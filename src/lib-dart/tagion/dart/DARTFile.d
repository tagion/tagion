/// Handles the lower level operation of DART database
module tagion.dart.DARTFile;
@safe:
private {
    import core.thread : Fiber;
    import std.algorithm.comparison : equal;
    import std.algorithm.iteration : each, filter;
    import std.algorithm.searching : all, count, maxElement;
    import std.algorithm.sorting : sort;
    import std.array;
    import std.conv : to;
    import std.exception : assumeWontThrow;
    import std.format;
    import std.range;
    import std.range.primitives : ElementType, isInputRange;
    import std.stdio : File;
    import std.traits;
    import std.typecons : Flag, No, Yes;
    import std.typecons;
    import tagion.basic.Debug : __write;
    import tagion.basic.Types : Buffer, isBufferType, isTypedef, mut;
    import tagion.basic.basic : EnumText, assumeTrusted, isinit;
    import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
    import tagion.crypto.Types : Fingerprint;
    import tagion.dart.BlockFile;
    import tagion.dart.DARTBasic;
    import tagion.dart.DARTException : DARTException;
    import tagion.dart.Recorder;
    import tagion.hibon.Document : Document;
    import tagion.hibon.HiBON : HiBON;
    import tagion.hibon.HiBONRecord : GetLabel, exclude, record_filter = filter, label, recordType;

    //import tagion.basic.basic;
    //    import std.stdio : writefln, writeln;
    import tagion.basic.tagionexceptions : Check;
    import tagion.dart.DARTRim;
    import tagion.dart.RimKeyRange : rimKeyRange;
    import tagion.hibon.HiBONRecord;
    import std.bitmanip;
}

/++
 + Gets the rim key from a buffer
 +
 + Returns;
 +     fingerprint[rim]
 +/
ubyte rim_key(F)(F rim_keys, const uint rim) pure if (isBufferType!F) {
    if (rim >= rim_keys.length) {
        debug __write("%(%02X%) rim=%d", rim_keys, rim);
    }
    return rim_keys[rim];
}

enum SECTOR_MAX_SIZE = 1 << (ushort.sizeof * 8);

import std.algorithm;

alias check = Check!DARTException;
enum KEY_SPAN = ubyte.max + 1;

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
class DARTFile {
    enum default_flat = Yes.flat;
    import tagion.dart.BlockFile : Index;

    immutable(string) filename;
    const Flag!"flat" flat;
    protected RecordFactory manufactor;

    protected {
        BlockFile blockfile;
        Fingerprint _fingerprint;
    }

    protected enum _params = [
            "dart_indices",
            "bullseye",
        ];

    mixin(EnumText!("Params", _params));

