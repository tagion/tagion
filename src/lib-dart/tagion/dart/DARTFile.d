/// Handles the lower level operation of DART database 
module tagion.dart.DARTFile;

private {
    import std.format;
    import std.exception : assumeWontThrow;
    import std.stdio : File;

    import std.algorithm.sorting : sort;
    import std.algorithm.iteration : filter, each;

    import std.algorithm.searching : count, maxElement, all;
    import std.algorithm.comparison : equal;

    import std.array : array;

    import std.traits : ReturnType;
    import std.typecons;
    import std.conv : to;
    import core.thread : Fiber;
    import std.range.primitives : isInputRange, ElementType;

    import tagion.basic.Types : Buffer, isBufferType, isTypedef;
    import tagion.basic.Basic : EnumText, assumeTrusted;
    import tagion.Keywords;

    import tagion.hibon.HiBON : HiBON;

    //    import tagion.hibon.HiBONType : GetLabel, label, HiBONPrefix, isStub, STUB;
    import tagion.hibon.HiBONType : isStub, label, record_filter = filter, GetLabel, recordType;
    import tagion.hibon.Document : Document;

    import tagion.dart.BlockFile;
    import tagion.dart.Recorder;
    import tagion.dart.DARTException : DARTException;
    import tagion.dart.DARTBasic;
    import tagion.crypto.SecureInterfaceNet : HashNet;

    //import tagion.basic.Basic;
    import tagion.basic.TagionExceptions : Check;
    import tagion.utils.Miscellaneous : toHex = toHexString;
}

/// Hash null definition (all zero values)
immutable(Buffer) hash_null;
shared static this() @trusted {
    import tagion.crypto.SecureNet : StdHashNet;
    import std.exception : assumeUnique;

    auto _null = new ubyte[StdHashNet.HASH_SIZE];
    hash_null = assumeUnique(_null);
}

/++
 + Gets the rim key from a buffer
 +
 + Returns;
 +     fingerprint[rim]
 +/
@safe
ubyte rim_key(F)(F rim_keys, const uint rim) pure @nogc if (isBufferType!F) {
    return rim_keys[rim];
}

/++
 + Sector is the little ending value the first two bytes of an fingerprint
 + Returns:
 +     Sector number of a fingerpint
 +/
@safe
ushort sector(F)(const(F) fingerprint) pure nothrow @nogc if (isBufferType!F)
in (fingerprint.length >= ubyte.sizeof)
do {
    ushort result = ushort(fingerprint[0]) << 8;
    if (fingerprint.length > ubyte.sizeof) {
        result |= fingerprint[1];

    }
    return result;
}

@safe
unittest {
    import tagion.basic.Types : Fingerprint;
    import std.stdio;

    ubyte[] buf1 = [0xA7];
    assert(sector(buf1) == 0xA700);
    assert(sector(cast(Fingerprint)[0xA7, 0x15]) == 0xA715);
    Buffer buf2 = [0xA7, 0x15, 0xE3];
    assert(sector(buf2) == 0xA715);

}

enum SECTOR_MAX_SIZE = 1 << (ushort.sizeof * 8);
@safe
void printfp(string msg, const Buffer[] fingerprints) {
    import std.stdio;

    foreach (fp; fingerprints) {
        if (fp) {
            writeln(msg, fp.hex);
        }
    }
}

alias check = Check!DARTException;

/++
 + DART File system
 + Distribute Achive of Random Transction
 + This class handels the CRUD Database
 +
 + The archive is hashed and store in structure similar to merkle trees datastruct.
 + Which here is called at sparsed merkle tree the sparse merkle is section in to rims
 + in  hierarchy which is where each rim contains a sub-tree called Branches. If a rim
 + Doens't branche out it contais a Leave which contains a Archive
 +
 +/

@safe class DARTFile {
    enum KEY_SPAN = ubyte.max + 1;
    enum uint request_limit = KEY_SPAN;
    enum INDEX_NULL = BlockFile.INDEX_NULL;
    immutable(string) filename;

    protected RecordFactory manufactor;

    protected {
        BlockFile blockfile;
        Buffer _fingerprint;
    }

    protected enum _params = [
            "fingerprints",
            "bullseye",
        ];

    mixin(EnumText!("Params", _params));

    enum MIN_BLOCK_SIZE = 0x80;
    static create(string filename, const uint block_size = MIN_BLOCK_SIZE)
    in {
        assert(block_size >= MIN_BLOCK_SIZE, format("Block size is too small for %s, %d must be langer than %d", filename, block_size, MIN_BLOCK_SIZE));
    }
    do {
        BlockFile.create(filename, DARTFile.stringof, block_size);
    }
    /++
     + A file set by filename should be create by the BlockFile
     + before it can be used as a DARTFile

     + Params:
     +   net       = Is the network object is for Hashing etc..
     +   filename = File name of the dart which much be created via the BlockFile.create method

     + Examples:
     ---
     enum BLOCK_SIZE=0x80; // Block size use in the BlockFile
     enum filename="some_filename.DART";
     auto net= new SomeNet;
     auto blockfile=BlockFile.create(filename, "Some description text", BLOCK_SIZE);
     // Open the DART File
     auto dartfile=new DARTFile(net, filename);
     ---
     +/
    this(const HashNet net, string filename) {
        blockfile = BlockFile(filename);
        this.manufactor = RecordFactory(net);
        this.filename = filename;
        if (blockfile.root_index) {
            const data = blockfile.load(blockfile.root_index);
            const doc = Document(data);
            auto branches = Branches(doc);
            _fingerprint = branches.fingerprint(this);
        }
    }

    /** 
     * Close the DARTFile
     */
    void close() @trusted {
        blockfile.close;
        blockfile.destroy;
        blockfile = null;
    }

    /* 
     * The Merkle root of the DARTFile
     * Returns: the `bullseye` of the DARTFile
     */
    immutable(Buffer) fingerprint() pure const nothrow {
        return _fingerprint;
    }

    /// Ditto for fingerprint
    alias bullseye = fingerprint;

    /**
     * Creates a recorder factor  
     * Returns: 
     *  recorder
     */
    RecordFactory.Recorder recorder() nothrow {
        return manufactor.recorder;
    }

    /** 
     * Creates a recorder from a document using the RecorderFactory used by the DART
     * Params:
     *   doc = list of archives in document format
     * Returns: 
     *   a recorder of the document
     */
    RecordFactory.Recorder recorder(const(Document) doc) {
        return manufactor.recorder(doc);
    }

