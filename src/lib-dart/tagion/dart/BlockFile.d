/// Block files system (file system support for DART)
module tagion.dart.BlockFile;

import console = std.stdio;

import std.path : setExtension;
import std.bitmanip : binwrite = write, binread = read;
import std.stdio;
import std.file : remove, rename;
import std.typecons;
import std.algorithm.sorting : sort;
import std.algorithm.searching : until;
import std.algorithm.mutation : SwapStrategy;
import std.algorithm.iteration : filter, each, map;

import std.range : isForwardRange, isInputRange;
import std.array : array, join;
import std.datetime;
import std.format;
import std.conv : to;
import std.traits;
import std.exception : assumeUnique, assumeWontThrow;
import std.container.rbtree : RedBlackTree, redBlackTree;

import tagion.basic.Types : Buffer, FileExtension;
import tagion.basic.basic : basename, log2, assumeTrusted;
import tagion.basic.tagionexceptions : Check;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.logger.Statistic;
import tagion.dart.DARTException : BlockFileException;
import tagion.dart.Recycler : Recycler;
import tagion.dart.BlockSegment;

import tagion.basic.Debug : __write;
import tagion.hibon.HiBONJSON : toPretty;

//import tagion.dart.BlockSegmentAllocator;

alias Index = Typedef!(ulong, ulong.init, "BlockIndex");
enum INDEX_NULL = Index.init;
enum BLOCK_SIZE = 0x80;

version (unittest) {
    import basic = tagion.basic.basic;

    const(basic.FileNames) fileId(T = BlockFile)(string prefix = null) @safe {
        return basic.fileId!T(FileExtension.dart, prefix);
    }
}

extern (C) {
    int ftruncate(int fd, long length);
}

// File object does not support yet truncate so the generic C function is used
@trusted
void truncate(ref File file, long length) {
    ftruncate(file.fileno, length);
}

alias check = Check!BlockFileException;

/// Block file operation
@safe
class BlockFile {
    enum FILE_LABEL = "DART:0.0";
    enum DEFAULT_BLOCK_SIZE = 0x40;
    immutable uint BLOCK_SIZE;
    //immutable uint DATA_SIZE;
    alias BlockFileStatistic = Statistic!(uint, Yes.histogram);
    static bool do_not_write;
    package {
        File file;
        Index _last_block_index;
        Recycler recycler;
    }

    protected {
        MasterBlock masterblock;
        HeaderBlock headerblock;
        bool hasheader;
        BlockFileStatistic _statistic;
    }

    Index last_block_index() const pure nothrow @nogc {
        return _last_block_index;
    }

    const(BlockFileStatistic) statistic() const pure nothrow @nogc {
        return _statistic;
    }

    // bool isRecyclable(const Index index) const pure nothrow {
    //     return recycler.isRecyclable(index);
    // }

    void recycleDump() {
        import tagion.dart.Recycler : Segment;

        // writefln("recycle dump from blockfile");

        Index index = masterblock.recycle_header_index;

        if (index == Index(0)) {
            return;
        }
        while (index != Index.init) {
            auto add_segment = Segment(this, index);
            writefln("Index(%s), size(%s), next(%s)", add_segment.index, add_segment
                    .size, add_segment.next);
            index = add_segment.next;
        }
    }

    protected this() {
        BLOCK_SIZE = DEFAULT_BLOCK_SIZE;
        recycler = Recycler(this);
        //empty
    }

    protected this(
        string filename,
        immutable uint SIZE,
        const bool read_only = false) {
        File _file;

        if (read_only) {
            _file.open(filename, "r");
        }
        else {
            _file.open(filename, "r+");
        }
        this(_file, SIZE);
    }

    protected this(File file, immutable uint SIZE) {
        this.BLOCK_SIZE = SIZE;
        //   DATA_SIZE = BLOCK_SIZE - Block.HEADER_SIZE;
        this.file = file;
        recycler = Recycler(this);
        readInitial;
    }

    /**
       Used by the Inspect
    */
    protected this(immutable uint SIZE) pure nothrow {
        this.BLOCK_SIZE = SIZE;
        //  DATA_SIZE = BLOCK_SIZE - Block.HEADER_SIZE;
        recycler = Recycler(this);
    }