    enum flat_marker = "flat";
    enum MIN_BLOCK_SIZE = 0x80;
    static create(string filename, const HashNet net, const uint block_size = MIN_BLOCK_SIZE, const uint max_size = 0x80_000, const Flag!"flat" flat = default_flat)
    in {
        assert(block_size >= MIN_BLOCK_SIZE,
                format("Block size is too small for %s, %d must be langer than %d", filename, block_size, MIN_BLOCK_SIZE));
    }
    do {
        auto id_name = net.multihash;
        if (flat) {
            id_name ~= ":" ~ flat_marker;
        }
        BlockFile.create(filename, id_name, block_size, DARTFile.stringof, max_size);
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
    this(const HashNet net, string filename, const Flag!"read_only" read_only = No.read_only) {
        blockfile = BlockFile(filename, read_only);
        this.manufactor = RecordFactory(net);
        this.filename = filename;

        

        .check(blockfile.headerBlock.checkLabel(DARTFile.stringof),
                format("Wrong label %s expected %s for %s",
                blockfile.headerBlock.Label,
                DARTFile.stringof, filename));

        Flag!"flat" checkId() {
            if (blockfile.headerBlock.checkId(net.multihash)) {
                return No.flat;
            }

            if (blockfile.headerBlock.checkId(net.multihash ~ ":" ~ flat_marker)) {
                return Yes.flat;
            }

            

            .check(false,
                    format("Wrong hash type %s expected %s for %s",
                    net.multihash, blockfile.headerBlock.Id, filename));

            assert(0);
        }

        flat = checkId;
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
    Fingerprint fingerprint() pure const nothrow {
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

    struct Leave {
        import tagion.hibon.HiBONRecord;

        Index index;
        Buffer fingerprint;
        DARTIndex dart_index;
        bool empty() pure const nothrow {
            return (index is Index.init) && (fingerprint is null);
        }

        mixin HiBONRecord!(q{
            this(const Index index, const(Fingerprint) fingerprint, const(DARTIndex) dart_index) {
                this.index = index;
                this.fingerprint = cast(Buffer)fingerprint;
                this.dart_index = dart_index;

            }
        });
    }

    /**
 * Data struct which contains the branches in sub-tree
 */
    @recordType("$@B") struct Branches {
        import std.stdio;
        import tagion.hibon.HiBONJSON;

        @exclude protected Fingerprint merkleroot; /// The sparsed Merkle root hash of the branches
        @label("$prints") @optional @(record_filter.Initialized) protected Fingerprint[] _fingerprints; /// Array of all the Leaves hashes
        @label("$darts") @(record_filter.Initialized) protected DARTIndex[] _dart_indices; /// Array of all the Leaves hashes
        @label("$idx") @optional @(record_filter.Initialized) protected Index[] _indices; /// Array of index pointer to BlockFile
        @exclude private bool done;
        enum fingerprintsName = GetLabel!(_fingerprints).name;
        enum dart_indicesName = GetLabel!(_dart_indices).name;
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
                _fingerprints = new Fingerprint[KEY_SPAN];
                foreach (e; doc[fingerprintsName].get!Document) {
                    _fingerprints[e.index] = e.get!(Buffer).idup;
                }
            }
            if (doc.hasMember(dart_indicesName)) {
                _dart_indices = new DARTIndex[KEY_SPAN];
                foreach (e; doc[dart_indicesName].get!Document) {
                    _dart_indices[e.index] = e.get!(Buffer).idup;
                }
            }
        }

        auto keys() {
            return _fingerprints.enumerate
                .filter!(f => !f.value.empty)
                .map!(f => f.index);
        }

        protected DARTIndex get_dart_index(const size_t key) pure nothrow {
            if (_dart_indices) {
                return _dart_indices[key];
            }
            return DARTIndex.init;
        }

        auto opSlice() {
            return keys.map!(key => Leave(indices[key], fingerprints[key], get_dart_index(key)));
        }

        DARTIndexRange dart_indices() const pure nothrow @nogc {
            return DARTIndexRange(this);
        }

        struct DARTIndexRange {
            const(Branches) owner;
            private size_t _key;
            pure nothrow @nogc {
                this(const(Branches) owner) {
                    this.owner = owner;
                }

                DARTIndex opIndex(const size_t key) const {
                    return owner.dart_index(key);
                }

                bool empty() const {
                    return _key >= owner._dart_indices.length;
                }

                DARTIndex front() const {
                    return owner.dart_index(_key);
                }

                void popFront() {
                    while (_key < owner._dart_indices.length) {
                        _key++;
                        if (!owner._dart_indices.isinit) {
                            break;
                        }

                    }
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
        Fingerprint fingerprint(const size_t key) pure const nothrow @nogc
        in {
            assert(key < KEY_SPAN);
        }
        do {
            if (_fingerprints) {
                return _fingerprints[key];
            }
            return Fingerprint.init;
        }

        DARTIndex dart_index(const size_t key) pure const nothrow @nogc {
            if (!_dart_indices.empty && !_dart_indices[key].isinit) {
                return _dart_indices[key];
            }
            return DARTIndex(cast(Buffer) fingerprint(key));
        }
        /**
         * Returns:
         *     All the fingerprints to the sub branches and archives
         */
        @property
        const(Fingerprint[]) fingerprints() pure const nothrow {
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
            assert(merkleroot.isinit, "Fingerprint must be calcuted before toHiBON is called");
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

                        

                        .check(!_fingerprints[key].isinit,
                        format("Fingerprint key=%02X at index=%d is not defined", key, index));
                        indices_set = true;
                    }
                }
                if (indices_set) {
                    hibon[indicesName] = hibon_indices;
                }
            }
            foreach (key, print; _fingerprints) {
                if (!print.isinit) {
                    hibon_fingerprints[key] = print;
                }
            }
            if (_dart_indices) {
                auto hibon_dart_indices = new HiBON;
                foreach (key, dart_index; _dart_indices) {
                    if (!dart_index.isinit && fingerprints[key] != dart_index) {

                        hibon_dart_indices[key] = dart_index;
                    }

                }
                if (hibon_dart_indices.length) {
                    hibon[dart_indicesName] = hibon_dart_indices;
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
            if (_fingerprints.isinit) {
                _fingerprints = new Fingerprint[KEY_SPAN];
            }
            if (!leave.dart_index.isinit) {
                if (_dart_indices.isinit) {
                    _dart_indices = new DARTIndex[KEY_SPAN];

                }
                _dart_indices[key] = leave.dart_index.mut;

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
                return Leave.init;
            }
            return Leave(_indices[key], _fingerprints[key], get_dart_index(key));
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
        private Fingerprint fingerprint(
                DARTFile dartfile) {
            if (merkleroot.isinit) {
                merkleroot = Fingerprint(sparsed_merkletree(dartfile.manufactor.net, _fingerprints, dartfile.flat));
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
                    writefln("branches[%02X]=%(%02x%)", key, _fingerprints[key]);
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
                .filter!(f => !f.isinit)
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
            Range dart_indices,
            Archive.Type type = Archive.Type.REMOVE) if (isInputRange!Range && is(ElementType!Range : const(DARTIndex))) {

        import std.algorithm.comparison : min;

        auto result = recorder;
        void traverse_dart(
                const Index branch_index,
                DARTIndex[] ordered_dart_indices,
                immutable uint rim = 0) @safe {
            if ((ordered_dart_indices) && (branch_index !is Index.init)) {
                immutable data = blockfile.load(branch_index);
                const doc = Document(data);
                if (Branches.isRecord(doc)) {
                    const branches = Branches(doc);
                    auto selected_dart_indices = ordered_dart_indices;
                    foreach (rim_key, index; branches._indices) {
                        uint pos;
                        while ((pos < selected_dart_indices.length) &&
                                (rim_key is selected_dart_indices[pos].rim_key(rim))) {
                            pos++;
                        }
                        if (pos > 0) {
                            traverse_dart(index, selected_dart_indices[0 .. pos], rim + 1);
                            selected_dart_indices = selected_dart_indices[pos .. $];
                        }
                    }
                }
                else {
                    // Loads the Archives into the archives

                    auto archive = new Archive(manufactor.net, doc, type);
                    if (ordered_dart_indices[0] == archive.dart_index) {
                        result.insert(archive);
                    }

                }
            }
        }

        auto sorted_dart_indices = dart_indices
            .filter!(a => a.length !is 0)
            .map!(a => DARTIndex(cast(Buffer) a))
            .array
            .dup;
        sorted_dart_indices.sort;
        traverse_dart(blockfile.masterBlock.root_index, sorted_dart_indices);
        return result;
    }

    DARTIndex[] checkload(Range)(Range dart_indices) if (isInputRange!Range && isBufferType!(ElementType!Range)) {
        import std.algorithm : canFind;

        auto result = loads(dart_indices)[]
            .map!(a => a.dart_index);

        auto not_found = dart_indices
            .filter!(f => !canFind(result, f))
            .map!(f => cast(DARTIndex) f)
            .array;

        return not_found;
    }

    enum RIMS_IN_SECTOR = 2;

    /// Wrapper function for the modify function.
    Fingerprint modify(const(RecordFactory.Recorder) modifyrecords, const Flag!"undo" undo = No.undo) {
        if (undo) {
            return modify!(Yes.undo)(modifyrecords);
        }
        else {
            return modify!(No.undo)(modifyrecords);

        }
    }

    import core.demangle;
    import std.traits;

    pragma(msg, "modify ", mangle!(FunctionTypeOf!(DARTFile.modify!(No.undo)))("modify"));
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
    Fingerprint modify(Flag!"undo" undo)(const(RecordFactory.Recorder) modifyrecords)
    in (blockfile.cache_empty, format("IN: THE CACHE MUST BE EMPTY WHEN PERFORMING NEW MODIFY len=%s", blockfile
            .cache_len))
    do {
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
            .check(!blockfile.read_only, format("Can not call a %s on a read-only DART", __FUNCTION__));
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
                    immutable rim_key = sub_range.front.dart_index.rim_key(sub_range.rim);
                    branches[rim_key] = traverse_dart(sub_range, branches.index(rim_key));
                }
                erase_block_index = Index(branch_index);

                if (branches.empty) {
                    return Leave.init;
                }

                return Leave(blockfile.save(branches).index,
                        branches.fingerprint(this), DARTIndex.init);

            }
            // Section for going through branches that are not in the sectors.
            else {
                if (branch_index !is Index.init) {
                    const doc = blockfile.cacheLoad(branch_index);
                    if (Branches.isRecord(doc)) {
                        branches = Branches(doc);
                        while (!range.empty) {
                            auto sub_range = range.nextRim;
                            immutable rim_key = sub_range.front.dart_index.rim_key(sub_range.rim);
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
                        return Leave(blockfile.save(branches).index, branches.fingerprint(this), DARTIndex.init);
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
                        auto sub_range = range.save.filter!(a => a.dart_index == current_archive.dart_index);

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
                        return Leave(
                                blockfile.save(range.front.store).index,
                                range.front.fingerprint, range.front.dart_index);
                    }
                    return Leave.init;
                }
                /// More than one archive is present. Meaning we have to traverse
                /// Deeper into the tree.
                while (!range.empty) {
                    const rim_key = range.front.dart_index.rim_key(range.rim + 1);

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
                return Leave(
                        blockfile.save(branches).index,
                        branches.fingerprint(this), DARTIndex.init);
            }

        }

        /// If our records is empty we return the previous fingerprint
        if (modifyrecords.empty) {
            return _fingerprint;
        }

        // This check ensures us that we never have multiple add and deletes on the
        // same archive in the same recorder.
        .check(modifyrecords.length <= 1 ||
                    !modifyrecords[]
                        .slide(2)
                        .map!(a => a.front.dart_index == a.dropOne.front.dart_index)
                        .any,
                        "cannot have multiple operations on same dart-index in one modify");

        auto range = rimKeyRange!undo(modifyrecords);
        auto new_root = traverse_dart(range, blockfile.masterBlock.root_index);

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
                // blockfile.block_chains.clear;
            }
        }
        scope (failure) {
            // On failure drop the BlockFile and reopen it
            blockfile.close;
            blockfile = BlockFile(filename);
        }
        return Fingerprint(new_root.fingerprint);
    }

    /** 
     * Loads the branches from the DART at rim_path
     * Params:
     *   rim_path = rim path select the branches
     * Returns:
     *   the branches a the rim_path
     */
    Branches branches(const(ubyte[]) rim_path, scope Index* branch_index = null) {
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
                    if (branch_index !is null) {
                        *branch_index = Index(index);

                    }
                    return branches;
                }
            }
            return Branches.init;
        }

        if (blockfile.masterBlock.root_index is Index.init) {
            return Branches.init;
        }
        return search(rim_path, blockfile.masterBlock.root_index);
    }