    /**
 * Ditto
 * Params:
 *   archives = Archive data which contails an ordred list of archives 
 * Returns: 
 * recorder of the list of archives
 */
    RecordFactory.Recorder recorder(RecordFactory.Recorder.Archives archives) nothrow {
        return manufactor.recorder(archives);
    }
    /**
 * Calculates the sparsed Merkle root from the branch-table list
* The size of the table must be KEY_SPAN
* Leaves in the branch table which doen't exist should have the value null
 * Params:
 *   net = The hash object/function used to calculate the hashs
 *   table = List if hash-value(fingerprint) in the branch
 * Returns: 
 *  The Merkle root
 */
    static immutable(Buffer) sparsed_merkletree(const HashNet net, const(Buffer[]) table)
    in {
        assert(table.length == KEY_SPAN);
    }
    do {
        immutable(Buffer) merkletree(
                const(Buffer[]) left,
        const(Buffer[]) right) {
            Buffer _left_fingerprint;
            Buffer _right_fingerprint;
            if ((left.length == 1) && (right.length == 1)) {
                _left_fingerprint = left[0];
                _right_fingerprint = right[0];
            }
            else {
                immutable left_mid = left.length >> 1;
                immutable right_mid = right.length >> 1;
                _left_fingerprint = merkletree(left[0 .. left_mid], left[left_mid .. $]);
                _right_fingerprint = merkletree(right[0 .. right_mid], right[right_mid .. $]);
            }
            if (_left_fingerprint is null) {
                return _right_fingerprint;
            }
            else if (_right_fingerprint is null) {
                return _left_fingerprint;
            }
            else {
                return net.calcHash(_left_fingerprint, _right_fingerprint);
            }
        }

        immutable mid = table.length >> 1;
        return merkletree(table[0 .. mid], table[mid .. $]);
    }

    // alias Leave=Tuple!(uint, "index", Buffer, "fingerprint");
    // bool empty(const Leave leave) pure nothrow {
    //     return (leave.index is DARTFile.INDEX_NULL) && ( leave.fingerprint is null);
    // }

    @safe struct Leave {
        uint index;
        Buffer fingerprint;
        this(const uint index, Buffer fingerprint) {
            this.index = index;
            this.fingerprint = fingerprint;
        }

        this(const uint index, DARTIndex hash_pointer) {
            this.index = index;
            this.fingerprint = cast(Buffer) hash_pointer;
        }

        bool empty() pure const nothrow {
            return (index is INDEX_NULL) && (fingerprint is null);
        }
    }

    /**
 * Data struct which contains the branches in sub-tree
 */
    @recordType("Branches") struct Branches {
        import std.stdio;
        import tagion.hibon.HiBONJSON;

        @label("") protected Buffer merkleroot; /// The sparsed Merkle root hash of the branches
        @label("$prints", true) @(record_filter.Initialized) protected Buffer[] _fingerprints; /// Array of all the Leaves hashes
        @label("$idx", true) @(record_filter.Initialized) protected uint[] _indices; /// Array of index pointer to BlockFile
        @label("") private bool done;
        enum fingerprintsName = GetLabel!(_fingerprints).name;
        enum indicesName = GetLabel!(_indices).name;
        this(Document doc) {

            

                .check(isRecord(doc), format("Document is not a %s", ThisType.stringof));
            if (doc.hasMember(indicesName)) {
                _indices = new uint[KEY_SPAN];
                foreach (e; doc[indicesName].get!Document[]) {
                    _indices[e.index] = e.get!uint;
                }
            }
            if (doc.hasMember(fingerprintsName)) {
                _fingerprints = new Buffer[KEY_SPAN];
                foreach (e; doc[fingerprintsName].get!Document) {
                    _fingerprints[e.index] = e.get!(immutable(ubyte)[]).idup;
                }
            }
        }

        /* 
     * Check if the Branches has storage indices
     * Returns: true if the branch has BlockFile indices
     */
        @nogc
        bool hasIndices() const pure nothrow {
            return _indices.length !is 0;
        }

        /**
         * Params:
         *     key = key index of the branch
         * Returns:
         *      The fingerprint at key
         */
        immutable(Buffer) fingerprint(const size_t key) pure const nothrow
        in {
            assert(key < KEY_SPAN);
        }
        do {
            if (_fingerprints) {
                return _fingerprints[key];
            }
            return null;
        }

        /**
         * Returns:
         *     All the fingerprints to the sub branches and archives
         */
        @property
        const(Buffer[]) fingerprints() pure const nothrow {
            return _fingerprints;
        }

        /**
         * Returns:
         *     All the blockfile pointers to the sub branches and archives
         */
        @property
        const(uint[]) indices() pure const nothrow {
            return _indices;
        }

        /**
         * Returns:
         *     The number of index pointer which points to Leave or Branches
         *     in the blockfile
         */
        uint count() pure const {
            return cast(uint) _indices.count!("a != b")(0);
        }

        /**
         * Creates a HiBON from a the branches
         * Params:
         *     exclude_indices = If this flag is `true` then indices is not generated
         * Returns: HiBON of the branches
         */
        HiBON toHiBON(const bool exclude_indices = false) const
        in {
            assert(merkleroot is null, "Fingerprint must be calcuted before toHiBON is called");
        }
        do {
            auto hibon = new HiBON;
            auto hibon_fingerprints = new HiBON;
            if (!exclude_indices) {
                auto hibon_indices = new HiBON;
                bool indices_set;
                foreach (key, index; _indices) {
                    if (index !is INDEX_NULL) {
                        hibon_indices[key] = index;

                        

                        .check(_fingerprints[key]!is null,
                        format("Fingerprint key=%02X at index=%d is not defined", key, index));
                        indices_set = true;
                    }
                }
                if (indices_set) {
                    hibon[indicesName] = hibon_indices;
                }
            }
            foreach (key, print; _fingerprints) {
                if (print !is null) {
                    hibon_fingerprints[key] = print;
                }
            }

            hibon[fingerprintsName] = hibon_fingerprints;
            hibon[TYPENAME] = type_name;
            return hibon;
        }

        /* 
     * Convert the Branches to a Document
     * Returns: document
     */
        const(Document) toDoc() const {
            return Document(toHiBON);
        }

        import tagion.hibon.HiBONJSON : JSONString;

        mixin JSONString;

        import tagion.hibon.HiBONType : HiBONRecordType;

        mixin HiBONRecordType;

        /**
         * Get the index number of Leave at the leave number key
         *
         * Params:
         *     key = Leave number of the branches
         *
         */
        uint index(const uint key) pure const {
            if (empty) {
                return INDEX_NULL;
            }
            else {
                return _indices[key];
            }
        }

        /**
         * Set the branch at leave-number key the leave
         *
         * Params:
         *     leave = Which contains the  archive data
         *     key   = leave number
         */
        void opIndexAssign(const Leave leave, const uint key) {
            if (_indices is null) {
                _indices = new uint[KEY_SPAN];
            }
            if (_fingerprints is null) {
                _fingerprints = new Buffer[KEY_SPAN];
            }
            _indices[key] = leave.index;
            _fingerprints[key] = leave.fingerprint;
        }

        /**
         * Get the leave at key in the branches
         * Params:
         *     key   = leave-number
         * Returns:
         *     The leave located at the leave-number key
         *
         */
        Leave opIndex(const uint key) {
            if (empty) {
                return Leave(INDEX_NULL, null);
            }
            else {
                return Leave(_indices[key], _fingerprints[key]);
            }
        }

        /** 
    * Check if the branches has indices
    * Returns: true if no indices
    */
        bool empty() pure const {
            if (_indices !is null) {
                import std.algorithm.searching : any;

                return !_indices.any!("a != 0");
            }
            return true;
        }