    static BlockFile Inspect(
        string filename,
        void delegate(string msg) @safe report,
        const uint max_iteration = uint.max) {
        BlockFile result;
        void try_it(void delegate() @safe dg) {
            try {
                dg();
            }
            catch (BlockFileException e) {
                report(e.msg);
            }
        }

        try_it({
            File _file;
            _file.open(filename, "r");
            BlockFile.HeaderBlock _headerblock;
            _file.seek(0);
            _headerblock.read(_file, DEFAULT_BLOCK_SIZE);
            result = new BlockFile(_headerblock.block_size);
            result.file = _file;
        });
        if (result.file.size == 0) {
            report(format("BlockFile %s size is 0", filename));
        }
        if (result) {
            try_it(&result.readHeaderBlock);
            result._last_block_index--;
            try_it(&result.readMasterBlock);
            try_it(&result.readStatistic);
            result.recycler = Recycler(result);
            //result.recycle_indices.max_iteration = max_iteration;
            //try_it(&result.recycle_indices.read);
        }
        return result;
    }
    /++
     Creates and empty BlockFile

     Params:
     $(LREF finename)    = File name of the BlockFile.
     If file exists with the same name this file will be overwritten
     $(LREF description) = This text will be written into the header
     $(LREF BLOCK_SIZE)  = Set the block size of the underlining BlockFile

     +/
    static void create(string filename, string description, immutable uint BLOCK_SIZE) {
        auto _file = File(filename, "w+");
        auto blockfile = new BlockFile(_file, BLOCK_SIZE);
        scope (exit) {
            blockfile.close;
        }
        blockfile.createHeader(description);
        blockfile.writeMasterBlock;
    }

    static BlockFile reset(string filename) {
        immutable old_filename = filename.setExtension("old");
        filename.rename(old_filename);
        auto old_blockfile = BlockFile(old_filename);
        old_blockfile.readStatistic;

        auto _file = File(filename, "w+");
        auto blockfile = new BlockFile(_file, old_blockfile.headerblock.block_size);
        blockfile.headerblock = old_blockfile.headerblock;
        blockfile._statistic = old_blockfile._statistic;
        blockfile.headerblock.write(_file);
        blockfile._last_block_index = 1;
        blockfile.masterblock.write(_file, blockfile.BLOCK_SIZE);
        blockfile.hasheader = true;
        blockfile.store;
        return blockfile;
    }
    /++
     + Opens an existing file which previously was created by BlockFile.create
     +
     + Params:
     +     filename  = Name of the blockfile
     +     read_only = If `true` the file is opened as read-only
     +/
    static BlockFile opCall(string filename, const bool read_only = false) {
        auto temp_file = new BlockFile();
        temp_file.file = File(filename, "r");
        temp_file.readHeaderBlock;
        temp_file.file.close;

        immutable SIZE = temp_file.headerblock.block_size;
        return new BlockFile(filename, SIZE, read_only);
    }

    /++
     +/
    void close() {
        file.close;
    }

    ~this() {
        file.close;
    }

    protected void createHeader(string name) {
        check(!hasheader, "Header is already created");
        check(file.size == 0, "Header can not be created the file is not empty");
        check(name.length < headerblock.id.length, format("Id is limited to a length of %d but is %d", headerblock
                .id.length, name.length));
        headerblock.label[0 .. FILE_LABEL.length] = FILE_LABEL;
        headerblock.block_size = BLOCK_SIZE;
        headerblock.id[0 .. name.length] = name;
        headerblock.create_time = Clock.currTime.toUnixTime!long;
        headerblock.write(file);
        _last_block_index = 1;
        masterblock.write(file, BLOCK_SIZE);
        hasheader = true;
    }

    /++
     + Returns:
     +     `true` of the file blockfile has a header
     +/
    bool hasHeader() const pure nothrow {
        return hasheader;
    }

    protected void readInitial() {
        if (file.size > 0) {
            readHeaderBlock;
            _last_block_index--;
            readMasterBlock;
            readStatistic;
            recycler.read(masterblock.recycle_header_index);
        }
    }

    pragma(msg, "fixme(cbr): The Statistic here should use tagion.utils.Statistic");
    enum Limits : double {
        MEAN = 10,
        SUM = 100
    }

