/// Block files system (file system support for DART)
module tagion.dart.BlockFile;

import console = std.stdio;

import std.path : setExtension;
import std.bitmanip : binwrite = write, binread = read;
import std.stdio;
import std.file : remove, rename;
import std.typecons;
import std.algorithm;

import std.range : isForwardRange, isInputRange;
import std.array : array, join;
import std.datetime;
import std.format;
import std.conv : to;
import std.traits;
import std.exception : assumeWontThrow;
import std.container.rbtree : RedBlackTree, redBlackTree;

import tagion.basic.Types : Buffer, FileExtension;
import tagion.basic.tagionexceptions : Check;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONFile;
import tagion.logger.Statistic;
import tagion.dart.DARTException : BlockFileException;
import tagion.dart.Recycler : Recycler;
import tagion.dart.BlockSegment;
import std.exception : ifThrown;
import tagion.basic.basic : isinit;

///
import tagion.logger.Logger;

alias Index = Typedef!(ulong, ulong.init, "BlockIndex");
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
alias BlockChain = RedBlackTree!(const(BlockSegment*), (a, b) => a.index < b.index);

/// Block file operation
@safe
class BlockFile {
    enum FILE_LABEL = "BLOCK:0.0";
    enum DEFAULT_BLOCK_SIZE = 0x40;
    immutable uint BLOCK_SIZE;
    //immutable uint DATA_SIZE;
    alias BlockFileStatistic = Statistic!(ulong, Yes.histogram);
    alias RecyclerFileStatistic = Statistic!(ulong, Yes.histogram);
    static bool do_not_write;
    package {
        File file;
        Index _last_block_index;
        Recycler recycler;
    }


    protected {

        BlockChain block_chains; // the cache
        MasterBlock masterblock;
        HeaderBlock headerblock;
        // /bool hasheader;
        BlockFileStatistic _statistic;
        RecyclerFileStatistic _recycler_statistic;
    }

    const(HeaderBlock) headerBlock() const pure nothrow @nogc {
        return headerblock;
    }

    const(BlockFileStatistic) statistic() const pure nothrow @nogc {
        return _statistic;
    }

    const(RecyclerFileStatistic) recyclerStatistic() const pure nothrow @nogc {
        return _recycler_statistic;
    }

    protected this() {
        BLOCK_SIZE = DEFAULT_BLOCK_SIZE;
        recycler = Recycler(this);
        block_chains = new BlockChain;
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
        this(_file, SIZE, !read_only);
    }

    protected this(File file, immutable uint SIZE, const bool set_lock = true) {
        block_chains = new BlockChain;
        scope (failure) {
            file.close;
        }
        if (set_lock) {
            const lock = (() @trusted => file.tryLock(LockType.read))();

            check(lock, "Error: BlockFile in use (LOCKED)");
        }
        this.BLOCK_SIZE = SIZE;
        this.file = file;
        recycler = Recycler(this);
        readInitial;
    }

    /** 
     * Creates an empty BlockFile
     * Params:
     *   filename = File name of the blockfile
     *   description = this text will be written to the header
     *   BLOCK_SIZE = set the block size of the underlying BlockFile.
     *   file_label = Used to set the type and version 
     */
    static void create(string filename, string description, immutable uint BLOCK_SIZE, string file_label = null, const uint max_size = 0x80) {
        import std.file : exists;

        check(!filename.exists, format("Error: File %s already exists", filename));
        auto _file = File(filename, "w+");
        auto blockfile = new BlockFile(_file, BLOCK_SIZE);
        scope (exit) {
            blockfile.close;
        }
        blockfile.createHeader(description, file_label, max_size);
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
        blockfile._recycler_statistic = old_blockfile._recycler_statistic;
        blockfile.headerblock.write(_file);
        blockfile._last_block_index = 1;
        blockfile.masterblock.write(_file, blockfile.BLOCK_SIZE);
        // blockfile.hasheader = true;
        blockfile.store;
        return blockfile;
    }

    /** 
     * Opens an existing file which previously was created by BlockFile.create
     * Params:
     *   filename = Name of the blockfile
     *   read_only = If `true` the file is opened as read-only
     * Returns: 
     */
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

        if (file.isOpen) {
            (() @trusted { file.unlock; })();
        }