        /**
     * Merkle root of the branches
     * Returns: fingerprint
     */
        private immutable(Buffer) fingerprint(
                DARTFile dartfile,
                scope bool[uint] index_used = null) {
            if (merkleroot is null) {
                foreach (key, index; _indices) {
                    if ((index !is INDEX_NULL) && (_fingerprints[key] is null)) {

                        

                            .check((index in index_used) is null,
                                    format("The DART contains a recursive tree @ index %d", index));
                        index_used[index] = true;
                        immutable data = dartfile.blockfile.load(index);
                        const doc = Document(data);
                        if (doc.hasMember(indicesName)) {
                            auto subbranch = Branches(doc);
                            _fingerprints[key] = subbranch.fingerprint(dartfile, index_used);
                        }
                        else {
                            _fingerprints[key] = dartfile.manufactor.net.calcHash(doc);
                        }
                    }
                }
                merkleroot = sparsed_merkletree(dartfile.manufactor.net, _fingerprints);
            }
            return merkleroot;
        }

        /**
         * Dumps the branches information
         */
        void dump() const {
            import std.stdio;

            foreach (key, index; _indices) {
                if (index !is INDEX_NULL) {
                    writefln("branches[%02X]=%s", key, _fingerprints[key].toHex);
                }
            }

        }
    }

    /** 
    * Reads the data at branch key
    * Params: 
    *    b = branches to read from
    *    key = key in the branch to read from 
    * Returns: the data a key
    */
    Buffer load(ref const(Branches) b, const uint key) {
        if ((key < KEY_SPAN) && (b.indices)) {
            immutable index = b.indices[key];
            if (index !is INDEX_NULL) {
                return blockfile.load(index);
            }
        }
        return null;
    }

    @safe
    class RimWalkerFiber : Fiber {
        immutable(Buffer) rim_paths;
        protected Buffer data;
        protected bool _finished;
        /** 
         * Sector for the walker
         * Returns: the sector of the rim
         */
        ushort sector() const pure nothrow
        in {
            assert(rim_paths.length >= ubyte.sizeof, assumeWontThrow(format("rim_paths is too short %d >= %d", rim_paths
                    .length, ubyte
                    .sizeof)));
        }
        do {
            if (rim_paths.length == ubyte.sizeof) {
                return ushort(rim_paths[0] << 8);
            }
            import std.bitmanip : bigEndianToNative;

            return bigEndianToNative!ushort(rim_paths[0 .. ushort.sizeof]);
        }
        /** 
         * Creates a walker from the DART path
         * Params:
         *   rim_paths = rim selected path
         */
        this(const(Buffer) rim_paths) @trusted
        in {
            assert(rim_paths.length >= ubyte.sizeof, format("Size of rim_paths should have a size of %d or more", ubyte
                    .sizeof));
        }
        do {
            this.rim_paths = rim_paths;
            super(&run);
            popFront;
        }

        final private void run() {
            void treverse(
                    immutable uint index,
                    immutable uint rim = 0) @safe {
                if (index !is INDEX_NULL) {
                    data = this.outer.blockfile.load(index);
                    const doc = Document(data);
                    if (rim < rim_paths.length) {
                        if (Branches.isRecord(doc)) {
                            const branches = Branches(doc);
                            // This branches
                            immutable key = rim_key(rim_paths, rim);
                            immutable next_index = branches.indices[key];
                            treverse(next_index, rim + 1);
                        }
                    }
                    else {
                        if (Branches.isRecord(doc)) {
                            const branches = Branches(doc);
                            foreach (next_index; branches.indices) {
                                treverse(next_index, rim + 1);
                            }
                        }
                        else {
                            assumeTrusted!yield;
                        }
                    }
                }
            }

            treverse(this.outer.blockfile.masterBlock.root_index);
            _finished = true;
        }

        /* 
     * Move to next data element in the range
     */
        @trusted
        final void popFront() {
            call;
        }

        /** 
     * Range empty 
     * Returns: true if empty
     */
        final bool empty() const pure nothrow {
            return _finished;
        }

        /** 
     * Front for the range
     * Returns: the data at the range position
     */
        final immutable(Buffer) front() const pure nothrow {
            return data;
        }
    }

    /**
     * A range which traverse the branches below the rim_paths
     * The range build as a Fiber.
     *
     * Params:
     *     rim_paths = Set the starting rim_paths
     *
     * Returns:
     *     A range on DARTFile as a Fiber
     */
    RimWalkerFiber rimWalkerRange(immutable(Buffer) rim_paths) {
        return new RimWalkerFiber(rim_paths);
    }

    /** 
     * Create indet string a rim_level
     * Params:
     *   rim = 
     * Returns: 
     */
    string indent(const uint rim_level) {
        string local_indent(const uint rim_level, string indent_str = null) {
            if (rim_level > 0) {
                return local_indent(rim_level - 1, indent_str ~ indent_tab);
            }
            return indent_str;
        }

        return local_indent(rim_level);
    }

    pragma(msg, "fixme(alex); Remove loadAll function");
    HiBON loadAll(Archive.Type type = Archive.Type.ADD) {
        auto recorder = manufactor.recorder;
        void local_load(
                const uint branch_index,
                const ubyte rim_key = 0,
                const uint rim = 0) @safe {
            if (branch_index !is INDEX_NULL) {
                immutable data = blockfile.load(branch_index);
                const doc = Document(data);
                if (Branches.isRecord(doc)) {
                    const branches = Branches(doc);
                    if (branches.indices.length) {
                        foreach (key, index; branches._indices) {
                            local_load(index, cast(ubyte) key, rim + 1);
                        }
                    }
                }
                else if (isStub(doc)) {
                    //                        writeln("stub");

                }
                else {
                    recorder.insert(doc, type);
                }
            }
        }

        local_load(blockfile.masterBlock.root_index);
        auto result = new HiBON;
        uint i;
        foreach (a; recorder[]) {
            result[i] = a.toDoc;
            i++;
        }
        return result;
    }
    /**
 * Loads all the archives in the list of fingerprints
 * 
 * Params:
 *   fingerprints = range of fingerprints
 *   type = types of archives
 * Returns: 
*   recorder of the read archives
 */
    RecordFactory.Recorder loads(Range)(
            Range fingerprints,
            Archive.Type type = Archive.Type.REMOVE) if (isInputRange!Range && is(ElementType!Range : Buffer)) {

        import std.algorithm.comparison : min;

        auto result = recorder;
        void traverse_dart(
                const uint branch_index,
                Buffer[] ordered_fingerprints,
                immutable uint rim = 0) @safe {
            if ((ordered_fingerprints) && (branch_index !is INDEX_NULL)) {
                immutable data = blockfile.load(branch_index);
                const doc = Document(data);
                if (Branches.isRecord(doc)) {
                    const branches = Branches(doc);
                    auto selected_fingerprints = ordered_fingerprints;
                    foreach (rim_key, index; branches._indices) {
                        uint pos;
                        while ((pos < selected_fingerprints.length) &&
                                (rim_key is selected_fingerprints[pos].rim_key(rim))) {
                            pos++;
                        }
                        if (pos > 0) {
                            traverse_dart(index, selected_fingerprints[0 .. pos], rim + 1);
                            selected_fingerprints = selected_fingerprints[pos .. $];
                        }
                    }
                }
                else {
                    // Loads the Archives into the archives
                        .check(ordered_fingerprints.length == 1,
                                format("Data base is broken at rim=%d fingerprint=%s",
                                rim, ordered_fingerprints[0].toHex));
                    // The archive is set in erase mode so it can be easily be erased later
                    auto archive = new Archive(manufactor.net, doc, type);
                    if (ordered_fingerprints[0] == archive.fingerprint) {
                        result.insert(archive);
                    }

                }
            }
        }

        auto sorted_fingerprints = fingerprints.filter!(a => a.length !is 0).array.dup;
        sorted_fingerprints.sort;
        traverse_dart(blockfile.masterBlock.root_index, sorted_fingerprints);
        return result;
    }