    enum indent_tab = "| .. ";
    /** 
     * Dumps the dart as rim-path
     * Params:
     *   full = true for full DART
     */
    void dump(
            const SectorRange sectors = SectorRange.init,
            const Flag!"full" full = No.full,
            const uint depth = 0
    ) {
        import std.stdio;

        writefln("EYE: %(%02X%)", _fingerprint);
        const from_rim = sectors.from_sector.nativeToBigEndian;
        const to_rim = sectors.to_sector.nativeToBigEndian;

        void local_dump(const Index branch_index,
                const ubyte rim_key = 0,
                const uint rim = 0,
                Buffer rim_path = null,
                string indent = null) @safe {
            if (!branch_index.isinit &&
                    ((depth == 0) || (rim <= depth))) {
                immutable data = blockfile.load(branch_index);
                const doc = Document(data);
                if (Branches.isRecord(doc)) {
                    auto branches = Branches(doc);
                    string _indent;
                    if (rim > 0) {
                        rim_path ~= rim_key;
                        if (!sectors.inRange(Rims(rim_path))) {
                            return;
                        }
                        writefln("%s| %02X [%d]", indent, rim_key, branch_index);
                        _indent = indent ~ indent_tab;
                    }
                    foreach (key, index; branches._indices) {
                        local_dump(index, cast(ubyte) key, rim + 1, rim_path, _indent);
                    }
                }
                else {
                    immutable dart_index = manufactor.net.dartIndex(doc);
                    auto lastRing = full ? dart_index.length : rim + 1;
                    const hash_marker = doc.hasHashKey ? " #" : "";
                    writefln("%s%(%02x%) [%d]%s",
                            indent, dart_index[0 .. lastRing], branch_index, hash_marker);
                }
            }
        }

        Index index = blockfile.masterBlock.root_index;
        if (!sectors.isinit) {
            Buffer start_path = Rims(sectors.from_sector).path;
            local_dump(index, start_path[0], 0, null);
            return;
        }

        local_dump(index);
    }