    protected bool check_statistic(const uint total_blocks, const uint blocks) pure const {
        if (blocks > total_blocks) {
            return false;
        }
        else if (_statistic.contains(blocks) || (total_blocks >= 2 * blocks)) {
            return true;
        }
        else {
            auto r = _statistic.result;
            if (r.mean > Limits.MEAN) {
                immutable limit = (r.mean - r.sigma);
                if (blocks > limit) {
                    immutable remain_blocks = total_blocks - blocks;
                    if (_statistic.contains(remain_blocks) || (remain_blocks > r.mean)) {
                        return true;
                    }
                }
            }
        }
        return false;
    }

    /++
     + The HeaderBlock is the first block in the BlockFile
     +/
    @safe
    struct HeaderBlock {
        enum ID_SIZE = 32;
        enum LABEL_SIZE = 16;
        char[LABEL_SIZE] label; /// Label to set the BlockFile type
        uint block_size; /// Size of the block's
        long create_time; /// Time of creation
        char[ID_SIZE] id; /// Short description string

        void write(ref File file) const @trusted
        in {
            assert(block_size >= HeaderBlock.sizeof);
        }
        do {
            auto buffer = new ubyte[block_size];
            size_t pos;
            foreach (i, m; this.tupleof) {
                alias type = typeof(m);
                static if (isStaticArray!type) {
                    buffer[pos .. pos + type.sizeof] = (cast(ubyte*) id.ptr)[0 .. type.sizeof];
                    pos += type.sizeof;
                }
                else {
                    buffer.binwrite(m, &pos);
                }
            }
            assert(!BlockFile.do_not_write, "Should not write here");
            file.rawWrite(buffer);
        }

        void read(ref File file, immutable uint BLOCK_SIZE) @trusted
        in {
            assert(BLOCK_SIZE >= HeaderBlock.sizeof);
        }
        do {

            auto buffer = new ubyte[BLOCK_SIZE];
            auto buf = file.rawRead(buffer);
            foreach (i, ref m; this.tupleof) {
                alias type = typeof(m);
                static if (isStaticArray!type && is(type : U[], U)) {
                    m = (cast(U*) buf.ptr)[0 .. m.sizeof];
                    buf = buf[m.sizeof .. $];
                }
                else {
                    m = buf.binread!type;
                }
            }
        }

        string toString() const {
            return [
                "Header Block",
                format("Label      : %s", label[].until(char(ubyte.max))),
                format("ID         : %s", id[].until(char.max)),
                format("Block size : %d", block_size),
                format("Created    : %s", SysTime.fromUnixTime(create_time).toSimpleString),
            ].join("\n");
        }

    }

    final Index lastBlockIndex() const pure nothrow {
        return _last_block_index;
    }

    /** 
     * Sets the pointer to the index in the blockfile.
     * Params:
     *   index = in blocks to set in the blockfile
     */
    final package void seek(const Index index) {
        file.seek(index_to_seek(index));
    }

    /++
     + The MasterBlock is the last block in the BlockFile
     + This block maintains the indices to of other block
     +/

    @safe @recordType("M")
    static struct MasterBlock {
        Index recycle_header_index; /// Points to the root of recycle block list
        //Index first_index; /// Points to the first block of data
        Index root_index; /// Point the root of the database
        Index statistic_index; /// Points to the statistic data

        mixin HiBONRecord;

        void write(
            ref File file,
            immutable uint BLOCK_SIZE) const @trusted {

            auto buffer = new ubyte[BLOCK_SIZE];

            const doc = this.toDoc;
            buffer[0 .. doc.full_size] = doc.serialize;

            file.rawWrite(buffer);
            // Truncate the file after the master block
            file.truncate(file.size);
            file.sync;
        }

        void read(ref File file, immutable uint BLOCK_SIZE) {
            const doc = file.fread();
            check(MasterBlock.isRecord(doc), "not a masterblock");
            this = MasterBlock(doc);
        }

        string toString() const pure nothrow {
            return assumeWontThrow([
                "Master Block",
                format("Root       @ %d", root_index),
                //       format("First      @ %d", first_index),
                format("Recycle    @ %d", recycle_header_index),
                format("Statistic  @ %d", statistic_index),
            ].join("\n"));

        }
    }