        file.close;

    }

    bool empty() const pure nothrow {
        return root_index is Index.init;
    }

    ~this() {
        file.close;
    }
    /** 
     * Creates the header block.
     * Params:
     *   name = name of the header
     */
    protected void createHeader(string name, string file_label, const uint max_size) {
        check(!hasHeader, "Header is already created");
        check(file.size == 0, "Header can not be created the file is not empty");
        check(name.length < headerblock.id.length,
                format("Id is limited to a length of %d but is %d",
                headerblock.id.length, name.length));
        check(file_label.length <= FILE_LABEL.length,
                format("Max size of file label is %d but '%s' is %d",
                FILE_LABEL.length, file_label, file_label.length));
        if (!file_label) {
            file_label = FILE_LABEL;
        }
        headerblock.label = ubyte.max;
        headerblock.id = ubyte.max;
        headerblock.label[0 .. file_label.length] = file_label;
        headerblock.block_size = BLOCK_SIZE;
        headerblock.max_size = max_size;
        headerblock.id[0 .. name.length] = name;
        headerblock.create_time = Clock.currTime.toUnixTime!long;
        headerblock.write(file);
        _last_block_index = 1;
        masterblock.write(file, BLOCK_SIZE);
        // hasheader = true;
    }

    /** 
     * 
     * Returns: `true` if the blockfile has a header.
     */
    bool hasHeader() const pure nothrow {
        return headerblock !is HeaderBlock.init;
    }

    protected void readInitial() {
        if (file.size > 0) {
            readHeaderBlock;
            _last_block_index--;
            readMasterBlock;
            readStatistic;
            readRecyclerStatistic;
            recycler.read(masterblock.recycle_header_index);
        }
    }

    /**
     * The HeaderBlock is the first block in the BlockFile
    */
    @safe
    struct HeaderBlock {
        enum ID_SIZE = 32;
        enum LABEL_SIZE = 16;
        char[LABEL_SIZE] label; /// Label to set the BlockFile type
        uint block_size; /// Size of the block's
        uint max_size; /// Max size of one blocksegment in block
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
                    buffer[pos .. pos + type.sizeof] = (cast(ubyte*) m.ptr)[0 .. type.sizeof];
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
                format("Label      : %s", label[].until(char.max)),
                format("ID         : %s", id[].until(char.max)),
                format("Block size : %d", block_size),
                format("Max  size  : %d", max_size),
                format("Created    : %s", SysTime.fromUnixTime(create_time).toSimpleString),
            ].join("\n");
        }

        bool checkId(string _id) const pure {
            return equal(_id, id[].until(char.max));
        }

        auto Id() const @nogc {
            return id[].until(char.max);
        }

        bool checkLabel(string _label) const pure {
            return equal(_label, label[].until(char.max));
        }

        auto Label() const @nogc {
            return label[].until(char.max);
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

    @safe @recordType("$@M")
    static struct MasterBlock {
        @label("head") Index recycle_header_index; /// Points to the root of recycle block list
        @label("root") Index root_index; /// Point the root of the database
        @label("block_s") Index statistic_index; /// Points to the statistic data
        @label("recycle_s") Index recycler_statistic_index; /// Points to the recycler statistic data

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
    ulong numberOfBlocks(const ulong size) const pure nothrow @nogc {
        return cast(ulong)((size / BLOCK_SIZE) + ((size % BLOCK_SIZE == 0) ? 0 : 1));
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

    protected void writeRecyclerStatistic() {
        immutable old_recycler_index = masterblock.recycler_statistic_index;

        if (old_recycler_index !is Index.init) {
            dispose(old_recycler_index);
        }
        auto recycler_stat_allocate = save(_recycler_statistic.toDoc);
        masterblock.recycler_statistic_index = Index(recycler_stat_allocate.index);
    }

    ref const(MasterBlock) masterBlock() pure const nothrow {
        return masterblock;
    }

    /// Write the master block to the filesystem and truncate the file
    protected void writeMasterBlock() {
        seek(_last_block_index);
        masterblock.write(file, BLOCK_SIZE);
    }

    private void readMasterBlock() {
        // The masterblock is located at the last_block_index in the file
        seek(_last_block_index);
        masterblock.read(file, BLOCK_SIZE);
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
        seek(Index.init);
        headerblock.read(file, BLOCK_SIZE);
    }

    /** 
     * Read the statistic into the blockfile.
     */
    private void readStatistic() @safe {
        if (masterblock.statistic_index !is Index.init) {
            immutable buffer = load(masterblock.statistic_index);
            _statistic = BlockFileStatistic(Document(buffer));
        }
    }
    /** 
     * Read the recycler statistic into the blockfile.
     */
    private void readRecyclerStatistic() @safe {
        if (masterblock.recycler_statistic_index !is Index.init) {
            immutable buffer = load(masterblock.recycler_statistic_index);
            _recycler_statistic = RecyclerFileStatistic(Document(buffer));
        }
    }

    /** 
     * Loads a document at an index. If the document is not valid it throws an exception.
     * Params:
     *   index = Points to the start of a block in the chain of blocks.
     * Returns: Document of a blocksegment
     */
    const(Document) load(const Index index) {
        check(index <= lastBlockIndex + 1, format("Block index [%s] out of bounds for last block [%s]", index, lastBlockIndex));
        return BlockSegment(this, index).doc;
    }

    T load(T)(const Index index) if (isHiBONRecord!T) {
        import tagion.hibon.HiBONJSON;

        const doc = load(index);

        check(isRecord!T(doc), format("The loaded document is not a %s record on index %s. loaded document: %s", T
                .stringof, index, doc.toPretty));
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
        auto equal_chain = block_chains.equalRange(new const(BlockSegment)(Document.init, index));
        if (!equal_chain.empty) {
            return equal_chain.front.doc;
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

    /** 
     * Marks a block for the recycler as erased
     * This function ereases the block before the store method is called
     * The list of recyclable blocks is also updated after the store method has been called.
     * 
     * This prevents it from damaging the BlockFile until a sequency of operations has been performed,
     * Params:
     *   index = Points to an start of a block in the chain of blocks.
     */
    void dispose(const Index index) {
        if (index is Index.init) {
            return;
        }
        import LEB128 = tagion.utils.LEB128;

        auto equal_chain = block_chains.equalRange(new const(BlockSegment)(Document.init, index));

        if (!equal_chain.empty) {
            import std.stdio;
            import tagion.hibon.HiBONJSON;
            import tagion.dart.DARTBasic;
            import tagion.crypto.SecureNet;
            const net = new StdHashNet();
            
            writefln("TO DISPOSE INDEX %s", index);
            writefln("equal_range=%s", equal_chain.map!(b => format("index %s, doc %s dartIndex %(%02x%)", b.index, b.doc.toPretty, net.dartIndex(b.doc)))); 
        }

        assert(equal_chain.empty, "We should not dispose cached blocks");
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

    /** 
     * Allocates new document
     * Does not acctually update the BlockFile just reserves new block's
     * Params:
     *   doc = Document to be reserved and allocated
     * Returns: a pointer to the blocksegment.
     */

    const(BlockSegment*) save(const(Document) doc) {
        auto result = new const(BlockSegment)(doc, claim(doc.full_size));

        block_chains.stableInsert(result);
        return result;

    }
    /// Ditto
    const(BlockSegment*) save(T)(const T rec) if (isHiBONRecord!T) {
        return save(rec.toDoc);
    }

    
    bool cache_empty() {
        return block_chains.empty;
    }
    const(size_t) cache_len() {
        return block_chains.length;
    }

    /** 
     * This function will erase, write, update the BlockFile and update the recyle bin
     * Stores the list of BlockSegment to the disk
     * If this function throws an Exception the Blockfile has not been updated
     */
    void store() {
        writeStatistic;
        _recycler_statistic(recycler.length());
        writeRecyclerStatistic;

        scope (exit) {
            block_chains.clear;
            file.flush;
            file.sync;
        }
        scope (success) {

            masterblock.recycle_header_index = recycler.write();
            writeMasterBlock;
        }

        foreach (block_segment; block_chains) {
            block_segment.write(this);
        }

    }

    struct BlockSegmentRange {
        BlockFile owner;

        Index index;
        Index last_index;
        BlockSegmentInfo current_segment;

        this(BlockFile owner) {
            this.owner = owner;
            index = (owner.lastBlockIndex == 0) ? Index.init : Index(1UL);
            initFront;
        }

        this(BlockFile owner, Index from, Index to) {
            this.owner = owner;
            index = from;
            last_index = to;
            index = (owner.lastBlockIndex == 0) ? Index.init : Index(1UL);
            findNextValidIndex(index);
            initFront;
        }

        alias BlockSegmentInfo = Tuple!(Index, "index", string, "type", ulong, "size", Document, "doc");
        private void findNextValidIndex(ref Index index) {
            while (index < owner.lastBlockIndex) {
                const doc = owner.load(index)
                    .ifThrown(Document.init);
                if (!doc.isinit) {
                    break;
                }
                index += 1;

            }
        }

        private void initFront() @trusted {
            import std.format;
            import core.exception : ArraySliceError;
            import tagion.dart.Recycler : RecycleSegment;
            import tagion.utils.Term;

            const doc = owner.load(index);
            ulong size;

            try {

                if (isRecord!RecycleSegment(doc)) {
                    const segment = RecycleSegment(doc, index);
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

            if (index == Index.init || current_segment == BlockSegmentInfo.init ||
                    (!last_index.isinit && index >= last_index)) {
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

    BlockSegmentRange opSlice(I)(I from, I to) if (isIntegral!I || is(I : const(Index))) {
        if (from.isinit && to.isinit) {
            return opSlice();
        }
        return BlockSegmentRange(this, Index(from), Index(to));
    }
    /**
     * Used for debuging only to dump the Block's
     */
    void dump(const uint segments_per_line = 6,
            const Index from = Index.init,
            const Index to = Index.init,
            File fout = stdout) {
        fout.writefln("|TYPE [INDEX]SIZE");

        BlockSegmentRange seg_range = opSlice(from, to);
        uint pos = 0;
        foreach (seg; seg_range) {
            if (pos == segments_per_line) {
                fout.writef("|");
                fout.writeln;
                pos = 0;
            }
            fout.writef("|%s [%s]%s", seg.type, seg.index, seg.size);
            pos++;
        }
        fout.writef("|");
        fout.writeln;
    }

    void recycleDump(File fout = stdout) {
        import tagion.dart.Recycler : RecycleSegment;

        // writefln("recycle dump from blockfile");

        Index index = masterblock.recycle_header_index;

        if (index == Index(0)) {
            return;
        }
        while (index != Index.init) {
            auto add_segment = RecycleSegment(this, index);
            fout.writefln("Index(%s), size(%s), next(%s)", add_segment.index, add_segment
                    .size, add_segment.next);
            index = add_segment.next;
        }
    }

    void statisticDump(File fout = stdout) const {
        fout.writeln(_statistic.toString);
        fout.writeln(_statistic.histogramString);
    }

    void recycleStatisticDump(File fout = stdout) const {
        fout.writeln(_recycler_statistic.toString);
        fout.writeln(_recycler_statistic.histogramString);
    }

    // Block index 0 is means null
    // The first block is use as BlockFile header
    unittest {
        enum SMALL_BLOCK_SIZE = 0x40;
        import std.format;
        import tagion.basic.basic : forceRemove;

        /// Test of BlockFile.create and BlockFile.opCall
        {
            immutable filename = fileId("create").fullpath;
            filename.forceRemove;
            BlockFile.create(filename, "create.unittest", SMALL_BLOCK_SIZE);
            auto blockfile_load = BlockFile(filename);
            scope (exit) {
                blockfile_load.close;
            }
        }

        {
            import std.exception : assertThrown, ErrnoException;

            // try to load an index that is out of bounds of the blockfile. 
            const filename = fileId.fullpath;
            filename.forceRemove;
            BlockFile.create(filename, "create.unittest", SMALL_BLOCK_SIZE);
            auto blockfile = BlockFile(filename);

            assertThrown!BlockFileException(blockfile.load(Index(5)));
        }

        /// Create BlockFile
        {
            // Delete test blockfile
            // Create new blockfile
            File _file = File(fileId.fullpath, "w+");
            auto blockfile = new BlockFile(_file, SMALL_BLOCK_SIZE);

            assert(!blockfile.hasHeader);
            blockfile.createHeader("This is a Blockfile unittest", "ID", 0x80);
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