    alias TraverseCallback = bool delegate(
            const(Document) doc,
            const Index branch_index,
            const uint rim,
            Buffer rim_path);

    void traverse(
            const TraverseCallback dg,
            const SectorRange sectors = SectorRange.init,
            const uint depth = 0,
            const bool branches = true) {
        void local_traverse(
                const Index branch_index,
                const ubyte rim_key = 0,
                const uint rim = 0,
                Buffer rim_path = null) @safe {
            if (!branch_index.isinit &&
                    ((depth == 0) || (rim <= depth))) {
                immutable data = blockfile.load(branch_index);
                const doc = Document(data);
                if (dg(doc, branch_index, rim, rim_path)) {
                    return;
                }
                if (Branches.isRecord(doc)) {
                    auto branches = Branches(doc);
                    if (rim > 0) {
                        rim_path ~= rim_key;
                        if (!sectors.inRange(Rims(rim_path))) {
                            return;
                        }
                    }
                    foreach (key, index; branches._indices) {
                        local_traverse(index, cast(ubyte) key, rim + 1, rim_path);
                    }
                }
            }
        }

        Index index = blockfile.masterBlock.root_index;
        if (!sectors.isinit) {
            Buffer start_path = Rims(sectors.from_sector).path;
            local_traverse(index, start_path[0], 0, null);
            return;
        }

        local_traverse(index);
    }