    /++
     + Sets the database root index
     +
     + Params:
     +     index = Root of the database
     +/
    void root_index(const Index index)
    in {
        assert(index > 0 && index < _last_block_index);
    }
    do {
        masterblock.root_index = Index(index);
    }

    Index root_index() const pure nothrow {
        return masterblock.root_index;
    }

    /++
     + Params:
     +     size = size of data bytes
     +
     + Returns:
     +     The number of blocks used to allocate size bytes
     +/
    uint numberOfBlocks(const size_t size) const pure nothrow @nogc {
        return cast(uint)((size / BLOCK_SIZE) + ((size % BLOCK_SIZE == 0) ? 0 : 1));
    }

    /++
     + Params:
     +      index = Block index pointer
     +
     + Returns:
     +      the file pointer in byte counts
     +/
    ulong index_to_seek(const Index index) const pure nothrow {
        return BLOCK_SIZE * cast(ulong) index;
    }

    protected void writeStatistic() {
        immutable old_statistic_index = masterblock.statistic_index;

        if (old_statistic_index !is Index.init) {
            dispose(old_statistic_index);

        }
        auto statistical_allocate = save(_statistic.toDoc);
        masterblock.statistic_index = Index(statistical_allocate.index);

    }

    ref const(MasterBlock) masterBlock() pure const nothrow {
        return masterblock;
    }

    // Write the master block to the filesystem and truncate the file
    protected void writeMasterBlock() {
        seek(_last_block_index);
        masterblock.write(file, BLOCK_SIZE);
    }

    private void readMasterBlock() {
        // The masterblock is locate as the lastblock in the file
        seek(_last_block_index);
        masterblock.read(file, BLOCK_SIZE);
    }

    ref const(HeaderBlock) headerBlock() pure const nothrow {
        return headerblock;
    }

    private void readHeaderBlock() {
        check(file.size % BLOCK_SIZE == 0,
            format("BlockFile should be sized in equal number of blocks of the size of %d but the size is %d", BLOCK_SIZE, file
                .size));
        _last_block_index = Index(file.size / BLOCK_SIZE);
        check(_last_block_index > 1, format(
                "The BlockFile should at least have a size of two block of %d but is %d", BLOCK_SIZE, file
                .size));
        // The headerblock is locate in the start of the file
        seek(INDEX_NULL);
        headerblock.read(file, BLOCK_SIZE);
        hasheader = true;
    }

    private void readStatistic() @safe {
        if (masterblock.statistic_index !is INDEX_NULL) {
            immutable buffer = load(masterblock.statistic_index);
            _statistic = BlockFileStatistic(Document(buffer));
        }
    }

    /++
     + Loads a chain of blocks from the filesystem starting from index
     + This function will not load data in BlockSegment list
     + The allocated chain list has to be stored first
     +
     + Params:
     +     index = Points to an start block in the chain of blocks
     +
     + Returns:
     +     Buffer of all data in the chain of blocks
     +
     + Throws:
     +     BlockFileException if this not first block in a chain or
     +     some because of some other failures in the blockfile system
     +/
    const(Document) load(const Index index, const bool check_format = true) {
        return BlockSegment(this, index).doc;
    }

    T load(T)(const Index index) if (isHiBONRecord!T) {
        const doc = load(index);

        check(isRecord!T(doc), format("The loaded document is not a %s record", T.stringof));
        return T(doc);
    }

    /**
     * Works the same as load except that it also reads data from cache which hasn't been stored yet
     * Params:
     *   index = Block index 
     * Returns: 
     *   Document load at index
     */
    Document cacheLoad(const Index index) nothrow {
        if (index == 0) {
            return Document.init;
        }
        auto allocated_range = allocated_chains.filter!(a => a.index == index);
        if (!allocated_range.empty) {
            return allocated_range.front.doc;
        }

        return assumeWontThrow(load(index));
    }

    /**
     * Ditto
     * Params:
     *   T = HiBON record type
     *   index = block index
     * Returns: 
     *   T load at index
     */
    T cacheLoad(T)(const Index index) if (isHiBONRecord!T) {
        const doc = cacheLoad(index);
        check(isRecord!T(doc), format("The loaded document is not a %s record", T.stringof));
        return T(doc);
    }