    // Range over a Range with the same key in the a specific rim
    @safe
    struct RimKeyRange {
        protected Archive[] current;
        @disable this();
        protected this(Archive[] current) pure nothrow @nogc {
            this.current = current;
        }

        this(Range)(ref Range range, const uint rim) {
            if (!range.empty) {
                immutable key = range.front.fingerprint.rim_key(rim);
                static if (is(Range == RimKeyRange)) {
                    auto reuse_current = range.current;
                    void build(ref Range range, const uint no = 0) @safe {
                        if (!range.empty && (range.front.fingerprint.rim_key(rim) is key)) {
                            auto a = range.front;
                            range.popFront;
                            build(range, no + 1);
                        }
                        else {
                            // Reuse the parent current
                            current = reuse_current[0 .. no];
                        }
                    }

                    build(range);
                }
                else {
                    void build(ref Range range, const uint no = 0) @safe {
                        if (!range.empty && (range.front.fingerprint.rim_key(rim) is key)) {
                            auto a = range.front;
                            range.popFront;
                            build(range, no + 1);
                            (() @trusted { current[no] = cast(Archive) a; })();
                        }
                        else {
                            current = new Archive[no];
                        }
                    }

                    build(range);
                }
            }
        }

        /**
     * Checks if all the archives in the range are of the type REMOVE
     * Params:
     *   get_type = archive type get function
     * Returns: true if all the archives are removes
     */
        bool onlyRemove(const GetType get_type) const pure {
            if (get_type) {
                return current
                    .all!((const(Archive) a) => a.type is Archive.Type.REMOVE);
            }
            return current
                .all!((const(Archive) a) => a.type is Archive.Type.REMOVE);
        }

        @nogc pure nothrow {
            /** 
             * Checks if the range only contains one archive 
             * Returns: true range if single
             */
            bool single() const {
                return current.length == 1;
            }

            /**
             * Checks if the range is empty
             * Returns: true if empty
             */
            bool empty() const {
                return current.length == 0;
            }

            /**
             *  Progress one archive
             */
            void popFront() {
                if (!empty) {
                    current = current[1 .. $];
                }
            }

            /**
             * Gets the current archive in the range
             * Returns: current archive and return null if the range is empty
             */
            inout(Archive) front() inout {
                if (empty) {
                    return null;
                }
                return current[0];
            }

            /**
             * Force the range to be empty
             */
            void force_empty() {
                current = null;
            }

            /**
             * Number of archive left in the range
             * Returns: size of the range
             */
            size_t length() const {
                return current.length;
            }
        }
        /**
         *  Creates new range at the current position
         * Returns: copy of this range
         */
        RimKeyRange save() pure nothrow @nogc {
            return RimKeyRange(current);
        }

    }