    package Document cacheLoad(const Index index) {
        return Document(blockfile.cacheLoad(index));
    }

    HiBON search(Buffer[] owners, const(SecureNet) net) {
        import std.algorithm : canFind;
        import tagion.script.common;

        TagionBill[] bills;

        void local_load(
                const Index branch_index,
                const ubyte rim_key = 0,
                const uint rim = 0) @safe {
            if (branch_index !is Index.init) {
                const doc = blockfile.load(branch_index);
                if (Branches.isRecord(doc)) {
                    const branches = Branches(doc);
                    if (branches.indices.length) {
                        foreach (key, index; branches._indices) {
                            local_load(index, cast(ubyte) key, rim + 1);
                        }
                    }
                }
                if (TagionBill.isRecord(doc)) {
                    auto bill = TagionBill(doc);
                    if (owners.canFind(bill.owner)) {
                        bills ~= bill;
                    }
                }
            }
        }

        local_load(blockfile.masterBlock.root_index);
        HiBON params = new HiBON;
        foreach (i, bill; bills) {
            params[i] = bill.toHiBON;
        }
        return params;

    }

    version (unittest) {

        static {
            bool check(const(RecordFactory.Recorder) A, const(RecordFactory.Recorder) B) {
                return equal!(q{a.dart_index == b.dart_index})(A.archives[], B.archives[]);
            }

            Fingerprint write(DARTFile dart, const(ulong[]) table, out RecordFactory.Recorder rec) {
                rec = records(dart.manufactor, table);
                return dart.modify(rec);
            }

            DARTIndex[] dart_indices(RecordFactory.Recorder recorder) {
                DARTIndex[] results;
                foreach (a; recorder.archives) {
                    results ~= a.dart_index;
                }
                return results;

            }

            bool validate(DARTFile dart, const(ulong[]) table, out RecordFactory
                .Recorder recorder) {
                write(dart, table, recorder);
                auto _dart_indices = dart_indices(recorder);
                auto find_recorder = dart.loads(_dart_indices);
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
unittest {
    import std.algorithm.sorting : sort;

    import std.stdio : writefln; //    import tagion.basic.basic;
    import std.bitmanip : BitArray;
    import std.typecons;
    import tagion.basic.basic : forceRemove;
    import tagion.hibon.HiBONJSON : toPretty;
    import tagion.utils.Miscellaneous : cutHex;
    import tagion.utils.Random;

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
        assert(recorder_archive.dart_index == a_in.dart_index);

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
            immutable key = rim_range.front.dart_index.rim_key(rim);
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
        recorder.remove(archive_1.dart_index);
        const archive_2 = new Archive(net, net.fake_doc(0xABB7_1112_1111_0000UL), Archive
                .Type.NONE);
        recorder.remove(archive_2.dart_index);
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
        import std.format;
        import std.range : empty;

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
            auto remove_dart_index = DARTIndex(recorder[].front.dart_index);
            // writefln("%s", remove_dart_index);

            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(remove_dart_index);
            dart_A.modify(remove_recorder);
            // dart_A.dump();

            auto branches = dart_A.branches([0xAB, 0xB9]);

            assert(numberOfArchives(branches, dart_A) == 1, "Branch not snapped back to rim 2");

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
            dart_A.modify(recorder);
            // dart_A.dump();
            auto dart_indices = recorder[].map!(a => cast(immutable) DARTIndex(a.dart_index)).array;

            auto empty_load = dart_A.checkload(dart_indices);
            assert(empty_load.length == 0);
            // test.map!(f => f.toPretty).writeln;
            const ulong[] not_in_dart = [
                0xABB9_13ab_11ef_0929,
                0xABB9_13ab_11ef_1239,

            ];
            auto not_in_dart_fingerprints = not_in_dart
                .map!(a => DARTFakeNet.fake_doc(a))
                .map!(a => net.dartIndex(a));

            auto full_load = dart_A.checkload(not_in_dart_fingerprints);
            assert(not_in_dart_fingerprints.length == full_load.length);

            const ulong[] half_in_dart = [
                0xABB9_13ab_11ef_0923,
                0xABB9_13ab_11ef_1239,
            ];
            auto half_in_dart_fingerprints = half_in_dart
                .map!(a => DARTFakeNet.fake_doc(a))
                .map!(a => net.dartIndex(a))
                .array;

            auto half_load = dart_A.checkload(half_in_dart_fingerprints);
            assert(half_load.length == 1);

            assert(half_load[0] == half_in_dart_fingerprints[1]);

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
            auto fingerprint = recorder[].front.fingerprint;
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
            auto remove_dart_index = recorder[].front.dart_index;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(remove_dart_index);
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
            auto remove_dart_index = recorder[].front.dart_index;

            dart_A.modify(recorder);
            // dart_A.dump();

            auto next_recorder = dart_A.recorder();
            next_recorder.remove(remove_dart_index);
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

            auto dart_indices = recorder[].map!(r => r.dart_index).array;
            assert(dart_indices.length == 4);
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(dart_indices[0]);
            remove_recorder.remove(dart_indices[2]);
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
            auto dart_indices = recorder[].map!(r => r.dart_index).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(dart_indices[$ - 1]);

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
            auto dart_indices = recorder[].map!(r => r.dart_index).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(dart_indices[4]);

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
            auto dart_indices = recorder[].map!(r => r.dart_index).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(dart_indices[4]);
            remove_recorder.remove(dart_indices[3]);

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
            auto dart_indices = recorder[].map!(r => r.dart_index).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(dart_indices[1]);
            remove_recorder.remove(dart_indices[2]);

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
            auto dart_indices = recorder[].map!(r => r.dart_index).array;
            dart_A.modify(recorder);
            // dart_A.dump();

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(dart_indices[0]);
            remove_recorder.remove(dart_indices[1]);

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
            auto remove_dart_index = DARTIndex(recorder[].front.dart_index);
            // writefln("%s", remove_dart_index);

            dart_A.modify(recorder);
            // dart_A.dump();

            auto dart_blockfile = BlockFile(filename_A);
            // dart_blockfile.dump;
            dart_blockfile.close;

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(remove_dart_index);
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
            auto remove_dart_index = DARTIndex(recorder[].front.dart_index);

            dart_A.modify(recorder);
            // dart_A.dump();

            auto dart_blockfile = BlockFile(filename_A);
            // dart_blockfile.dump;
            dart_blockfile.close;

            auto remove_recorder = dart_A.recorder();
            remove_recorder.remove(remove_dart_index);
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

                auto dart_index = recorder[].front.dart_index;

                auto read_recorder = dart_A.loads([dart_index]);

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
                auto new_dart_index = new_recorder[].front.dart_index;

                auto new_read_recorder = dart_A.loads([new_dart_index]);
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
                auto dart_index = recorder[].front.dart_index;
                auto read_recorder = dart_A.loads([dart_index]);
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
        const dart_indices = recorder[].map!(a => a.dart_index).array;

        auto new_doc = DARTFakeNet.fake_doc(0x2345_130b_1234_1234);
        recorder = dart_A.recorder();
        recorder.add(new_doc);
        foreach (dart_index; dart_indices) {
            recorder.remove(dart_index);
        }
        dart_A.modify(recorder);
        const new_bullseye = dart_A.bullseye;
        dart_A.modify(recorder, Yes.undo);
        assert(dart_A.bullseye != new_bullseye, "Should not be the same as the new bullseye after undo");
        assert(dart_A.bullseye == bullseye, "should have been reverted to previoius bullseye");

    }

    {
        pragma(msg, "fixme(cbr): This unittest does not see to be relavant to DARTFile maybe this should be moved");
        // At least it should not be dependent on tagion.script
        // Just make a d Document with $Y owner key
        filename_A.forceRemove;
        DARTFile.create(filename_A, net);
        auto dart_A = new DARTFile(net, filename_A);
        import tagion.crypto.Types;
        import tagion.script.TagionCurrency;
        import tagion.script.common;
        import tagion.utils.StdTime;

        RecordFactory.Recorder recorder_A;

        TagionBill[] bills;

        Pubkey pkey1 = Pubkey([1, 2, 3, 4]);
        Pubkey pkey2 = Pubkey([2, 3, 4, 5]);

        bills ~= TagionBill(100.TGN, currentTime, pkey1, Buffer.init);
        bills ~= TagionBill(100.TGN, currentTime, pkey2, Buffer.init);

        recorder_A = dart_A.recorder;

        recorder_A.insert(bills, Archive.Type.ADD);
        dart_A.modify(recorder_A);

        // dart_A.dump;
        import tagion.crypto.SecureInterfaceNet;
        import tagion.crypto.SecureNet;

        SecureNet _net = new StdSecureNet();
        import tagion.crypto.SecureNet : StdSecureNet;

        _net.generateKeyPair("wowo");
        auto h = dart_A.search([pkey1, pkey2].map!(b => cast(Buffer) b).array, (() @trusted => cast(immutable) _net)());
    }

    { // Check the #name archives 
        filename_A.forceRemove;
        DARTFile.create(filename_A, net);
        auto dart_A = new DARTFile(net, filename_A);
        static struct HashDoc {
            @label("#name") string name;
            int number;
            mixin HiBONRecord!(q{
                this(string name, int n) {
                    this.name=name;
                    number=n;
                }
        });
        }

        auto recorder_add = dart_A.recorder;
        const hashdoc = HashDoc("hugo", 42);
        recorder_add.add(hashdoc);
        assert(recorder_add[].front.dart_index != recorder_add[].front.fingerprint,
        "The dart_index and the fingerprint of a archive should not be the same for a # archive");
        auto bullseye = dart_A.modify(recorder_add);
        // dart_A.dump;
        // writefln("bullseye   =%(%02x%)", bullseye);
        // writefln("fingerprint=%(%02x%)", recorder_add[].front.fingerprint);
        assert(bullseye == recorder_add[].front.fingerprint,
        "The bullseye for a DART with a single #key archive should be the same as the fingerprint of the archive");
        const hashdoc_change = HashDoc("hugo", 17);
        auto recorder_B = dart_A.recorder;
        recorder_B.remove(hashdoc_change);
        // dart_A.dump;
        bullseye = dart_A.modify(recorder_B);
        auto recorder_change = dart_A.recorder;
        recorder_change.add(hashdoc_change);
        bullseye = dart_A.modify(recorder_change);
        // dart_A.dump;
        // writefln("bullseye   =%(%02x%)", bullseye);
        // writefln("dart_index =%(%02x%)", recorder_change[].front.dart_index);
        // writefln("fingerprint=%(%02x%)", recorder_change[].front.fingerprint);
        assert(recorder_add[].front.dart_index == recorder_change[].front.dart_index);
        assert(bullseye == recorder_change[].front.fingerprint,
        "The bullseye for a DART with a single #key archive should be the same as the fingerprint of the archive");
        { // read the dart_index from the dart and check the dart_index 
            auto load_recorder = dart_A.loads(recorder_change[].map!(a => a.dart_index));
            //writefln("load_recorder=%(%02x%)", load_recorder[].front.dart_index);
            assert(equal(
                    load_recorder[].map!(a => a.dart_index),
                    recorder_change[].map!(a => a.dart_index)));
        }
        // writefln("filename_A %s", filename_A);
        const hashdoc_extra = HashDoc("boerge", 42);
        auto recorder_C = dart_A.recorder;
        recorder_C.add(hashdoc_extra);
        bullseye = dart_A.modify(recorder_C);
        dart_A.close;
        {
            auto dart_reload = new DARTFile(net, filename_A);
            auto reload_recorder = dart_reload.loads(recorder_change[].map!(a => a.dart_index));
            //writefln("reload_recorder=%(%02x%)", reload_recorder[].front.dart_index);
            // dart_reload.dump;
            assert(equal(recorder_change[].map!(a => a.filed), reload_recorder[].map!(a => a.filed)));
        }

    }

}