    /++
     + Marks a chain for blocks as erased
     + This function does actually erease the block before the store method is called
     + The list of recyclable block also be update after the store method has been called
     +
     + This prevents it from danaging the BlockFile until a sequency of operations has been performed
     +
     + Params:
     +     index = Points to an start block in the chain of blocks
     +
     + Returns:
     +     Begin to the next block sequency in the
     + Throws:
     +     BlockFileException
     +
     +/
    void dispose(const Index index) {
        import LEB128 = tagion.utils.LEB128;

        auto allocated_range = allocated_chains.filter!(a => a.index == index);
        assert(allocated_range.empty, "We should dispose cached blocks");
        seek(index);
        ubyte[LEB128.DataSize!ulong] _buf;
        ubyte[] buf = _buf;
        file.rawRead(buf);
        const doc_size = LEB128.read!ulong(buf);

        recycler.dispose(index, numberOfBlocks(doc_size.size + doc_size.value));
    }

    /**
     * Internal function used to reserve a size bytes in the blockfile
     * Params:
     *   size = size in bytes
     * Returns: 
     *   block index position of the reserved bytes
     */
    protected Index claim(const size_t size) nothrow {
        const nblocks = numberOfBlocks(size);
        _statistic(nblocks);
        return Index(recycler.claim(nblocks));
    }

    /// Cache to be stored
    protected const(BlockSegment)*[] allocated_chains;

    /++
     + Allocates new document
     + Does not acctually update the BlockFile just reserves new block's
     +
     + Params:
     +     doc = Document to be reserved and allocated
     +/
    const(BlockSegment*) save(const(Document) doc) {
        auto result = new const(BlockSegment)(doc, claim(doc.full_size));

        allocated_chains ~= result;
        return result;

    }
    /// Ditto
    const(BlockSegment*) save(T)(const T rec) if (isHiBONRecord!T) {
        return save(rec.toDoc);
    }
    /++
     +
     + This function will erase, write, update the BlockFile and update the recyle bin
     + Stores the list of BlockSegment to the disk
     + If this function throws an Exception the Blockfile has not been updated
     +
     +/
    void store() {
        writeStatistic;

        scope (success) {
            allocated_chains = null;

            masterblock.recycle_header_index = recycler.write();
            writeMasterBlock;

        }
        foreach (block_segment; sort!(q{a.index < b.index}, SwapStrategy.unstable)(
                allocated_chains)) {
            block_segment.write(this);
        }
    }

    struct BlockSegmentRange {
        BlockFile owner;

        Index index = Index(1UL);
        BlockSegmentInfo current_segment;

        this(BlockFile owner) {
            this.owner = owner;
            initFront;
        }

        alias BlockSegmentInfo = Tuple!(Index, "index", string, "type", uint, "size", Document, "doc");

        private void initFront() @trusted {
            import std.format;
            import core.exception : ArraySliceError;
            import tagion.dart.Recycler : Segment;
            import tagion.utils.Term;

            const doc = owner.load(index);
            uint size;

            try {

                if (isRecord!Segment(doc)) {
                    const segment = Segment(doc, index);
                    size = segment.size;
                }
                else {
                    size = owner.numberOfBlocks(doc.full_size);
                }
            }
            catch (ArraySliceError e) {
                current_segment = BlockSegmentInfo(index, format("%sERROR%s", RED, RESET), 1, Document());
                return;
            }
            const type = getType(doc);

            current_segment = BlockSegmentInfo(index, type, size, doc);
        }

        BlockSegmentInfo front() const pure nothrow @nogc {
            return current_segment;
        }

        void popFront() {
            index = Index(current_segment.index + current_segment.size);
            initFront;
        }

        bool empty() {

            if (index == Index.init || current_segment == BlockSegmentInfo.init) {
                return true;
            }

            const last_index = owner.numberOfBlocks(owner.file.size);

            return Index(current_segment.index + current_segment.size) > last_index;
        }

        BlockSegmentRange save() {
            return this;
        }

    }

    static assert(isInputRange!BlockSegmentRange);
    static assert(isForwardRange!BlockSegmentRange);
    BlockSegmentRange opSlice() {
        return BlockSegmentRange(this);
    }