    enum RIMS_IN_SECTOR = 2;
    /**
     * $(SMALL_TABLE
     * Sample of the DART Map
     * |      |key[0]|key[1]|key[2]|key[3]|key[4]|
     * |  rim |  00  |  01  |  02  |  03  |  04  | ....
     * |------|------|------|------|------|------|-----
     * |      |  20  |  A3  |  33  |  B1  |  17  | -> arcive fingerprint=20_A3_33_B1_17....
     * |      |  **  |  **  |  **  |  **  |  42  | -> arcive fingerprint=20_A3_33_B1_42....
     * |      |  **  |  **  |  57  |  B1  |  17  | -> arcive fingerprint=20_A3_57_B1_17....
     * |      |  **  |  **  |  **  |  **  |  42  | -> arcive fingerprint=20_A3_57_B1_42....
     * |      |  **  |  **  |  C2  |      |      | -> arcive fingerprint=20_A3_C3....
     * |      |  **  |  **  |  CA  |  48  |      | -> arcive fingerprint=20_A3_CA_48....
     * |      |  **  |  **  |  **  |  68  |      | -> arcive fingerprint=20_A3_CA_48....
     * )
     * $(B Sector=[key[0],key[1]]) <br>
     * ### Note ** means the same value as above
     * The first two rims is set the sector and the following is rims
     * represents the key index into the Branches incices
     * The modify_records contains the archives which is going to be added or deleted
     * The type of archive tells which actions are going to be performed by the modifier
     * If the function executes succesfully then the DART is update or else it does not affect the DART
     * The function return the bulleye of the dart
     */
    Buffer modify(const(RecordFactory.Recorder) modify_records, GetType get_type = null) {
        if (get_type is null) {
            get_type = (a) => a.type;
        }
        Leave traverse_dart(R)(
                ref R range,
                const uint branch_index,
                immutable uint rim = 0) @safe {
            if (!range.empty) {
                auto archive = range.front;
                uint erase_block_index;
                scope (success) {
                    blockfile.erase(erase_block_index);
                }
                immutable sector = sector(archive.fingerprint);
                Branches branches;
                if (rim < RIMS_IN_SECTOR) {
                    if (branch_index !is INDEX_NULL) {
                        immutable data = blockfile.load(branch_index);
                        const doc = Document(data);
                        branches = Branches(doc);

                        

                        .check(branches.hasIndices,
                                "DART failure within the sector rims the DART should contain a branch");
                    }

                    while (!range.empty) {
                        auto sub_range = RimKeyRange(range, rim);
                        immutable rim_key = sub_range.front.fingerprint.rim_key(rim);
                        if (!branches[rim_key].empty || !sub_range.onlyRemove(get_type)) {
                            branches[rim_key] = traverse_dart(sub_range, branches.index(rim_key), rim + 1);
                        }
                    }
                    erase_block_index = branch_index;
                    if (branches.empty) {
                        return Leave(INDEX_NULL, null);
                    }
                    else {
                        return Leave(blockfile.save(branches.toHiBON.serialize)
                                .begin_index, branches.fingerprint(this));
                    }
                }
                else static if (is(R == RimKeyRange)) {
                    uint lonely_rim_key;
                    if (branch_index !is INDEX_NULL) {
                        immutable data = blockfile.load(branch_index);
                        const doc = Document(data);

                        

                        .check(!doc.isStub, "DART failure a stub is not allowed within the sector angle");
                        if (Branches.isRecord(doc)) {
                            branches = Branches(doc);
                            do {
                                auto sub_range = RimKeyRange(range, rim);
                                const sub_archive = sub_range.front;
                                immutable rim_key = sub_archive.fingerprint.rim_key(rim);
                                if (!branches[rim_key].empty || !sub_range.onlyRemove(get_type)) {
                                    branches[rim_key] = traverse_dart(sub_range, branches.index(rim_key), rim + 1);
                                }
                            }
                            while (!range.empty);
                        }
                        else {
                            // DART does not store a branch this means that it contains a leave.
                            // Leave means and archive
                            // The new Archives is constructed to include the archive which is already in the DART
                            auto archive_in_dart = new Archive(manufactor.net, doc);
                            scope (success) {
                                // The archive is erased and it will be added again to the DART
                                // if it not removed by and action in the record
                                blockfile.erase(branch_index);

                            }
                            if (range.single) {
                                auto single_archive = range.front;
                                if (!single_archive.done) {
                                    range.popFront;
                                    if (single_archive.fingerprint == archive_in_dart.fingerprint) {
                                        if (single_archive.isRemove(get_type)) {
                                            single_archive.doit;
                                            return Leave(INDEX_NULL, null);
                                        }
                                        else {
                                            return Leave(blockfile.save(single_archive.store.serialize)
                                                    .begin_index,
                                                    single_archive.fingerprint);
                                        }
                                    }
                                    else {
                                        auto recorder = manufactor.recorder;
                                        recorder.insert(archive_in_dart);
                                        recorder.insert(single_archive);
                                        auto archives_range = recorder.archives[];
                                        do {
                                            auto sub_range = RimKeyRange(archives_range, rim);
                                            const sub_archive = sub_range.front;
                                            immutable rim_key = sub_archive.fingerprint.rim_key(
                                                    rim);

                                            if (!branches[rim_key].empty || !sub_range.onlyRemove(
                                                    get_type)) {
                                                branches[rim_key] = traverse_dart(sub_range, INDEX_NULL, rim + 1);
                                            }
                                        }
                                        while (!archives_range.empty);
                                    }
                                }
                            }
                            else {
                                scope archives = manufactor.recorder(range).archives;
                                range.force_empty;
                                scope equal_range = archives.equalRange(archive_in_dart);
                                if (!equal_range.empty) {
                                    const equal_archive = equal_range.front;
                                    if (!equal_archive.done) {
                                        if (equal_archive.isRemove(get_type)) {
                                            equal_archive.doit;
                                        }
                                    }
                                }
                                else {
                                    archives.insert(archive_in_dart);
                                }
                                auto archive_range = archives[];
                                do {
                                    auto sub_range = RimKeyRange(archive_range, rim);
                                    const sub_archive = sub_range.front;
                                    immutable rim_key = sub_archive.fingerprint.rim_key(rim);
                                    if (!branches[rim_key].empty || !sub_range.onlyRemove(get_type)) {
                                        branches[rim_key] = traverse_dart(sub_range, branches.index(rim_key), rim + 1);
                                    }
                                }
                                while (!archive_range.empty);
                            }
                        }
                    }
                    else {
                        // Adds archives in new branch which has not been created yet
                        if (range.single) {
                            auto single_archive = range.front;
                            if (!single_archive.done) {
                                range.popFront;
                                if (single_archive.isRemove(get_type)) {
                                    return Leave(INDEX_NULL, null);
                                }
                                else {
                                    single_archive.doit;
                                    lonely_rim_key = single_archive.fingerprint.rim_key(rim);
                                    if (rim is RIMS_IN_SECTOR) {
                                        // Return a branch with as single leave when the leave is on the on
                                        // the edge between the sector
                                        branches[lonely_rim_key] = Leave(blockfile.save(single_archive.store.serialize)
                                                .begin_index, single_archive.fingerprint);
                                        return Leave(blockfile.save(branches.toHiBON.serialize)
                                                .begin_index, branches.fingerprint(this));
                                    }
                                    else {
                                        return Leave(blockfile.save(single_archive.store.serialize)
                                                .begin_index, single_archive.fingerprint);
                                    }
                                }
                            }
                        }
                        else {
                            do {
                                const sub_archive = range.front;
                                immutable rim_key = sub_archive.fingerprint.rim_key(rim);
                                auto sub_range = RimKeyRange(range, rim);
                                if (!branches[rim_key].empty || !sub_range.onlyRemove(get_type)) {
                                    branches[rim_key] = traverse_dart(sub_range, branches.index(rim_key), rim + 1);
                                }
                            }
                            while (!range.empty);
                        }
                    }
                    immutable count = branches.count;
                    if (count == 0) {
                        return Leave(INDEX_NULL, null);
                    }
                    else if ((count == 1) && (lonely_rim_key !is INDEX_NULL)) {
                        // Return the leave if the branches only contain one leave
                        return branches[lonely_rim_key];
                    }
                    else {
                        return Leave(blockfile.save(branches.toHiBON.serialize)
                                .begin_index, branches.fingerprint(this));
                    }
                    assert(0);
                }
                else {
                    assert(0, format("Range %s not expected", R.stringof));
                }
            }
            return Leave(INDEX_NULL, null);
        }

        if (modify_records.empty) {
            return _fingerprint;
        }
        else {
            auto range = modify_records.archives[];
            immutable new_root = traverse_dart(range, blockfile.masterBlock.root_index);

            scope (success) {
                // On success the new root_index is set and the DART is updated
                _fingerprint = new_root.fingerprint;
                if ((new_root.fingerprint is null) || (new_root.index is INDEX_NULL)) {
                    // All data has been delete so a new blockfile is created
                    blockfile.close;
                    blockfile = BlockFile.reset(filename);
                }
                else {
                    blockfile.root_index = new_root.index;
                    blockfile.store;
                }
            }
            scope (failure) {
                // On failure drop the BlockFile and reopen it
                blockfile.close;
                blockfile = BlockFile(filename);
            }
            return new_root.fingerprint;
        }
    }

    RecordFactory.Recorder readStubs() { //RIMS_IN_SECTOR
        RecordFactory.Recorder rec = manufactor.recorder();
        void iterate(const uint branch_index, immutable uint rim = 0) @safe {
            if (branch_index !is INDEX_NULL) {
                immutable data = blockfile.load(branch_index);
                const doc = Document(data);
                if (Branches.isRecord(doc)) {
                    auto branches = Branches(doc);
                    if (rim == RIMS_IN_SECTOR) {
                        // writeln("ADD BRANCH FP", branches.fingerprint(this).toHex);
                        rec.stub(branches.fingerprint(this));
                    }
                    else {
                        foreach (rim_key, index; branches._indices) {
                            iterate(index, rim + 1);
                        }
                    }
                }
                else {
                    rec.stub(manufactor.net.dartIndex(doc));
                }
            }
        }

        auto root_index = blockfile.masterBlock.root_index;

        iterate(root_index);
        return rec;
    }

    /** 
     * Loads the branches from the DART at rim_path
     * Params:
     *   rim_path = rim path select the branches
     * Returns:
     *   the branches a the rim_path
     */
    Branches branches(const(ubyte[]) rim_path) {
        Branches search(const(ubyte[]) rim_path, const uint index, const uint rim = 0) {
            immutable data = blockfile.load(index);
            const doc = Document(data);
            if (Branches.isRecord(doc)) {
                Branches branches = Branches(doc);
                if (rim < rim_path.length) {
                    immutable rim_key = rim_path.rim_key(rim);
                    immutable sub_index = branches._indices[rim_key];
                    if (sub_index !is INDEX_NULL) {
                        return search(rim_path, sub_index, rim + 1);
                    }
                }
                else {
                    return branches;
                }
            }
            // Return empty branches
            return Branches();
        }

        if (blockfile.masterBlock.root_index is INDEX_NULL) {
            return Branches();
        }
        return search(rim_path, blockfile.masterBlock.root_index);
    }

