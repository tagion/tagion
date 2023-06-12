/// Handles the lower level operation of DART database 
module tagion.dart.DARTFile;

private {
    import std.format;
    import std.exception : assumeWontThrow;
    import std.stdio : File;

    import std.algorithm.sorting : sort;
    import std.algorithm.iteration : filter, each;
    import std.range;
    import std.algorithm.searching : count, maxElement, all;
    import std.algorithm.comparison : equal;
    import std.typecons : Flag, Yes, No;

    import std.array : array;

    import std.traits;
    import std.typecons;
    import std.conv : to;
    import core.thread : Fiber;
    import std.range.primitives : isInputRange, ElementType;

    import tagion.basic.Debug : __write;
    import tagion.basic.Types : Buffer, isBufferType, isTypedef;
    import tagion.basic.basic : EnumText, assumeTrusted;
    import tagion.Keywords;

    import tagion.hibon.HiBON : HiBON;

    import tagion.hibon.HiBONRecord : label, record_filter = filter, GetLabel, recordType;
    import tagion.hibon.Document : Document;

    import tagion.dart.BlockFile;
    import tagion.dart.Recorder;
    import tagion.dart.DARTException : DARTException;
    import tagion.dart.DARTBasic;
    import tagion.crypto.SecureInterfaceNet : HashNet;

    //import tagion.basic.basic;
    import tagion.basic.tagionexceptions : Check;
    import tagion.utils.Miscellaneous : toHex = toHexString;

    import std.stdio : writeln, writefln;
    import tagion.hibon.HiBONRecord;
    import tagion.hibon.HiBONJSON : toPretty;

    import tagion.dart.RimKeyRange : rimKeyRange;
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
ubyte rim_key(F)(F rim_keys, const uint rim) pure if (isBufferType!F) {
    if (rim >= rim_keys.length) {
        debug __write("%s rim=%d", rim_keys.hex, rim);
    }
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
    import tagion.crypto.Types : Fingerprint;
    import std.stdio;

    ubyte[] buf1 = [0xA7];
    assert(sector(buf1) == 0xA700);
    assert(sector(cast(Fingerprint)[0xA7, 0x15]) == 0xA715);
    Buffer buf2 = [0xA7, 0x15, 0xE3];
    assert(sector(buf2) == 0xA715);

}

enum SECTOR_MAX_SIZE = 1 << (ushort.sizeof * 8);

import std.algorithm;

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

    import tagion.dart.BlockFile : Index;

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
    static create(string filename, const HashNet net, const uint block_size = MIN_BLOCK_SIZE)
    in {
        assert(block_size >= MIN_BLOCK_SIZE,
                format("Block size is too small for %s, %d must be langer than %d", filename, block_size, MIN_BLOCK_SIZE));
    }
    do {
        BlockFile.create(filename, net.multihash, block_size, DARTFile.stringof);
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
        import std.stdio;

        if (table.length != KEY_SPAN) {
            writefln("table_length: %s", table.length);
        }
        assert(table.length == KEY_SPAN);
    }
    do {
        // if (table.length == 0) {
        //     return null;
        // }
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
                return net.binaryHash(_left_fingerprint, _right_fingerprint);
            }
        }

        immutable mid = table.length >> 1;
        return merkletree(table[0 .. mid], table[mid .. $]);
    }

    @safe struct Leave {
        import tagion.hibon.HiBONRecord;

        Index index;
        Buffer fingerprint;

        bool empty() pure const nothrow {
            return (index is Index.init) && (fingerprint is null);
        }

        mixin HiBONRecord!(q{ 
            this(const Index index, Buffer fingerprint) {
                this.index = index;
                this.fingerprint = fingerprint;

            }

            this(const Index index, DARTIndex hash_pointer) {
                this.index = index;
                this.fingerprint = cast(Buffer) hash_pointer;

            }
        });
    }

    /**
 * Data struct which contains the branches in sub-tree
 */
    @recordType("Branches") struct Branches {
        import std.stdio;
        import tagion.hibon.HiBONJSON;

        @label("") protected Buffer merkleroot; /// The sparsed Merkle root hash of the branches
        @label("$prints", true) @(record_filter.Initialized) protected Buffer[] _fingerprints; /// Array of all the Leaves hashes
        @label("$idx", true) @(record_filter.Initialized) protected Index[] _indices; /// Array of index pointer to BlockFile
        @label("") private bool done;
        enum fingerprintsName = GetLabel!(_fingerprints).name;
        enum indicesName = GetLabel!(_indices).name;
        this(Document doc) {

            

                .check(isRecord(doc), format("Document is not a %s", ThisType.stringof));
            if (doc.hasMember(indicesName)) {
                _indices = new Index[KEY_SPAN];
                foreach (e; doc[indicesName].get!Document[]) {
                    _indices[e.index] = e.get!Index;
                }
            }
            if (doc.hasMember(fingerprintsName)) {
                _fingerprints = new Buffer[KEY_SPAN];
                foreach (e; doc[fingerprintsName].get!Document) {
                    _fingerprints[e.index] = e.get!(immutable(ubyte)[]).idup;
                }
            }
        }

        auto keys() {
            return _fingerprints.enumerate
                .filter!(f => !f.value.empty)
                .map!(f => f.index);
        }

        auto opSlice() {
            return keys.map!(key => Leave(indices[key], fingerprints[key]));
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
        const(Index[]) indices() pure const nothrow {
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
                    if (index !is Index.init) {
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

        import tagion.hibon.HiBONRecord : HiBONRecordType;

        mixin HiBONRecordType;

        /**
         * Get the index number of Leave at the leave number key
         *
         * Params:
         *     key = Leave number of the branches
         *
         */
        Index index(const uint key) pure const {
            if (empty) {
                return Index.init;
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
                _indices = new Index[KEY_SPAN];
            }
            if (_fingerprints is null) {
                _fingerprints = new Buffer[KEY_SPAN];
            }
            _indices[key] = Index(leave.index);
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
                return Leave(Index.init, null);
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
                DARTFile dartfile) {
            if (merkleroot is null) {
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
                if (index !is Index.init) {
                    writefln("branches[%02X]=%s", key, _fingerprints[key].toHex);
                }
            }

        }
        /** 
         * 
         * Returns: true if there is only one fingerprint left else false
         */
        bool isSingle() pure const nothrow @nogc {
            import std.range : take, walkLength;

            return _fingerprints
                .filter!(f => f !is null)
                .take(2)
                .walkLength == 1;
        }
    }

    /** 
    * Reads the data at branch key  
    * Params: 
    *    b = branches to read from
    *    key = key in the branch to read from 
    * Returns: the data a key
    */
    Document load(ref const(Branches) b, const uint key) {
        if ((key < KEY_SPAN) && (b.indices)) {
            immutable index = b.indices[key];
            if (index !is Index.init) {
                return blockfile.load(index);
            }
        }
        return Document.init;
    }

    @safe
    class RimWalkerFiber : Fiber {
        immutable(Buffer) rim_paths;
        protected Document doc;
        protected bool _finished;
        /** 
         * Sector for the walker
         * Returns: the sector of the rim
         */
        ushort sector() const pure nothrow
        in {
            assert(rim_paths.length >= ubyte.sizeof, assumeWontThrow(format(
                    "rim_paths is too short %d >= %d", rim_paths
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
            assert(rim_paths.length >= ubyte.sizeof, format(
                    "Size of rim_paths should have a size of %d or more", ubyte
                    .sizeof));
        }
        do {
            this.rim_paths = rim_paths;
            super(&run);
            popFront;
        }

        final private void run() {
            void traverse(
                    immutable Index index,
                    immutable uint rim = 0) @safe {
                if (index !is Index.init) {
                    doc = this.outer.blockfile.load(index);
                    assert(!doc.empty, "Loaded document should not be empty");
                    //const doc = Document(data);
                    if (rim < rim_paths.length) {
                        if (Branches.isRecord(doc)) {
                            const branches = Branches(doc);
                            // This branches
                            immutable key = rim_key(rim_paths, rim);
                            immutable next_index = branches.indices[key];
                            traverse(next_index, rim + 1);
                        }
                    }
                    else {
                        if (Branches.isRecord(doc)) {
                            const branches = Branches(doc);
                            foreach (next_index; branches.indices) {
                                traverse(next_index, rim + 1);
                            }
                        }
                        else {
                            assumeTrusted!yield;
                        }
                    }
                }
            }

            traverse(this.outer.blockfile.masterBlock.root_index);
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
        final const(Document) front() const pure nothrow {
            return doc;
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
                const Index branch_index,
                const ubyte rim_key = 0,
                const uint rim = 0) @safe {
            if (branch_index !is Index.init) {
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
                recorder.insert(doc, type);
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
            Archive.Type type = Archive.Type.REMOVE) if (isInputRange!Range && isBufferType!(ElementType!Range)) {

        import std.algorithm.comparison : min;

        auto result = recorder;
        void traverse_dart(
                const Index branch_index,
                Buffer[] ordered_fingerprints,
                immutable uint rim = 0) @safe {
            if ((ordered_fingerprints) && (branch_index !is Index.init)) {
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

        auto sorted_fingerprints = fingerprints
            .filter!(a => a.length !is 0)
            .map!(a => cast(Buffer) a)
            .array
            .dup;
        sorted_fingerprints.sort;
        traverse_dart(blockfile.masterBlock.root_index, sorted_fingerprints);
        return result;
    }

    enum RIMS_IN_SECTOR = 2;

    /// Wrapper function for the modify function.
    Buffer modify(const(RecordFactory.Recorder) modifyrecords, const Flag!"undo" undo = No.undo) {
        if (undo) {
            return modify!(Yes.undo)(modifyrecords);
        }
        else {
            return modify!(No.undo)(modifyrecords);

        }
    }
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
     * The modifyrecords contains the archives which is going to be added or deleted
     * The type of archive tells which actions are going to be performed by the modifier
     * If the function executes succesfully then the DART is updated or else it does not affect the DART
     * The function returns the bullseye of the dart
     */
    Buffer modify(Flag!"undo" undo)(const(RecordFactory.Recorder) modifyrecords) {

        /** 
         * Inner function for the modify function.
         * Note that this function is recursive and called from itself. 
         * Can be broken up into 3 sections. The first is for going through the branches
         * In the sectors. Next section is for going through branches deeper than the sectors.
         * The last section is responsible for acutally doing the work with the archives.
         * Params:
         *   range = RimKeyRange to traverse with.
         *   branch_index = The branch index to modify.
         * Returns: 
         */
        Leave traverse_dart(Range)(Range range, const Index branch_index) @safe if (isInputRange!Range)
        out {
            assert(range.empty, "Must have been through the whole range and therefore empty on return");
        }
        do {
            // if the range is empty that means that nothing is located in it now. 
            if (range.empty) {
                return Leave.init;
            }

            /// First section for going through the Branches in the sectors.
            Index erase_block_index;
            scope (success) {
                blockfile.dispose(erase_block_index);
            }
            Branches branches;
            if (range.rim < RIMS_IN_SECTOR) {
                if (branch_index !is Index.init) {
                    branches = blockfile.load!Branches(branch_index);

                    

                    .check(branches.hasIndices,
                            "DART failure within the sector rims the DART should contain a branch");
                }

                while (!range.empty) {
                    auto sub_range = range.nextRim;
                    immutable rim_key = sub_range.front.fingerprint.rim_key(sub_range.rim);
                    branches[rim_key] = traverse_dart(sub_range, branches.index(rim_key));
                }
                erase_block_index = Index(branch_index);

                if (branches.empty) {
                    return Leave.init;
                }

                return Leave(blockfile.save(branches).index,
                        branches.fingerprint(this));

            }
            // Section for going through branches that are not in the sectors.
            else {
                if (branch_index !is Index.init) {
                    const doc = blockfile.cacheLoad(branch_index);
                    if (Branches.isRecord(doc)) {
                        branches = Branches(doc);
                        while (!range.empty) {
                            auto sub_range = range.nextRim;
                            immutable rim_key = sub_range.front.fingerprint.rim_key(sub_range.rim);
                            branches[rim_key] = traverse_dart(sub_range, branches.index(rim_key));
                        }
                        // if the range is empty then we return a null leave.
                        if (branches.empty) {
                            return Leave.init;
                        }

                        if (branches.isSingle && range.rim >= RIMS_IN_SECTOR) {
                            const single_leave = branches[].front;
                            const buf = cacheLoad(single_leave.index);
                            const single_doc = Document(buf);

                            if (!Branches.isRecord(single_doc)) {
                                return single_leave;
                            }

                        }
                        return Leave(blockfile.save(branches).index, branches.fingerprint(this));
                    }
                    else {
                        // This is a standalone archive ("single").
                        // DART does not store a branch this means that it contains a leave.
                        // Leave means and archive
                        // The new Archives is constructed to include the archive which is already in the DART
                        auto current_archive = recorder.archive(doc, Archive.Type.ADD);
                        scope (success) {
                            // The archive is erased and it will be added again to the DART
                            // if it not removed by and action in the record
                            blockfile.dispose(branch_index);

                        }
                        auto sub_range = range.save.filter!(a => a.fingerprint == current_archive.fingerprint);

                        if (sub_range.empty) {
                            range.add(current_archive);
                        }

                    }
                }
                // If there is only one archive left, it means we have traversed to the bottom of the tree
                // Therefore we must return the leave if it is an ADD.
                if (range.oneLeft) {
                    scope (exit) {
                        range.popFront;
                    }
                    if (range.type == Archive.Type.ADD) {
                        return Leave(blockfile.save(range.front.store).index, range
                                .front.fingerprint);
                    }
                    return Leave.init;
                }
                /// More than one archive is present. Meaning we have to traverse
                /// Deeper into the tree.
                while (!range.empty) {
                    const rim_key = range.front.fingerprint.rim_key(range.rim + 1);

                    const leave = traverse_dart(range.nextRim, Index.init);
                    branches[rim_key] = leave;
                }
                /// If the branch is empty we return a NULL leave.
                if (branches.empty) {
                    return Leave.init;
                }
                // If the branch isSingle then we have to move the branch / archives located in it upwards.
                if (branches.isSingle) {
                    const single_leave = branches[].front;
                    const buf = cacheLoad(single_leave.index);
                    const single_doc = Document(buf);

                    if (!Branches.isRecord(single_doc)) {
                        return single_leave;
                    }

                }
                return Leave(blockfile.save(branches)
                        .index, branches.fingerprint(this));
            }

        }

        /// If our records is empty we return the previous fingerprint
        if (modifyrecords.empty) {
            return _fingerprint;
        }

        // This check ensures us that we never have multiple add and deletes on the
        // same archive in the same recorder.
        .check(modifyrecords.length <= 1 ||
                    !modifyrecords[].slide(2).map!(a => a.front.fingerprint == a.dropOne.front.fingerprint)
                        .any,
                        "cannot have multiple operations on same fingerprint in one modify");

        auto range = rimKeyRange!undo(modifyrecords);
        immutable new_root = traverse_dart(range, blockfile.masterBlock.root_index);

        scope (success) {
            // On success the new root_index is set and the DART is updated
            _fingerprint = new_root.fingerprint;
            if ((new_root.fingerprint is null) || (new_root.index is Index.init)) {
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

    /** 
     * Loads the branches from the DART at rim_path
     * Params:
     *   rim_path = rim path select the branches
     * Returns:
     *   the branches a the rim_path
     */
    Branches branches(const(ubyte[]) rim_path) {
        Branches search(const(ubyte[]) rim_path, const Index index, const uint rim = 0) {
            const doc = blockfile.load(index);
            if (Branches.isRecord(doc)) {
                Branches branches = Branches(doc);
                if (rim < rim_path.length) {
                    immutable rim_key = rim_path.rim_key(rim);
                    immutable sub_index = branches._indices[rim_key];
                    if (sub_index !is Index.init) {
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

        if (blockfile.masterBlock.root_index is Index.init) {
            return Branches();
        }
        return search(rim_path, blockfile.masterBlock.root_index);
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
        void local_dump(const Index branch_index,
                const ubyte rim_key = 0,
                const uint rim = 0,
                string indent = null) @safe {
            if (branch_index !is Index.init) {
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

    package Document cacheLoad(const Index index) {
        return Document(blockfile.cacheLoad(index));
    }

    version (unittest) {

        static {
            bool check(const(RecordFactory.Recorder) A, const(RecordFactory.Recorder) B) {
                return equal!(q{a.fingerprint == b.fingerprint})(A.archives[], B.archives[]);
            }

            Buffer write(DARTFile dart, const(ulong[]) table, out RecordFactory.Recorder rec) {
                rec = records(dart.manufactor, table);
                return dart.modify(rec);
            }

            Buffer[] fingerprints(RecordFactory.Recorder recorder) {
                Buffer[] results;
                foreach (a; recorder.archives) {
                    results ~= cast(Buffer) a.fingerprint;
                }
                return results;

            }

            bool validate(DARTFile dart, const(ulong[]) table, out RecordFactory
                .Recorder recorder) {
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

            RecordFactory.Recorder recordsRemove(RecordFactory factory, const(ulong[]) table) {
                auto rec = factory.recorder;
                foreach (t; table) {
                    const doc = DARTFakeNet.fake_doc(t);
                    rec.remove(doc);
                }
                return rec;
            }

        }

    }
}

version (unittest) {
    import tagion.dart.DARTFakeNet;
    import tagion.dart.RimKeyRange;
    import std.internal.math.biguintx86;
}
///
@safe
unittest {
    import std.algorithm.sorting : sort;

    import std.stdio : writefln; //    import tagion.basic.basic;
    import std.typecons;
    import tagion.utils.Random;
    import std.bitmanip : BitArray;
    import tagion.utils.Miscellaneous : cutHex;
    import tagion.hibon.HiBONJSON : toPretty;
    import tagion.basic.basic : forceRemove;

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
        0x20_21_11_33_40_50_80_90,
        0x20_21_20_32_30_40_50_80,

        0x20_21_20_32_31_40_50_80, // rim 4 test
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
            auto root_range = rimKeyRange(recorder);
            auto rim_range = root_range.selectRim(3);

            i = 0;
            immutable key = rim_range.front.fingerprint.rim_key(rim);
            foreach (a; rim_range) {
                while (net.dartIndex(DARTFakeNet.fake_doc(test_tabel[i])).rim_key(rim) !is key) {
                    i++;
                }
                i++;
            }
        }
    }

    { // Rim 2 test
        filename.forceRemove;
        DARTFile.create(filename, net);
        auto dart = new DARTFile(net, filename);
        RecordFactory.Recorder recorder;
        assert(DARTFile.validate(dart, table[0 .. 4], recorder));
    }

    { // Rim 3 test
        filename.forceRemove;

        DARTFile.create(filename, net);
        auto dart = new DARTFile(net, filename);
        RecordFactory.Recorder recorder;
        //=Recorder(net);
        assert(DARTFile.validate(dart, table[4 .. 9], recorder));
        // dart.dump;
    }

    { // Rim 4 test
        filename.forceRemove;
        DARTFile.create(filename, net);
        auto dart = new DARTFile(net, filename);
        RecordFactory.Recorder recorder;

        assert(DARTFile.validate(dart, table[17 .. $], recorder));
        // dart.dump;
    }

    { // Rim 2 & 3
        filename.forceRemove;
        DARTFile.create(filename, net);
        auto dart = new DARTFile(net, filename);
        RecordFactory.Recorder recorder;

        assert(DARTFile.validate(dart, table[0 .. 9], recorder));
        // dart.dump;
    }

    { // Rim 2 & 3 & 4
        filename.forceRemove;
        DARTFile.create(filename, net);
        auto dart = new DARTFile(net, filename);
        RecordFactory.Recorder recorder;

        assert(DARTFile.validate(dart, table[0 .. 9] ~ table[17 .. $], recorder));
        // dart.dump;
    }

    { // Rim all
        filename.forceRemove;
        DARTFile.create(filename, net);
        auto dart = new DARTFile(net, filename);
        RecordFactory.Recorder recorder;

        assert(DARTFile.validate(dart, table, recorder));
        // dart.dump;
    }

    { // Remove two archives and check the bulleye
        immutable file_A = fileId!DARTFile("XA").fullpath;
        immutable file_B = fileId!DARTFile("XB").fullpath;

        DARTFile.create(file_A, net);
        DARTFile.create(file_B, net);

        RecordFactory.Recorder recorder_A;
        RecordFactory.Recorder recorder_B;
        auto dart_A = new DARTFile(net, file_A);
        auto dart_B = new DARTFile(net, file_B);
        //
        DARTFile.write(dart_A, table, recorder_A);
        // table 8 and 9 is left out
        auto bulleye_B = DARTFile.write(dart_B, table[0 .. 8] ~ table[10 .. $], recorder_B);

        //dart_A.dump;
        //dart_B.dump;
        auto remove_recorder = DARTFile.recordsRemove(manufactor, table[8 .. 10]);

        auto bulleye_A = dart_A.modify(remove_recorder);
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
        DARTFile.create(filename_A, net);
        DARTFile.create(filename_B, net);
        RecordFactory.Recorder recorder_A;
        RecordFactory.Recorder recorder_B;
        auto dart_A = new DARTFile(net, filename_A);
        auto dart_B = new DARTFile(net, filename_B);
        //

        auto bulleye_A = DARTFile.write(dart_A, random_table, recorder_A);
        auto bulleye_B = DARTFile.write(dart_B, random_table[0 .. N - 100], recorder_B);
        auto remove_recorder = DARTFile.recordsRemove(manufactor, random_table[N - 100 .. N]);

        bulleye_A = dart_A.modify(remove_recorder);
        // dart_A.dump;

        // The bull eye of the two DART must be the same
        assert(bulleye_A == bulleye_B);
    }
    { // DARTFile.write on to an existing DART and the bulleye is check
        // This test is based on the next random test. Where an error was found. Do not delete.
        const from_random_table = [
            0xABBA_1234_DF92_7BA7UL, // add first time
            0xABBA_1234_62BD_7814UL, // add first time
            0xABBA_1234_DFA5_2B29UL,
        ];
        filename_A.forceRemove;
        filename_B.forceRemove;
        DARTFile.create(filename_A, net);
        DARTFile.create(filename_B, net);
        RecordFactory.Recorder recorder_A;
        RecordFactory.Recorder recorder_B;
        auto dart_A = new DARTFile(net, filename_A);
        auto dart_B = new DARTFile(net, filename_B);
        //

        DARTFile.write(dart_A, from_random_table[0 .. 2], recorder_A);
        // writeln("0->2");
        // dart_A.dump;
        auto bulleye_A = DARTFile.write(dart_A, from_random_table[2 .. 3], recorder_A);
        // writeln("4->5");
        // dart_A.dump;
        //assert(0);
        auto bulleye_B = DARTFile.write(dart_B, from_random_table, recorder_B);
        // writeln("DART B: 0->2 & 4->5");
        // dart_B.dump;

        // The bull eye of the two DART must be the same
        assert(bulleye_A == bulleye_B);
    }

    { // Random DARTFile.write on to an existing DART and the bulleye is check
        auto rand = Random!ulong(1234_5678_9012_345UL);
        enum N = 100;
        auto random_table = new ulong[N];
        foreach (ref r; random_table) {
            r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
        }
        filename_A.forceRemove;
        filename_B.forceRemove;
        DARTFile.create(filename_A, net);
        DARTFile.create(filename_B, net);
        RecordFactory.Recorder recorder_A;
        RecordFactory.Recorder recorder_B;
        auto dart_A = new DARTFile(net, filename_A);
        auto dart_B = new DARTFile(net, filename_B);
        //

        DARTFile.write(dart_A, random_table[0 .. 29], recorder_A);
        // dart_A.dump;
        auto bulleye_A = DARTFile.write(dart_A, random_table[34 .. 100], recorder_A);
        // dart_A.dump;
        //assert(0);
        auto bulleye_B = DARTFile.write(dart_B, random_table[0 .. 29] ~ random_table[34 .. 100], recorder_B);
        // dart_B.dump;

        // The bullseye of the two DART must be the same
        assert(bulleye_A == bulleye_B);
    }

    { // Random remove and the bullseye is checked
        auto rand = Random!ulong(1234_5678_9012_345UL);
        enum N = 1000;
        auto random_table = new ulong[N];
        foreach (ref r; random_table) {
            r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
        }
        filename_A.forceRemove;
        filename_B.forceRemove;
        DARTFile.create(filename_A, net);
        DARTFile.create(filename_B, net);
        RecordFactory.Recorder recorder_A;
        RecordFactory.Recorder recorder_B;
        auto dart_A = new DARTFile(net, filename_A);
        auto dart_B = new DARTFile(net, filename_B);
        //

        auto bulleye_A = DARTFile.write(dart_A, random_table, recorder_A);
        auto bulleye_B = DARTFile.write(dart_B, random_table[0 .. N - 100], recorder_B);
        auto remove_recorder = DARTFile.recordsRemove(manufactor, random_table[N - 100 .. N]);
        bulleye_A = dart_A.modify(remove_recorder);
        // dart_A.dump;
        // The bull eye of the two DART must be the same
        assert(bulleye_A == bulleye_B);
    }

    { // Random DARTFile.write and then bullseye is checked
        auto rand = Random!ulong(1234_5678_9012_345UL);
        enum N = 1000;
        auto random_table = new ulong[N];
        foreach (ref r; random_table) {
            r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
        }
        filename_A.forceRemove;
        filename_B.forceRemove;
        DARTFile.create(filename_A, net);
        DARTFile.create(filename_B, net);
        RecordFactory.Recorder recorder_A;
        RecordFactory.Recorder recorder_B;
        auto dart_A = new DARTFile(net, filename_A);
        auto dart_B = new DARTFile(net, filename_B);

        DARTFile.write(dart_A, random_table[0 .. 333], recorder_A);
        DARTFile.write(dart_B, random_table[0 .. 777], recorder_B);
        auto bulleye_A = DARTFile.write(dart_A, random_table[333 .. $], recorder_A);
        auto bulleye_B = DARTFile.write(dart_B, random_table[777 .. $], recorder_B);

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
        filename_A.forceRemove;
        filename_B.forceRemove;
        DARTFile.create(filename_A, net);
        DARTFile.create(filename_B, net);

        auto dart_A = new DARTFile(net, filename_A);
        auto dart_B = new DARTFile(net, filename_B);
        RecordFactory.Recorder recorder_A;
        RecordFactory.Recorder recorder_B;

        DARTFile.write(dart_A, random_table, recorder_A);
        DARTFile.write(dart_B, random_table, recorder_B);
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
        enum N = 1000;
        auto random_table = new ulong[N];
        foreach (ref r; random_table) {
            r = rand.value(0xABBA_1234_5678_0000UL, 0xABBA_1234_FFFF_0000UL);
        }
        filename_A.forceRemove;
        filename_B.forceRemove;
        DARTFile.create(filename_A, net);
        DARTFile.create(filename_B, net);
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
                //recorder.dump;
                dart_A.modify(recorder);
                saved_archives |= added_archives;
                saved_archives &= ~removed_archives;
                // dart_A.dump;
            }
            auto recorder_B = dart_B.recorder;

            saved_archives.bitsSet.each!(
                n => recorder_B.add(net.fake_doc(random_table[n])));
            dart_B.modify(recorder_B);
            // dart_B.dump;
            assert(dart_A.fingerprint == dart_B.fingerprint);
        })();
    }

    {
        // The bug we want to find
        //  EYE: abb913ab11ef1234000000000000000000000000000000000000000000000000
        //  | AB [17]
        //  | .. | B9 [16]
        //  | .. | .. | 13 [15]
        //  | .. | .. | .. | AB [14]
        //  | .. | .. | .. | .. abb913ab11ef1234000000000000000000000000000000000000000000000000 [7]
        // As it can be seen the branch has not snapped back to the first rim. The database should instead look like 
        // this:
        //  | AB [17]
        //  | .. | .. abb913ab11ef1234000000000000000000000000000000000000000000000000 [7]

        import std.algorithm : map;
        import std.range : empty;
        import std.format;

        size_t numberOfArchives(DARTFile.Branches branches, DARTFile db) {
            return branches.indices
                .filter!(i => i !is Index.init)
                .map!(i => DARTFile.Branches.isRecord(db.cacheLoad(i)))
                .walkLength;

        }

        {
            filename_A.forceRemove;
            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_13ab_11ef_0923,
                0xABB9_13ab_11ef_1234,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }
            auto remove_fingerprint = DARTIndex(recorder[].front.fingerprint);
            // writefln("%s", remove_fingerprint);

            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(remove_fingerprint);
            dart_A.modify(remove_recorder);
            // dart_A.dump();

            auto branches = dart_A.branches([0xAB, 0xB9]);

            assert(numberOfArchives(branches, dart_A) == 1, "Branch not snapped back to rim 2");

        }

        {
            // this test is just a support to see how the real result should be of the previous test.
            filename_A.forceRemove;
            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong archive = 0xABB9_13ab_11ef_0234;

            auto doc = DARTFakeNet.fake_doc(archive);
            auto recorder = dart_A.recorder();

            recorder.add(doc);

            auto fingerprint = DARTIndex(recorder[].front.fingerprint);
            dart_A.modify(recorder);

            // dart_A.dump();
            assert(dart_A.bullseye == fingerprint);

            auto branches = dart_A.branches([0xAB, 0xB9]);

            assert(numberOfArchives(branches, dart_A) == 1, "Branch not snapped back to rim 2");
        }
        {
            // middle branch test.
            // we start by creating the following archive structure.
            // EYE: 88aed312de6a292c4f3c80267b9272b32e39af749ceef8723e66c91c1872e056
            // | AB [9]
            // | .. | B9 [8]
            // | .. | .. | 13 [7]
            // | .. | .. | .. | AB [6]
            // | .. | .. | .. | .. | 11 [4]
            // | .. | .. | .. | .. | .. | EF [3]
            // | .. | .. | .. | .. | .. | .. abb913ab11ef0923 [1]
            // | .. | .. | .. | .. | .. | .. abb913ab11ef1234 [2]
            // | .. | .. | .. | .. abb913ab1213 [5]

            // now we remove one of the archives located in EF [3]. Then we should get the following.
            // EYE: 9428892e35b550187e8ff0a0d612bbd94029dbf6d7780cf29b66a8d5f8d10f58
            // | AB [15]
            // | .. | B9 [14]
            // | .. | .. | 13 [13]
            // | .. | .. | .. | AB [12]
            // | .. | .. | .. | .. abb913ab11ef [2]
            // | .. | .. | .. | .. abb913ab1213 [5]
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_13ab_11ef_0923,
                0xABB9_13ab_11ef_1234,
                0xABB9_13ab_1213_5678,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }
            auto remove_fingerprint = DARTIndex(recorder[].front.fingerprint);
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(remove_fingerprint);
            dart_A.modify(remove_recorder);

            ubyte[] rim_path = [0xAB, 0xB9, 0x13, 0xab];
            auto branches = dart_A.branches(rim_path);

            assert(numberOfArchives(branches, dart_A) == 2, "Branch not snapped back");

            // dart_A.dump();
        }

        {
            // ADD ADD REMOVE
            // we start by creating the following archive structure.
            // | AB [9]
            // | .. | B9 [8]
            // | .. | .. | 13 [7]
            // | .. | .. | .. | AB [6]
            // | .. | .. | .. | .. | 11 [4]
            // | .. | .. | .. | .. | .. | EF [3]
            // | .. | .. | .. | .. | .. | .. abb913ab11ef0923 [1]
            // | .. | .. | .. | .. | .. | .. abb913ab11ef1234 [2]

            // now we remove one of the archives located in EF [3]. And add another archive afterwards in the same recorder.
            // EYE: f32ee782a2576cdb57cc36c9e64409f36aa7747dd6c4ff1df8166b268b6ee0b1
            // | AB [17]
            // | .. | B9 [16]
            // | .. | .. | 13 [15]
            // | .. | .. | .. | AB [14]
            // | .. | .. | .. | .. | 11 [13]
            // | .. | .. | .. | .. | .. | EF [12]
            // | .. | .. | .. | .. | .. | .. abb913ab11ef1234 [2]
            // | .. | .. | .. | .. | .. | .. abb913ab11ef2078 [11]
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            // writefln("dartfilename=%s", filename_A);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_13ab_11ef_0923,
                0xABB9_13ab_11ef_1234,
                0xABB9_13ab_11ef_2078,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a)).array;
            auto recorder = dart_A.recorder();

            assert(docs.length == 3);
            recorder.add(docs[0]);
            recorder.add(docs[1]);
            auto remove_fingerprint = DARTIndex(recorder[].front.fingerprint);

            dart_A.modify(recorder);
            // dart_A.dump();

            auto next_recorder = dart_A.recorder();
            next_recorder.remove(remove_fingerprint);
            next_recorder.add(docs[2]);
            // next_recorder[].each!q{a.dump};
            dart_A.modify(next_recorder);
            // dart_A.dump();

            ubyte[] rim_path = [0xAB, 0xB9, 0x13, 0xab, 0x11, 0xef];
            auto branches = dart_A.branches(rim_path);

            assert(numberOfArchives(branches, dart_A) == 2, "Should contain two archives");

        }

        {
            // Double snap back. Add 2 x 2 archives and remove one in each so both branches should snap back.
            // EYE: 13c0d1bdc484c65f84968f8bcd1eb873520cfda16c070fdac4f5eb54f1fa54d9
            // | AB [11]
            // | .. | B9 [10]
            // | .. | .. | 13 [9]
            // | .. | .. | .. | AB [8]
            // | .. | .. | .. | .. | 11 [4]
            // | .. | .. | .. | .. | .. | EF [3]
            // | .. | .. | .. | .. | .. | .. abb913ab11ef0923 [1]
            // | .. | .. | .. | .. | .. | .. abb913ab11ef1234 [2]
            // | .. | .. | .. | .. | 12 [7]
            // | .. | .. | .. | .. | .. abb913ab121356 [5]
            // | .. | .. | .. | .. | .. abb913ab121412 [6]
            // Then the db should look like this:
            // EYE: a8db386daf51e78165021eae66ef072815d52bfcdd776e59f065a742e680ffb0
            // | AB [17]
            // | .. | B9 [16]
            // | .. | .. | 13 [15]
            // | .. | .. | .. | AB [14]
            // | .. | .. | .. | .. abb913ab11ef [2]
            // | .. | .. | .. | .. abb913ab1214 [6]
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_13ab_11ef_0923,
                0xABB9_13ab_11ef_1234,
                0xABB9_13ab_1213_5678,
                0xABB9_13ab_1214_1234,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }

            auto fingerprints = recorder[].map!(r => r.fingerprint).array;
            assert(fingerprints.length == 4);
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(fingerprints[0]);
            remove_recorder.remove(fingerprints[2]);
            dart_A.modify(remove_recorder);
            // dart_A.dump();

            ubyte[] rim_path = [0xAB, 0xB9, 0x13, 0xab];
            auto branches = dart_A.branches(rim_path);

            assert(numberOfArchives(branches, dart_A) == 2, "Should contain two archives");
        }

        {
            // we start with the following structure.
            // EYE: 96443dfcd4959c2698f1553976e18d7a7ab99b9c914967d9e0e6cd7bb3db5852
            // | AB [13]
            // | .. | B9 [12]
            // | .. | .. | 13 [11]
            // | .. | .. | .. abb9130b11 [1]
            // | .. | .. | .. | AB [10]
            // | .. | .. | .. | .. abb913ab11ef [2]
            // | .. | .. | .. | .. | 12 [9]
            // | .. | .. | .. | .. | .. abb913ab12de56 [3]
            // | .. | .. | .. | .. | .. | EF [8]
            // | .. | .. | .. | .. | .. | .. abb913ab12ef1354 [4]
            // | .. | .. | .. | .. | .. | .. | 56 [7]
            // | .. | .. | .. | .. | .. | .. | .. abb913ab12ef565600 [5]
            // | .. | .. | .. | .. | .. | .. | .. abb913ab12ef567800 [6]
            // EYE: a3f372ca07524db275e0bd8445af237c7827e97c7cb9d50d585b6798f0da3be0
            // then we remove the last one. we should get this.
            // | AB [21]
            // | .. | B9 [20]
            // | .. | .. | 13 [19]
            // | .. | .. | .. abb9130b11 [1]
            // | .. | .. | .. | AB [18]
            // | .. | .. | .. | .. abb913ab11ef [2]
            // | .. | .. | .. | .. | 12 [17]
            // | .. | .. | .. | .. | .. abb913ab12de56 [3]
            // | .. | .. | .. | .. | .. | EF [16]
            // | .. | .. | .. | .. | .. | .. abb913ab12ef1354 [4]
            // | .. | .. | .. | .. | .. | .. abb913ab12ef5656 [5]
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_13ab_11ef_0923,
                0xABB9_130b_11ef_1234,
                0xABB9_13ab_12ef_5678,
                0xABB9_13ab_12ef_1354,
                0xABB9_13ab_12ef_5656,
                0xABB9_13ab_12de_5678,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }
            auto fingerprints = recorder[].map!(r => r.fingerprint).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(fingerprints[$ - 1]);

            dart_A.modify(remove_recorder);
            // dart_A.dump();

            ubyte[] rim_path = [0xAB, 0xB9, 0x13, 0xab, 0x12, 0xef];

            auto branches = dart_A.branches(rim_path);
            assert(numberOfArchives(branches, dart_A) == 2, "Should contain two archives after remove");

        }

        {
            // we start with the following structure.
            // EYE: 96443dfcd4959c2698f1553976e18d7a7ab99b9c914967d9e0e6cd7bb3db5852
            // | AB [13]
            // | .. | B9 [12]
            // | .. | .. | 13 [11]
            // | .. | .. | .. abb9130b11 [1]
            // | .. | .. | .. | AB [10]
            // | .. | .. | .. | .. abb913ab11ef [2]
            // | .. | .. | .. | .. | 12 [9]
            // | .. | .. | .. | .. | .. abb913ab12de56 [3]
            // | .. | .. | .. | .. | .. | EF [8]
            // | .. | .. | .. | .. | .. | .. abb913ab12ef1354 [4]
            // | .. | .. | .. | .. | .. | .. | 56 [7]
            // | .. | .. | .. | .. | .. | .. | .. abb913ab12ef565600 [5]
            // | .. | .. | .. | .. | .. | .. | .. abb913ab12ef567800 [6]
            // now we remove the middle branch located at EF.
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_13ab_11ef_0923,
                0xABB9_130b_11ef_1234,
                0xABB9_13ab_12ef_5678,
                0xABB9_13ab_12ef_1354,
                0xABB9_13ab_12ef_5656,
                0xABB9_13ab_12de_5678,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }
            auto fingerprints = recorder[].map!(r => r.fingerprint).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(fingerprints[4]);

            dart_A.modify(remove_recorder);
            // dart_A.dump();

            ubyte[] rim_path = [0xAB, 0xB9, 0x13, 0xab, 0x12, 0xef];

            auto branches = dart_A.branches(rim_path);
            // writefln("XXX %s", numberOfArchives(branches, dart_A));
            assert(numberOfArchives(branches, dart_A) == 2, "Should contain two archives after remove");

        }

        {
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_13ab_11ef_0923,
                0xABB9_130b_11ef_1234,
                0xABB9_13ab_12ef_5678,
                0xABB9_13ab_12ef_1354,
                0xABB9_13ab_12ef_5656,
                0xABB9_13ab_12de_5678,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }
            auto fingerprints = recorder[].map!(r => r.fingerprint).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(fingerprints[4]);
            remove_recorder.remove(fingerprints[3]);

            dart_A.modify(remove_recorder);
            // dart_A.dump();

            ubyte[] rim_path = [0xAB, 0xB9, 0x13, 0xab, 0x12];

            auto branches = dart_A.branches(rim_path);
            // writefln("XXX %s", numberOfArchives(branches, dart_A));
            assert(numberOfArchives(branches, dart_A) == 2, "Should contain two archives after remove");

        }

        {
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_13ab_11ef_0923,
                0xABB9_130b_3456_1234,
                0xABB9_13ab_11ef_1234,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }
            auto fingerprints = recorder[].map!(r => r.fingerprint).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(fingerprints[1]);
            remove_recorder.remove(fingerprints[2]);

            dart_A.modify(remove_recorder);
            // dart_A.dump();

            ubyte[] rim_path = [0xAB, 0xB9];

            auto branches = dart_A.branches(rim_path);
            // // writefln("XXX %s", numberOfArchives(branches, dart_A));
            assert(numberOfArchives(branches, dart_A) == 1, "Should contain one archives after remove");

        }
        {
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_130b_11ef_0923,
                0xABB9_13ab_3456_1234,
                0xABB9_130b_11ef_1234,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }
            auto fingerprints = recorder[].map!(r => r.fingerprint).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(fingerprints[0]);
            remove_recorder.remove(fingerprints[1]);

            dart_A.modify(remove_recorder);
            // dart_A.dump();

            ubyte[] rim_path = [0xAB, 0xB9];

            auto branches = dart_A.branches(rim_path);
            // // writefln("XXX %s", numberOfArchives(branches, dart_A));
            assert(numberOfArchives(branches, dart_A) == 1, "Should contain one archives after remove");

        }

        {
            // add two of the same archives and remove it. The bullseye should be null.
            filename_A.forceRemove;

            // writefln("two same archives");
            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_130b_11ef_0923,
                0xABB9_130b_11ef_0923,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }
            auto remove_fingerprint = DARTIndex(recorder[].front.fingerprint);
            // writefln("%s", remove_fingerprint);

            dart_A.modify(recorder);
            // dart_A.dump();

            auto dart_blockfile = BlockFile(filename_A);
            // dart_blockfile.dump;
            dart_blockfile.close;

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(remove_fingerprint);
            dart_A.modify(remove_recorder);
            // writefln("after remove");
            // dart_A.dump();

            dart_blockfile = BlockFile(filename_A);
            // dart_blockfile.dump;
            dart_blockfile.close;

            assert(dart_A.bullseye == null);

        }

        { // add the same archive in different modifies. Should only contain one archive afterwards.
            // Test was created due to error were if the same archive was added it would remove the 
            // archive in the database.
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            auto doc = DARTFakeNet.fake_doc(0xABB9_130b_11ef_0923);
            auto recorder = dart_A.recorder();
            recorder.add(doc);
            dart_A.modify(recorder);
            assert(dart_A.bullseye == recorder[].front.fingerprint);
            dart_A.modify(recorder);

            assert(dart_A.bullseye == recorder[].front.fingerprint);
        }

        {
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);

            const ulong[] deep_table = [
                0xABB9_130b_11ef_0923,
                0xAB10_130b_11ef_0923,
            ];

            auto docs = deep_table.map!(a => DARTFakeNet.fake_doc(a));
            auto recorder = dart_A.recorder();
            foreach (doc; docs) {
                recorder.add(doc);
            }
            auto remove_fingerprint = DARTIndex(recorder[].front.fingerprint);
            // writefln("%s", remove_fingerprint);

            dart_A.modify(recorder);
            // dart_A.dump();

            auto dart_blockfile = BlockFile(filename_A);
            // dart_blockfile.dump;
            dart_blockfile.close;

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(remove_fingerprint);
            dart_A.modify(remove_recorder);
            // writefln("after remove");
            // dart_A.dump();

            dart_blockfile = BlockFile(filename_A);
            // dart_blockfile.dump;
            dart_blockfile.close;

            ubyte[] rim_path = [0xAB];

            auto branches = dart_A.branches(rim_path);
            assert(numberOfArchives(branches, dart_A) == 1, "Should contain one archives after remove");

        }
        {
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);
            dart_A.close;
            auto blockfile = BlockFile(filename_A);
            // blockfile.dump;
            blockfile.close;

            dart_A = new DARTFile(net, filename_A);
            assert(dart_A.bullseye == null);

        }
        { // name record unittests
            @recordType("name")
            static struct NameRecord {
                @label("#name") string name;
                string data;

                mixin HiBONRecord!(q{
                    this(const string name, const string data) {
                        this.name = name;
                        this.data = data;
                    }
                });
            }

            {
                filename_A.forceRemove;

                DARTFile.create(filename_A, net);
                auto dart_A = new DARTFile(net, filename_A);

                auto recorder = dart_A.recorder();

                auto name_record = NameRecord("jens", "10");

                recorder.add(name_record);

                dart_A.modify(recorder);

                auto fingerprint = recorder[].front.fingerprint;

                auto read_recorder = dart_A.loads([DARTIndex(fingerprint)]);

                auto read_name_record = NameRecord(read_recorder[].front.filed);
                // writefln(read_name_record.toPretty);
                // dart_A.dump;
                // auto blockfile = BlockFile(filename_A);
                // blockfile.dump;
                // blockfile.close;
                assert(read_name_record == name_record, "should be the same after reading");

                // we try to insert a namerecord with the same name. 
                // This should overwrite the namerecord in the database.
                // We insert a long string in order to see if we are not using the same
                // index afterwards.

                auto new_recorder = dart_A.recorder();

                auto new_name = NameRecord("jens", 'x'.repeat(200).array);
                new_recorder.add(new_name);
                dart_A.modify(new_recorder);
                auto new_fingerprint = new_recorder[].front.fingerprint;

                auto new_read_recorder = dart_A.loads([DARTIndex(new_fingerprint)]);
                auto new_read_name = NameRecord(new_read_recorder[].front.filed);
                // writefln(new_read_name.toPretty);
                // dart_A.dump;
                // auto new_blockfile = BlockFile(filename_A);
                // new_blockfile.dump;
                // new_blockfile.close;
                assert(new_read_name == new_name,
                        "Should not be updated, since the previous name record was not removed");

            }
            {
                // Namerecord. add the name to the DART
                // Then perform a manual REMOVE ADD with a different add data in the same recorder
                // should throw an exception since we cannot have multiple adds
                // and removes in same recorder
                import std.exception : assertThrown;

                filename_B.forceRemove;

                DARTFile.create(filename_B, net);
                auto dart_A = new DARTFile(net, filename_B);

                auto recorder = dart_A.recorder();

                auto name_record = NameRecord("hugo", "10");

                recorder.add(name_record);

                dart_A.modify(recorder);
                auto fingerprint = recorder[].front.fingerprint;
                auto read_recorder = dart_A.loads([DARTIndex(fingerprint)]);
                auto read_name_record = NameRecord(read_recorder[].front.filed);
                assert(read_name_record == name_record, "should be the same after reading");

                auto new_recorder = dart_A.recorder();
                auto new_name_record = NameRecord("hugo", 'x'.repeat(200).array);
                new_recorder.remove(name_record);
                new_recorder.add(new_name_record);
                // new_recorder.each!q{a.dump};
                auto rim_key_range = rimKeyRange(new_recorder);
                // writefln("rim key dump");
                // rim_key_range.each!q{a.dump};
                assertThrown!DARTException(dart_A.modify(new_recorder));

            }

        }

        { // undo test
            filename_A.forceRemove;

            DARTFile.create(filename_A, net);
            auto dart_A = new DARTFile(net, filename_A);
            RecordFactory.Recorder recorder;

            auto doc = DARTFakeNet.fake_doc(0xABB9_130b_11ef_0923);
            recorder = dart_A.recorder();
            recorder.add(doc);
            dart_A.modify(recorder);

            const bullseye = dart_A.bullseye;
            // dart_A.dump;
            auto new_doc = DARTFakeNet.fake_doc(0x2345_130b_1234_1234);
            recorder = dart_A.recorder();
            recorder.add(new_doc);
            dart_A.modify(recorder);
            const new_bullseye = dart_A.bullseye;
            dart_A.modify(recorder, Yes.undo);
            assert(dart_A.bullseye != new_bullseye,
                    "Should not be the same as the new bullseye after undo");
            assert(dart_A.bullseye == bullseye, "should have been reverted to previoius bullseye");
        }

    }

    { // undo test both with remove and adds
        filename_A.forceRemove;

        DARTFile.create(filename_A, net);
        auto dart_A = new DARTFile(net, filename_A);
        RecordFactory.Recorder recorder;

        const ulong[] datas = [
            0xABB9_130b_11ef_0923,
            0x1234_5678_9120_1234,
            0xABCD_1234_0000_0000,
        ];
        auto docs = datas.map!(a => DARTFakeNet.fake_doc(a));

        recorder = dart_A.recorder();

        foreach (doc; docs) {
            recorder.add(doc);
        }

        dart_A.modify(recorder);

        const bullseye = dart_A.bullseye;
        const fingerprints = recorder[].map!(a => a.fingerprint).array;

        auto new_doc = DARTFakeNet.fake_doc(0x2345_130b_1234_1234);
        recorder = dart_A.recorder();
        recorder.add(new_doc);
        foreach (fingerprint; fingerprints) {
            recorder.remove(fingerprint);
        }
        dart_A.modify(recorder);
        const new_bullseye = dart_A.bullseye;
        dart_A.modify(recorder, Yes.undo);
        assert(dart_A.bullseye != new_bullseye, "Should not be the same as the new bullseye after undo");
        assert(dart_A.bullseye == bullseye, "should have been reverted to previoius bullseye");

    }

}