    /++
     + Fail type for the inspect function
     +/
    enum Fail {
        NON = 0, /// No error detected in this Block
        RECURSIVE, /// Block links is recursive
        INCREASING, /// The next pointer should be greater than the block index
        SEQUENCY, /**
                     Block size in a sequency should be decreased by Block.DATA_SIZE
                     between the current and the next block in a sequency
                  */
        LINK, /// Blocks should be double linked
        ZERO_SIZE, /// The size of Recycled block should be zero
        BAD_SIZE, /** Bad size means that a block is not allowed to have a size larger than DATA_SIZE
                       if the next block is a head block
                   */
        RECYCLE_HEADER, /// Recycle block should not contain a header mask
        RECYCLE_NON_ZERO, /// The size of an recycle block should be zero

    }

    /++
     + Check the BlockFile
     +
     + Params:
     +     fail  = is callback delegate which will be call when a Fail is detected
     +     index  = Point to the block in the BlockFile
     +     f      = is the Fail code
     +     block  = is the failed block
     +     data_flag = Set to `false` if block is a resycled block and `true` if it a data block
     +/
    bool inspect(bool delegate(
            const Index index,
            const Fail f,
            const bool recycle_chain) @safe trace) {
        scope bool[Index] visited;
        scope bool end;
        bool failed;
        version (none) @safe
        void check_data(bool check_recycle_mode)(ref BlockRange r) {
            Block previous;
            while (!r.empty && !end) {
                auto current = r.front;
                if ((r.index in visited) && (r.index !is INDEX_NULL)) {
                    failed = true;
                    end |= trace(r.index, Fail.RECURSIVE, current, check_recycle_mode);
                }
                visited[r.index] = true;
                static if (!check_recycle_mode) {
                    if (current.size == 0) {
                        failed = true;
                        end |= trace(r.index, Fail.ZERO_SIZE, current, check_recycle_mode);
                    }
                }
                if (!failed) {
                    end |= trace(r.index, Fail.NON, current, check_recycle_mode);
                }
                previous = r.front;
                r.popFront;
            }
        }

        return failed;
    }

    enum BlockSymbol {
        file_header = 'H',
        header = 'h',
        empty = '_',
        recycle = 'X',
        data = '#',
        none_existing = 'Z',

    }

    /++
     + Used for debuging only to dump the Block's
     +/
    void dump(const uint segments_per_line = 6) {

        BlockSegmentRange seg_range = opSlice();

        uint pos = 0;
        foreach (seg; seg_range) {
            if (pos == segments_per_line) {
                writef("|");
                writeln;
                pos = 0;
            }
            writef("|%s index(%s) size(%s)", seg.type, seg.index, seg.size);
            pos++;

        }
        writef("|");
        writeln;
    }

    // Block index 0 is means null
    // The first block is use as BlockFile header
    unittest {
        enum SMALL_BLOCK_SIZE = 0x40;
        import std.format;

        /// Test of BlockFile.create and BlockFile.opCall
        {
            immutable filename = fileId("create").fullpath;
            BlockFile.create(filename, "create.unittest", SMALL_BLOCK_SIZE);
            auto blockfile_load = BlockFile(filename);
            scope (exit) {
                blockfile_load.close;
            }
        }

        alias B = Tuple!(string, "label", uint, "blocks");
        version (none) Document generate_block(const BlockFile blockfile, const B b) {
            enum filler = " !---- ;-) -----! ";
            string text = b.label;
            while ((text.length / blockfile.DATA_SIZE) < b.blocks) {
                text ~= filler;
            }
            return cast(Buffer) text;
        }

        /// Create BlockFile
        {
            // Delete test blockfile
            // Create new blockfile
            File _file = File(fileId.fullpath, "w");
            auto blockfile = new BlockFile(_file, SMALL_BLOCK_SIZE);

            assert(!blockfile.hasHeader);
            blockfile.createHeader("This is a Blockfile unittest");
            assert(blockfile.hasHeader);
            _file.close;
        }

        {
            // Check the header exists
            auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);
            assert(blockfile.hasHeader);
            blockfile.close;
        }

        {
            auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);

            blockfile.dispose(blockfile.masterblock.statistic_index);

            blockfile.close;
        }

    }
}