    /**
     * Creates a range at which iterate and read the data in the DART at rim_path 
     * Params:
     *   rim_path = rim_path where to select the range 
     * Returns: 
     *  the rim-range at rim_path
     */
    RimRange iterator(const(ubyte[]) rim_path) @trusted {
        auto range = new RimRange(rim_path);
        range.call;
        return range;
    }

    /** 
     * Rim range 
     */
    @safe class RimRange : Fiber {
        protected {
            const(ubyte[]) rim_path;
            Buffer data;
            bool _finished;
        }
        /**
         * Create a rim range form the DARTFile
         * Params:
         *   rim_path = rim path
         */
        private this(const(ubyte[]) rim_path) @trusted {
            this.rim_path = rim_path;
            super(&run);
        }

        protected final void run() {
            void local_iterator(const(ubyte[]) rim_path, const uint index, const uint rim = 0) {
                if (index !is INDEX_NULL) {
                    data = blockfile.load(index);
                    const doc = Document(data);
                    if (Branches.isRecord(doc)) {
                        Branches branches = Branches(doc);
                        foreach (key, sub_index; branches._indices) {
                            local_iterator(rim_path ~ cast(ubyte) key, sub_index, rim + 1);
                        }
                    }
                    assumeTrusted!yield;
                }
            }

            uint search(const(ubyte[]) rim_path, const uint index, const uint rim = 0) @safe {
                if (index !is INDEX_NULL) {
                    immutable local_data = this.outer.blockfile.load(index);
                    const doc = Document(local_data);
                    if (Branches.isRecord(doc)) {
                        Branches branches = Branches(doc);
                        if (rim < rim_path.length) {
                            immutable rim_key = rim_path.rim_key(rim);
                            immutable sub_index = branches._indices[rim_key];
                            if (rim + 1 == rim_path.length) {
                                return sub_index;
                            }
                            else {
                                return search(rim_path, sub_index, rim + 1);
                            }
                        }
                    }
                }
                return index;
            }

            immutable index = search(rim_path, blockfile.masterBlock.root_index);
            immutable rim = cast(uint) rim_path.length;
            local_iterator(rim_path, index, rim);
            _finished = true;
        }

        /// Progress to next Buffer
        final void popFront() @trusted {
            call;
        }

        /// Returns: true if empty
        final bool empty() pure const nothrow {
            return _finished;
        }

        /// Returns: current buffer
        final Buffer front() pure const nothrow {
            return data;
        }
    }

    enum indent_tab = "| .. ";
    /** 
     * Dumps the dart as rim-path
     * Params:
     *   full = true for full DART
     */
    void dump(bool full = false) {
        import std.stdio;

        writeln("EYE: ", _fingerprint.hex);
        void local_dump(const uint branch_index,
                const ubyte rim_key = 0,
                const uint rim = 0,
                string indent = null) @safe {
            if (branch_index !is INDEX_NULL) {
                immutable data = blockfile.load(branch_index);
                const doc = Document(data);
                if (Branches.isRecord(doc)) {
                    auto branches = Branches(doc);
                    string _indent;
                    if (rim > 0) {
                        writefln("%s| %02X [%d]", indent, rim_key, branch_index);
                        _indent = indent ~ indent_tab;
                    }
                    foreach (key, index; branches._indices) {
                        local_dump(index, cast(ubyte) key, rim + 1, _indent);
                    }
                }
                else {
                    immutable fingerprint = manufactor.net.dartIndex(doc);
                    auto lastRing = full ? fingerprint.length : rim + 1;
                    writefln("%s%s [%d]", indent, fingerprint[0 .. lastRing].hex, branch_index);
                }
            }
        }

        local_dump(blockfile.masterBlock.root_index);
    }

    version (unittest) {
        import tagion.dart.DARTFakeNet;

        static {

            bool check(const(RecordFactory.Recorder) A, const(RecordFactory.Recorder) B) {
                return equal!(q{a.fingerprint == b.fingerprint})(A.archives[], B.archives[]);
            }

            Buffer write(DARTFile dart, const(ulong[]) table, out RecordFactory.Recorder rec, bool isStubs = false) {
                rec = isStubs ? stubs(dart.manufactor, table) : records(dart.manufactor, table);
                return dart.modify(rec);
            }

            Buffer[] fingerprints(RecordFactory.Recorder recorder) {
                Buffer[] results;
                foreach (a; recorder.archives) {
                    assert(a.done);
                    results ~= cast(Buffer) a.fingerprint;
                }
                return results;

            }

            bool validate(DARTFile dart, const(ulong[]) table, out RecordFactory.Recorder recorder) {
                write(dart, table, recorder);
                auto _fingerprints = fingerprints(recorder);

                auto find_recorder = dart.loads(_fingerprints);
                return check(recorder, find_recorder);
            }

            RecordFactory.Recorder records(RecordFactory factory, const(ulong[]) table) {
                auto rec = factory.recorder;
                foreach (t; table) {
                    const doc = DARTFakeNet.fake_doc(t);
                    rec.add(doc);
                }
                return rec;
            }

            RecordFactory.Recorder stubs(RecordFactory factory, const(ulong[]) table) {
                auto rec = factory.recorder;
                foreach (t; table) {
                    import std.bitmanip;

                    immutable fp = nativeToBigEndian(t).idup;
                    rec.stub(fp);
                }
                return rec;
            }
        }

    }

    ///
    unittest {
        import std.algorithm.sorting : sort;

        //    import tagion.basic.Basic;
        import std.typecons;
        import tagion.utils.Random;
        import std.bitmanip : BitArray;
        import tagion.utils.Miscellaneous : cutHex;

        auto net = new DARTFakeNet;
        auto manufactor = RecordFactory(net);

        immutable(ulong[]) table = [
            //  RIM 2 test (rim=2)
            0x20_21_10_30_40_50_80_90,
            0x20_21_11_30_40_50_80_90,
            0x20_21_12_30_40_50_80_90,
            0x20_21_0a_30_40_50_80_90, // Insert before in rim 2

            // Rim 3 test (rim=3)
            0x20_21_20_30_40_50_80_90,
            0x20_21_20_31_40_50_80_90,
            0x20_21_20_34_40_50_80_90,
            0x20_21_20_20_40_50_80_90, // Insert before the first in rim 3

            0x20_21_20_32_40_50_80_90, // Insert just the last archive in the bucket  in rim 3

            // Rim 3 test (rim=3)
            0x20_21_22_30_40_50_80_90,
            0x20_21_22_31_40_50_80_90,
            0x20_21_22_34_40_50_80_90,
            0x20_21_22_20_40_50_80_90, // Insert before the first in rim 3
            0x20_21_22_36_40_50_80_90, // Insert after the first in rim 3

            0x20_21_22_32_40_50_80_90, // Insert between in rim 3

            // Add in first rim again
            0x20_21_11_33_40_50_80_90, // Rim 4 test
            0x20_21_20_32_30_40_50_80,
            0x20_21_20_32_31_40_50_80,
            0x20_21_20_32_34_40_50_80,
            0x20_21_20_32_20_40_50_80, // Insert before the first in rim 4

            0x20_21_20_32_32_40_50_80, // Insert just the last archive in the bucket in rim 4

        ];

        immutable filename = fileId!DARTFile.fullpath;
        immutable filename_A = fileId!DARTFile("A").fullpath;
        immutable filename_B = fileId!DARTFile("B").fullpath;

        { // Test the fake hash on Archive
            auto doc_in = DARTFakeNet.fake_doc(table[0]);
            auto a_in = new Archive(net, doc_in, Archive.Type.ADD);

            // Test recorder
            auto recorder = manufactor.recorder;
            recorder.insert(a_in);
            auto recorder_doc_out = recorder.toDoc;
            auto recorder_out = manufactor.recorder(recorder_doc_out);
            auto recorder_archive = recorder_out.archives[].front;
            assert(recorder_archive.fingerprint == a_in.fingerprint);

        }

        { // Test RimKeyRange
            auto recorder = manufactor.recorder;
            auto test_tabel = table[0 .. 8].dup;
            foreach (t; test_tabel) {
                const doc = DARTFakeNet.fake_doc(t);
                recorder.add(doc);
            }

            test_tabel.sort;

            uint i;
            foreach (a; recorder.archives) {
                assert(a.filed.data == net.fake_doc(test_tabel[i]).data);
                i++;
            }

            immutable rim = 3;
            {
                auto range = recorder.archives[];
                auto rim_range = DARTFile.RimKeyRange(range, rim);
                i = 0;
                immutable key = rim_range.front.fingerprint.rim_key(rim);
                foreach (a; rim_range) {
                    while (net.dartIndex(DARTFakeNet.fake_doc(test_tabel[i])).rim_key(rim) !is key) {
                        i++;
                    }
                    i++;
                }
            }

            {
                auto range = recorder.archives[];
                auto rim_range = DARTFile.RimKeyRange(range, rim);
                assert(!rim_range.empty);
                assert(!rim_range.single);
                rim_range.popFront;
                assert(!rim_range.empty);
                assert(!rim_range.single);
                rim_range.popFront;
                assert(!rim_range.empty);
                assert(!rim_range.single);
                rim_range.popFront;
                assert(!rim_range.empty);
                rim_range.popFront;
                assert(rim_range.empty);
                assert(!rim_range.single);
            }
        }

        { // Rim 2 test
            DARTFile.create(filename);
            auto dart = new DARTFile(net, filename);
            RecordFactory.Recorder recorder;
            assert(validate(dart, table[0 .. 4], recorder));
        }

        { // Rim 3 test
            DARTFile.create(filename);
            auto dart = new DARTFile(net, filename);
            RecordFactory.Recorder recorder;
            //=Recorder(net);

            assert(validate(dart, table[4 .. 9], recorder));
            // dart.dump;
        }

        { // Rim 3 test
            DARTFile.create(filename);
            auto dart = new DARTFile(net, filename);
            RecordFactory.Recorder recorder;

            assert(validate(dart, table[4 .. 9], recorder));
            // dart.dump;
        }

        { // Rim 4 test
            DARTFile.create(filename);
            auto dart = new DARTFile(net, filename);
            RecordFactory.Recorder recorder;

            assert(validate(dart, table[17 .. $], recorder));
            // dart.dump;
        }

        { // Rim 2 & 3
            DARTFile.create(filename);
            auto dart = new DARTFile(net, filename);
            RecordFactory.Recorder recorder;

            assert(validate(dart, table[0 .. 9], recorder));
            // dart.dump;
        }

        { // Rim 2 & 3 & 4
            DARTFile.create(filename);
            auto dart = new DARTFile(net, filename);
            RecordFactory.Recorder recorder;

            assert(validate(dart, table[0 .. 9] ~ table[17 .. $], recorder));
            // dart.dump;
        }

        { // Rim all
            DARTFile.create(filename);
            auto dart = new DARTFile(net, filename);
            RecordFactory.Recorder recorder;

            assert(validate(dart, table, recorder));
            // dart.dump;
        }

        { // Remove two archives and check the bulleye
            DARTFile.create(filename_A);
            DARTFile.create(filename_B);
            RecordFactory.Recorder recorder_A;
            RecordFactory.Recorder recorder_B;
            auto dart_A = new DARTFile(net, filename_A);
            auto dart_B = new DARTFile(net, filename_B);
            //
            write(dart_A, table, recorder_A);
            // table 8 and 9 is left out
            auto bulleye_B = write(dart_B, table[0 .. 8] ~ table[10 .. $], recorder_B);

            //dart_A.dump;
            //dart_B.dump;
            auto remove_recorder = records(manufactor, table[8 .. 10]);

            auto bulleye_A = dart_A.modify(remove_recorder, (a) => Archive.Type.REMOVE);
            //dart_A.dump;
            assert(bulleye_A == bulleye_B);
        }

        { // Random remove and the bulleye is check
            auto rand = Random!ulong(1234_5678_9012_345UL);
            enum N = 1000;
            auto random_table = new ulong[N];
            foreach (ref r; random_table) {
                r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
            }
            DARTFile.create(filename_A);
            DARTFile.create(filename_B);
            RecordFactory.Recorder recorder_A;
            RecordFactory.Recorder recorder_B;
            auto dart_A = new DARTFile(net, filename_A);
            auto dart_B = new DARTFile(net, filename_B);
            //

            auto bulleye_A = write(dart_A, random_table, recorder_A);
            auto bulleye_B = write(dart_B, random_table[0 .. N - 100], recorder_B);
            auto remove_recorder = records(manufactor, random_table[N - 100 .. N]);

            bulleye_A = dart_A.modify(remove_recorder, (a) => Archive.Type.REMOVE);
            // dart_A.dump;

            // The bull eye of the two DART must be the same
            assert(bulleye_A == bulleye_B);
        }

        { // Random write on to an existing DART and the bulleye is check

            auto rand = Random!ulong(1234_5678_9012_345UL);
            enum N = 1000;
            auto random_table = new ulong[N];
            foreach (ref r; random_table) {
                r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
            }
            DARTFile.create(filename_A);
            DARTFile.create(filename_B);
            RecordFactory.Recorder recorder_A;
            RecordFactory.Recorder recorder_B;
            auto dart_A = new DARTFile(net, filename_A);
            auto dart_B = new DARTFile(net, filename_B);
            //

            write(dart_A, random_table[27 .. 29], recorder_A);
            // dart_A.dump;
            auto bulleye_A = write(dart_A, random_table[34 .. 35], recorder_A);
            // dart_A.dump;
            //assert(0);
            auto bulleye_B = write(dart_B, random_table[27 .. 29] ~ random_table[34 .. 35], recorder_B);

            // dart_B.dump;

            // The bull eye of the two DART must be the same
            assert(bulleye_A == bulleye_B);
        }

        { // Random remove and the bulleye is check
            auto rand = Random!ulong(1234_5678_9012_345UL);
            enum N = 1000;
            auto random_table = new ulong[N];
            foreach (ref r; random_table) {
                r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
            }
            DARTFile.create(filename_A);
            DARTFile.create(filename_B);
            RecordFactory.Recorder recorder_A;
            RecordFactory.Recorder recorder_B;
            auto dart_A = new DARTFile(net, filename_A);
            auto dart_B = new DARTFile(net, filename_B);
            //

            auto bulleye_A = write(dart_A, random_table, recorder_A);
            auto bulleye_B = write(dart_B, random_table[0 .. N - 100], recorder_B);
            auto remove_recorder = records(manufactor, random_table[N - 100 .. N]);
            bulleye_A = dart_A.modify(remove_recorder, (a) => Archive.Type.REMOVE);
            // dart_A.dump;
            // The bull eye of the two DART must be the same
            assert(bulleye_A == bulleye_B);
        }

        { // Random write on to an existing DART and the bulleye is check
            immutable(ulong[]) selected_table = [
                0xABBA_1234_DF92_7BA7,
                0xABBA_1234_62BD_7814,
                0xABBA_1234_DFA5_2B29
            ];
            DARTFile.create(filename_A);
            DARTFile.create(filename_B);
            RecordFactory.Recorder recorder_A;
            RecordFactory.Recorder recorder_B;
            auto dart_A = new DARTFile(net, filename_A);
            auto dart_B = new DARTFile(net, filename_B);
            //

            write(dart_A, selected_table[0 .. 2], recorder_A);
            auto bulleye_A = write(dart_A, selected_table[2 .. $], recorder_A);
            auto bulleye_B = write(dart_B, selected_table, recorder_B);
            // The bull eye of the two DART must be the same
            assert(bulleye_A == bulleye_B);
        }

        { // Random write and then bulleye is check
            auto rand = Random!ulong(1234_5678_9012_345UL);
            enum N = 1000;
            auto random_table = new ulong[N];
            foreach (ref r; random_table) {
                r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
            }
            DARTFile.create(filename_A);
            DARTFile.create(filename_B);
            RecordFactory.Recorder recorder_A;
            RecordFactory.Recorder recorder_B;
            auto dart_A = new DARTFile(net, filename_A);
            auto dart_B = new DARTFile(net, filename_B);

            write(dart_A, random_table[0 .. 333], recorder_A);
            write(dart_B, random_table[0 .. 777], recorder_B);
            auto bulleye_A = write(dart_A, random_table[333 .. $], recorder_A);
            auto bulleye_B = write(dart_B, random_table[777 .. $], recorder_B);

            // The bull eye of the two DART must be the same
            assert(bulleye_A == bulleye_B);
        }

        { // Try to remove a nonexisting archive
            auto rand = Random!ulong(1234_5678_9012_345UL);
            enum N = 50;
            auto random_table = new ulong[N];
            foreach (ref r; random_table) {
                r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
            }
            DARTFile.create(filename_A);
            DARTFile.create(filename_B);

            auto dart_A = new DARTFile(net, filename_A);
            auto dart_B = new DARTFile(net, filename_B);
            RecordFactory.Recorder recorder_A;
            RecordFactory.Recorder recorder_B;

            write(dart_A, random_table, recorder_A);
            write(dart_B, random_table, recorder_B);
            assert(dart_A.fingerprint == dart_B.fingerprint);

            auto recorder = dart_A.recorder;
            const archive_1 = new Archive(net, net.fake_doc(0xABB7_1111_1111_0000UL), Archive
                    .Type.NONE);
            recorder.remove(archive_1.fingerprint);
            const archive_2 = new Archive(net, net.fake_doc(0xABB7_1112_1111_0000UL), Archive
                    .Type.NONE);
            recorder.remove(archive_2.fingerprint);
            dart_B.modify(recorder);
            // dart_B.dump;
            // dart_A.dump;
            assert(dart_A.fingerprint == dart_B.fingerprint);

            // Check fingerprint on load
            auto read_dart_A = new DARTFile(net, filename_A);
            assert(dart_A.fingerprint == read_dart_A.fingerprint);
        }

        { // Large random test
            auto rand = Random!ulong(1234_5678_9012_345UL);
            enum N = 500;
            auto random_table = new ulong[N];
            foreach (ref r; random_table) {
                r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
            }
            DARTFile.create(filename_A);
            DARTFile.create(filename_B);
            // Recorder recorder_B;
            auto dart_A = new DARTFile(net, filename_A);
            auto dart_B = new DARTFile(net, filename_B);

            BitArray saved_archives;
            (() @trusted { saved_archives.length = N; })();
            auto rand_index = Random!uint(1234);
            enum ITERATIONS = 7;
            enum SELECT_ITER = 35;
            (() @trusted {
                foreach (i; 0 .. ITERATIONS) {
                    auto recorder = dart_A.recorder;
                    BitArray check_archives;
                    BitArray added_archives;
                    BitArray removed_archives;
                    check_archives.length = N;
                    added_archives.length = N;
                    removed_archives.length = N;
                    foreach (j; 0 .. SELECT_ITER) {
                        immutable index = rand_index.value(N);
                        if (!check_archives[index]) {
                            const doc = net.fake_doc(random_table[index]);
                            if (saved_archives[index]) {
                                recorder.remove(doc);
                                removed_archives[index] = true;
                            }
                            else {
                                recorder.add(doc);
                                added_archives[index] = true;
                            }
                            check_archives[index] = true;
                        }
                    }
                    // dart_A.blockfile.dump;
                    dart_A.modify(recorder);
                    saved_archives |= added_archives;
                    saved_archives &= ~removed_archives;
                    // dart_A.dump;
                }
                auto recorder_B = dart_B.recorder;

                saved_archives.bitsSet.each!(n => recorder_B.add(net.fake_doc(random_table[n])));
                dart_B.modify(recorder_B);
                // dart_B.dump;
                assert(dart_A.fingerprint == dart_B.fingerprint);
            })();
        }
        version (none) { //Read stubs test
            writeln("FROM THIS");
            auto rand = Random!ulong(1234_5678_9012_345UL);
            enum N = 50;
            auto random_table = new ulong[N];
            auto random_stubs = new ulong[N];
            foreach (ref r; random_table) {
                r = rand.value(0x20_21_22_36_40_50_80_90, 0x20_26_22_36_40_50_80_90);
            }

            foreach (ref r; random_stubs) {
                r = rand.value(0x20_27_22_36_40_50_80_90, 0x20_29_22_36_40_50_80_90);
            }
            DARTFile.create(filename_A);
            DARTFile.create(filename_B);

            auto dart_A = new DARTFile(net, filename_A);
            auto dart_B = new DARTFile(net, filename_B);
            Recorder recorder_A;
            Recorder recorder_B;

            write(dart_A, random_table, recorder_A);
            write(dart_A, random_stubs, recorder_B, true);
            // recorder_B.dump;
            // dart_A.dump;

            auto rec = dart_A.readStubs();
            // rec.dump;

            dart_B.modify(rec);
            // dart_B.dump;
            // dart_A.dump;

            // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
            assert(dart_A.fingerprint == dart_B.fingerprint);

            // Check fingerprint on load
            auto read_dart_A = new DARTFile(net, filename_A);
            writefln("read_dart_A %s", read_dart_A.fingerprint.cutHex);
        }
    }
}
