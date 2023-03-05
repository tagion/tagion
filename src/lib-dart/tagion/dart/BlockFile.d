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

import std.array : array, join;
import std.datetime;
import std.format;
import std.conv : to;
import std.traits;
import std.exception : assumeUnique, assumeWontThrow;
import std.container.rbtree : RedBlackTree, redBlackTree;

import tagion.basic.Types : Buffer, FileExtension;
import tagion.basic.Basic : basename, log2, assumeTrusted;
import tagion.basic.TagionExceptions : Check;

import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;
import tagion.dart.DARTException : BlockFileException;
import tagion.logger.Statistic;

import std.math : rint;

enum BLOCK_SIZE = 0x80;

version (unittest) {
    import Basic = tagion.basic.Basic;

    enum random = false;

    const(Basic.FileNames) fileId(T = BlockFile)(string prefix = null) @safe {
        return Basic.fileId!T(FileExtension.dart, prefix);
    }
}
else {
    enum random = true;
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
    immutable uint DATA_SIZE;
    alias BlockFileStatistic = Statistic!(uint, Yes.histogram);
    static bool do_not_write;
    protected {
        File file;
        RecycleIndices recycle_indices;
        uint last_block_index;
        MasterBlock masterblock;
        HeaderBlock headerblock;
        bool hasheader;
        BlockFileStatistic _statistic;
    }

    const(BlockFileStatistic) statistic() const pure nothrow @nogc {
        return _statistic;
    }

    bool isRecyclable(const uint index) const pure nothrow @nogc {
        return recycle_indices.isRecyclable(index);
    }

    void recycleDump() {
        recycle_indices.dump;
    }

    struct RecycleIndices {
        uint max_iteration = uint.max;
        alias Indices = RedBlackTree!(uint, (a, b) => a < b);
        alias Segments = RedBlackTree!(Segment, (a, b) => a.size < b.size, true);
        protected Indices indices;
        protected BlockFile owner;
        protected bool[uint] recycled_blocks_which_needs_to_be_saved;
        protected Segments recycle_segments;

        alias Range = Indices.Range;
        @disable this();
        this(BlockFile owner) pure nothrow {
            this.owner = owner;
            indices = new Indices;
            recycle_segments = new Segments;
        }

        const(Segments) segments() const {
            return recycle_segments;
        }

        private Range opSlice() {
            return indices[];
        }

        uint next(const uint index) const {
            auto next_range = indices.lowerBound(index);
            if (next_range.empty) {
                return INDEX_NULL;
            }
            return next_range.back;
        }

        uint previous(const uint index) const {
            auto previous_range = indices.upperBound(index);
            if (previous_range.empty) {
                return INDEX_NULL;
            }
            return previous_range.front;
        }

        void add(const uint index) {
            indices.insert(index);
            recycled_blocks_which_needs_to_be_saved[index] = true;
            do_save(index);
        }

        alias opAssign = add;

        protected void do_save(const uint index) {
            immutable next_index = next(index);
            if ((next_index !is INDEX_NULL) && (index + 1 !is next_index)) {
                recycled_blocks_which_needs_to_be_saved[next_index] = true;
            }
            immutable previous_index = previous(index);
            if ((previous_index !is INDEX_NULL) && (previous_index + 1 !is index)) {
                recycled_blocks_which_needs_to_be_saved[previous_index] = true;
            }
        }

        bool needs_saving(const uint index) pure const nothrow {
            return (index in recycled_blocks_which_needs_to_be_saved) !is null;
        }

        bool isRecyclable(const uint index) const pure nothrow @nogc {
            return index in indices;
        }

        void reclaim(const uint index) {
            if (index in indices) {
                do_save(index);
                recycled_blocks_which_needs_to_be_saved.remove(index);
                indices.removeKey(index);
            }
        }

        void write() {
            uint order_blocks(
                    ref Range range,
                    const uint previous_index = INDEX_NULL) {
                if (!range.empty) {
                    immutable index = range.front;
                    if (index < owner.last_block_index) {
                        range.popFront;
                        const next_index = order_blocks(range, index);
                        const block = owner.block(previous_index, next_index, 0, null, false);
                        if (index in recycled_blocks_which_needs_to_be_saved) {
                            owner.write(index, block);
                        }
                        return index;
                    }
                }
                return INDEX_NULL;
            }

            auto range = indices[];
            scope (exit) {
                recycled_blocks_which_needs_to_be_saved = null;
            }
            if (range.empty) {
                owner.masterblock.recycle_header_index = INDEX_NULL;
            }
            else {
                owner.masterblock.recycle_header_index = range.front;
                order_blocks(range);
            }

        }

        void read() {
            indices.clear;
            void read_recycle_list(const uint start_index) {
                uint index = start_index;
                while (index !is INDEX_NULL) {
                    const block = owner.read(index);

                    

                    .check(block !is null, format("Block @ %d does not exist in the recycle list of the blockfile", index));
                    max_iteration--;

                    

                    .check(max_iteration > 0, format("Block @ %d max iteration exceeds when reading of the recycle list of the blockfile", index));
                    indices.insert(index);
                    index = block.next;
                }
            }

            read_recycle_list(owner.masterblock.recycle_header_index);
            build_segments;
        }

        void dump() @trusted {
            auto s = recycle_segments[];
            if (!s.empty) {
                writefln("segments %-(%s %)", s.map!(a => a.toInfo));
                writefln("indices =%s", indices[]);
                writefln("s.back.end_index=%d last_block_index=%d s.end_index=%d back=%s", s.back.end_index, owner
                        .last_block_index, s.front.end_index, s.back.toInfo);

            }

        }

        void build_segments()
        out {
            assert(check);
        }
        do {
            recycle_segments = update_segments;
        }

        protected Segments update_segments(bool segments_needs_saving = false)() {
            // Find continues segments of blocks
            auto segments = new Segments;
            void find_segments(bool first = false, R)(
                    ref R range,
                    const uint previous_index = INDEX_NULL,
                    const uint begin_index = INDEX_NULL) {
                if (!range.empty) {
                    immutable index = range.front;
                    range.popFront;
                    static if (first) {
                        find_segments(range, index, index);
                    }
                    else {
                        if ((previous_index + 1 !is index)) {
                            find_segments(range, index, index);
                            auto new_segment = Segment(begin_index, previous_index + 1);
                            if (new_segment.end_index < owner.last_block_index) {
                                segments.insert(new_segment);
                            }
                        }
                        else {
                            find_segments(range, index, begin_index);
                        }
                    }
                }
                else if (begin_index !is INDEX_NULL) {
                    auto new_segment = Segment(begin_index, previous_index + 1);
                    if (new_segment.end_index < owner.last_block_index) {
                        segments.insert(Segment(begin_index, previous_index + 1));
                    }
                }
            }

            auto range = indices[];
            static if (segments_needs_saving) {
                auto range_needs_saving = range.filter!(a => needs_saving(a));
                find_segments!true(range_needs_saving);
            }
            else {
                find_segments!true(range);
            }
            return segments;
        }

        const(uint) reserve_segment(bool random_block = random_)(const uint size) {
            void remove_segment(const(Segment) segment_to_be_removed, const uint size)
            in {
                assert(segment_to_be_removed.size >= size);
            }
            do {
                recycle_segments.removeKey(segment_to_be_removed);
                version (unittest) {
                    foreach (index; segment_to_be_removed.begin_index .. segment_to_be_removed.begin_index + size) {
                        scope block = owner.read(index);
                        assert(block);
                        assert(!block.head, format("Header marker detected in recycle block @ index=%d", index));
                        assert(block.size == 0, format("Recycle block @ index %d shoud have zero size", index));
                    }
                }
                foreach (index; segment_to_be_removed.begin_index .. segment_to_be_removed.begin_index + size) {
                    indices.removeKey(index);
                }
                if (size < segment_to_be_removed.size) {
                    recycle_segments.insert(Segment(segment_to_be_removed.begin_index + size, segment_to_be_removed
                            .end_index));
                }

            }

            static if (random_block) {
                import std.random;

                scope segments = array(recycle_segments[]);
                scope random_range = randomSample(segments, segments.length);
                foreach (segment; random_range) {
                    if ((size == segment.size) || (size * 2 <= segment.size) || owner.check_statistic(segment.size, size)) {
                        remove_segment(segment, size);
                        return segment.begin_index;
                    }
                }
            }
            else {
                if (!recycle_segments.empty) {
                    enum dummy_begin_index = 1;
                    const search_segment = Segment(dummy_begin_index, dummy_begin_index + size);
                    auto equal = recycle_segments.equalRange(search_segment);
                    if (!equal.empty) {
                        auto found = equal.front;
                        assert(found.size == size);
                        remove_segment(found, size);
                        return found.begin_index;
                    }
                    else {
                        auto upper = recycle_segments.upperBound(search_segment);
                        if (!upper.empty) {
                            auto found = upper.front;

                            

                            .check(found.end_index < owner.last_block_index,
                                    format("recylce blocks=%d extends beond last_block_index=%d",
                                    found.end_index, owner.last_block_index));
                            assert(found.end_index < owner.last_block_index);
                            if ((size * 2 <= found.size) || owner.check_statistic(found.size, size)) {
                                remove_segment(found, size);
                                return found.begin_index;
                            }
                        }
                    }
                }
            }
            scope (success) {
                owner.last_block_index += size;
            }
            return owner.last_block_index;
        }

        /++
         + Params:
         +     end_index = Points to an existg block in the blockfile
         + Returns:
         +     Returns the begin_index of the next data block after end_index
         +     If the value is INDEX_NULL then this block chain is the first block chain
         +     in the blockfile
         +/
        uint next_begin_index(const uint end_index) {
            uint search(R)(ref R range, const uint previous_index) {
                if (!range.empty) {
                    immutable current_index = range.front;
                    if (previous_index + 1 is current_index) {
                        range.popFront;
                        return search(range, current_index);
                    }
                }
                return previous_index;
            }

            auto next_range = indices.upperBound(end_index);
            return search(next_range, end_index) + 1;
        }

        /++
         + Params:
         +    begin_index = Points to an existg block in the blockfile
         + Returns:
         +    Returns the end_index of the previous data block before begin_index
         +    If the value is INDEX_NULL then this block chain is the last block chain
         +    in the blockfile
         +/
        uint previous_end_index(const uint begin_index) const {
            uint search(R)(ref R range, const uint next_index) {
                if (!range.empty) {
                    immutable current_index = range.back;
                    if (current_index + 1 is next_index) {
                        range.popBack;
                        return search(range, current_index);
                    }
                }
                return next_index;
            }

            auto previous_range = indices.lowerBound(begin_index);
            return search(previous_range, begin_index) - 1;
        }

        void trim_last_block_index(ref scope Block[uint] blocks) {
            if (!indices.empty) {
                immutable current_index = indices.back;
                if (current_index + 1 is owner.last_block_index) {
                    owner.last_block_index = current_index;
                    indices.removeBack;
                    trim_last_block_index(blocks);
                }
            }
            if (owner.last_block_index > 1) {
                immutable end_of_blocks_index = owner.last_block_index - 1;
                if (end_of_blocks_index in blocks) {
                    const end_block = blocks[end_of_blocks_index];
                    if (end_block.next !is INDEX_NULL) {
                        blocks[end_of_blocks_index] = owner.block(end_block.previous, INDEX_NULL, end_block.size, end_block
                                .data, end_block.head);
                    }
                }
            }
        }

        bool check() pure const {
            scope indices_range = indices[];
            scope recycle_sorted_tree = redBlackTree!("a.begin_index < b.begin_index")(
                    recycle_segments[]);
            scope recycle_range = recycle_sorted_tree[];
            while (!indices_range.empty) {
                immutable index = indices_range.front;
                indices_range.popFront;
                if (recycle_range.empty) {
                    return false;
                }
                immutable segment = recycle_range.front;
                if (index < segment.begin_index) {
                    return false;
                }
                else if (index + 1 == segment.end_index) {
                    recycle_range.popFront;
                }
            }

            return recycle_range.empty;
        }
    }

    protected this(
            string filename,
            immutable uint SIZE,
            const bool read_only = false) {
        File file;

        if (read_only) {
            file.open(filename, "r");
        }
        else {
            file.open(filename, "r+");
        }
        this(file, SIZE);
    }

    protected this(
            File file,
            immutable uint SIZE) {
        this.BLOCK_SIZE = SIZE;
        DATA_SIZE = BLOCK_SIZE - Block.HEADER_SIZE;
        this.file = file;
        recycle_indices = RecycleIndices(this);
        readInitial;
    }

    /**
       Used by the Inspect
    */
    protected this(immutable uint SIZE) pure nothrow {
        this.BLOCK_SIZE = SIZE;
        DATA_SIZE = BLOCK_SIZE - Block.HEADER_SIZE;
        recycle_indices = RecycleIndices(this);
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
            File file;
            file.open(filename, "r");
            BlockFile.HeaderBlock headerblock;
            file.seek(0);
            headerblock.read(file, DEFAULT_BLOCK_SIZE);
            result = new BlockFile(headerblock.block_size);
            result.file = file;
        });
        if (result.file.size == 0) {
            report(format("BlockFile %s size is 0", filename));
        }
        if (result) {
            try_it(&result.readHeaderBlock);
            result.last_block_index--;
            try_it(&result.readMasterBlock);
            try_it(&result.readStatistic);
            result.recycle_indices = RecycleIndices(result);
            result.recycle_indices.max_iteration = max_iteration;
            try_it(&result.recycle_indices.read);
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
        File file;
        file.open(filename, "w+");
        auto blockfile = new BlockFile(file, BLOCK_SIZE);
        blockfile.createHeader(description);
        blockfile.writeMasterBlock;
        scope (exit) {
            blockfile.close;
        }
    }

    static BlockFile reset(string filename) {
        immutable old_filename = filename.setExtension("old");
        filename.rename(old_filename);
        auto old_blockfile = BlockFile(old_filename);
        old_blockfile.readStatistic;

        File file;
        file.open(filename, "w+");
        auto blockfile = new BlockFile(file, old_blockfile.headerblock.block_size);
        blockfile.headerblock = old_blockfile.headerblock;
        blockfile._statistic = old_blockfile._statistic;
        blockfile.headerblock.write(file);
        blockfile.last_block_index = 1;
        blockfile.masterblock.write(file, blockfile.BLOCK_SIZE);
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
        auto temp_file = new BlockFile(filename, DEFAULT_BLOCK_SIZE, read_only);
        immutable SIZE = temp_file.headerblock.block_size;
        temp_file.close;
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
        last_block_index = 1;
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
            last_block_index--;
            readMasterBlock;
            readStatistic;
            version (blockfile_recycle)
                recycle_indices.read;
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

    final uint lastBlockIndex() const pure nothrow {
        return last_block_index;
    }

    final protected void seek(const uint index) {
        file.seek(index_to_seek(index));
    }

    /++
     + The MasterBlock is the last block in the BlockFile
     + This block maintains the indices to of other block
     +/

    @safe
    static struct MasterBlock {
        uint recycle_header_index; /// Points to the root of recycle block list
        uint first_index; /// Points to the first block of data
        uint root_index; /// Point the root of the database
        uint statistic_index; /// Points to the statistic data
        final void write(
                ref File file,
                immutable uint BLOCK_SIZE) const @trusted {
            auto buffer = new ubyte[BLOCK_SIZE];
            size_t pos;
            foreach (i, m; this.tupleof) {
                buffer.binwrite(m, &pos);
            }
            buffer[$ - FILE_LABEL.length .. $] = cast(ubyte[]) FILE_LABEL;
            assert(!BlockFile.do_not_write, "Should not write here");
            file.rawWrite(buffer);
            // Truncate the file after the master block
            file.truncate(file.size);
            file.sync;
        }

        final void read(ref File file, immutable uint BLOCK_SIZE) {
            auto buffer = new ubyte[BLOCK_SIZE];
            auto buf = file.rawRead(buffer);
            foreach (i, ref m; this.tupleof) {
                alias type = typeof(m);
                m = buf.binread!type;
            }
        }

        string toString() const pure nothrow {
            return assumeWontThrow([
                "Master Block",
                format("Root       @ %d", root_index),
                format("First      @ %d", first_index),
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
    void root_index(const uint index)
    in {
        assert(index > 0 && index < last_block_index);
    }
    do {
        masterblock.root_index = index;
    }

    uint root_index() const pure nothrow {
        return masterblock.root_index;
    }

    /++
     + Params:
     +     size = size of data bytes
     +
     + Returns:
     +     The number of blocks used to allocate size bytes
     +/
    uint number_of_blocks(const size_t size) const pure nothrow {
        return cast(uint)((size / DATA_SIZE) + ((size % DATA_SIZE == 0) ? 0 : 1));
    }

    /++
     + Params:
     +      index = Block index pointer
     +
     + Returns:
     +      the file pointer in byte counts
     +/
    ulong index_to_seek(const uint index) const pure nothrow {
        return BLOCK_SIZE * cast(ulong) index;
    }

    /++
     + Block handler
     +/
    @safe
    static class Block {
        immutable uint previous; /// Points to the previous block
        immutable uint next; /// Points to the next block
        immutable uint size; /// size of the data in this block
        immutable bool head; /// Set to `true` this block starts a chain of blocks
        enum uint HEAD_MASK = 1 << (uint.sizeof * 8 - 1);
        enum HEADER_SIZE = cast(uint)(previous.sizeof + next.sizeof + size.sizeof);
        immutable(Buffer) data;
        void write(ref File file, immutable uint BLOCK_SIZE) const @trusted {
            scope buffer = new ubyte[BLOCK_SIZE];
            size_t pos;
            foreach (i, m; this.tupleof) {
                alias type = typeof(m);
                enum name = this.tupleof[i].stringof;
                static if (is(type : Buffer)) {
                    buffer[pos .. pos + m.length] = m;
                    pos += m.length;
                }
                else static if (name != this.head.stringof) {
                    static if (name == this.size.stringof) {
                        buffer.binwrite(m | (head ? HEAD_MASK : 0), &pos);
                    }
                    else {
                        buffer.binwrite(m, &pos);
                    }
                }

            }
            assert(!BlockFile.do_not_write, "Should not write here");

            file.rawWrite(buffer[0 .. pos]);
        }

        private this(ref File file, immutable uint BLOCK_SIZE)
        in {
            assert(HEADER_SIZE < BLOCK_SIZE);
        }
        do {

            scope buffer = new ubyte[BLOCK_SIZE];
            scope buf = file.rawRead(buffer);
            foreach (i, m; this.tupleof) {
                alias type = typeof(m);
                enum name = this.tupleof[i].stringof;
                static if (name != this.data.stringof) {
                    static if (name == this.size.stringof) {
                        immutable _size = buf.binread!type;
                        size = _size & (~HEAD_MASK);
                        head = (_size & HEAD_MASK) != 0;
                    }
                    else static if (name != this.head.stringof) {
                        this.tupleof[i] = buf.binread!type;
                    }
                }
            }
            immutable size_t data_size = (size <= buf.length) ? size : buf.length;
            data = buf[0 .. data_size].idup;
        }

        private this(
                immutable uint previous,
                immutable uint next,
                immutable uint size,
                immutable(Buffer) buf,
                const bool head) pure nothrow {
            this.previous = previous;
            this.next = next;
            this.size = size;
            this.head = head;
            data = buf;
        }

    }

    protected final Block block(immutable uint previous, immutable uint next, immutable uint size, immutable(
            Buffer) buf, const bool head)
    in {
        assert(buf.length <= DATA_SIZE);
    }
    do {
        return new Block(previous, next, size, buf, head);
    }

    /++
     + Read's a block at the current index
     +/
    protected final Block block(ref File file) {
        return new Block(file, BLOCK_SIZE);
    }

    /++
     + Write a block to the current index
     +/
    protected final write(ref const Block block, ref File file) {
        with (block) {
            block.write(file, BLOCK_SIZE);
        }
    }

    /++
     + Returns:
     +     information text of the block
     +/
    string toInfo(const Block block) const {
        with (block) {
            return format("<-[%04d] ->[%04d] blocks=%d size=%d head=%s", previous, next, number_of_blocks(
                    size), size, head);
        }
    }

    @safe
    static struct Segment {
        protected uint _begin_index;
        protected uint _size;
        invariant {
            assert(_size > 0);
        }

        this(const uint from, const uint to)
        in {
            assert(from < to);
        }
        do {
            _size = to - from;
            _begin_index = from;
        }

        uint size() pure const nothrow {
            return _size;
        }

        uint begin_index() pure const nothrow {
            return _begin_index;
        }

        uint end_index() pure const nothrow {
            return _begin_index + _size;
        }

        string toInfo() const {
            return format("[%d..%d]:%d", begin_index, end_index, size);
        }

    }

    /++
     + Write a block to the index
     + Params:
     +     index = Block index poiter where to write in the block file
     +     block = The block to be written
     +/
    protected void write(scope const uint index, const(Block) block) {
        seek(index);
        block.write(file, BLOCK_SIZE);
    }

    protected void writeStatistic() {
        // Allocate block for statistical data
        immutable old_statistic_index = masterblock.statistic_index;

        auto statistical_allocate = save(_statistic.toDoc.serialize, random);
        masterblock.statistic_index = statistical_allocate.begin_index;
        if (old_statistic_index !is INDEX_NULL) {
            // The old statistic block is erased
            erase(old_statistic_index);
        }
    }

    ref const(MasterBlock) masterBlock() pure const nothrow {
        return masterblock;
    }

    ref const(HeaderBlock) headerBlock() pure const nothrow {
        return headerblock;
    }

    // Write the master block to the filesystem and truncate the file
    protected void writeMasterBlock() {
        seek(last_block_index);
        masterblock.write(file, BLOCK_SIZE);
    }

    Block read(const uint index) {
        Block result;
        if (index < last_block_index) {
            seek(index);
            result = block(file);
        }
        return result;
    }

    private void readHeaderBlock() {
        check(file.size % BLOCK_SIZE == 0,
                format("BlockFile should be sized in equal number of blocks of the size of %d but the size is %d", BLOCK_SIZE, file
                .size));
        last_block_index = cast(uint)(file.size / BLOCK_SIZE);
        check(last_block_index > 1, format("The BlockFile should at least have a size of two block of %d but is %d", BLOCK_SIZE, file
                .size));
        // The headerblock is locate in the start of the file
        seek(0);
        headerblock.read(file, BLOCK_SIZE);
        hasheader = true;
    }

    private void readMasterBlock() {
        // The masterblock is locate as the lastblock in the file
        seek(last_block_index);
        masterblock.read(file, BLOCK_SIZE);
    }

    private void readStatistic() @safe {
        if (masterblock.statistic_index !is INDEX_NULL) {
            immutable buffer = load(masterblock.statistic_index);
            _statistic = BlockFileStatistic(Document(buffer));
        }
    }

    /++
     + Loads a chain of blocks from the filesystem starting from index
     + This function will not load data in AllocatedChain list
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
    immutable(Buffer) load(const uint index, const bool check_format = true) {
        auto first_block = read(index);
        // Check if this is the first block is the start of a block sequency
        check(check_format || first_block.head, format(
                "Block @ %d is not the head of block sequency", index));
        Buffer build_sequency(Block block) @safe {
            scope buffer = new ubyte[first_block.size];
            auto cache = buffer;
            while (block.size > DATA_SIZE) {
                cache[0 .. DATA_SIZE] = block.data;
                auto next_block = read(block.next);
                check(next_block !is null, format("Fatal error in the blockfile @ %d", block.next));
                check(check_format || !next_block.head, format(
                        "Block @ %d is marked as head of block sequency but it should not be", index));
                block = next_block;
                cache = cache[DATA_SIZE .. $];
            }

            {
                check(check_format || block.size !is 0, format("Block @ %d has the size zero", index));
                cache[0 .. block.size] = block.data[0 .. block.size];
            }
            return buffer.idup;
        }

        return build_sequency(first_block);
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
    uint erase(const uint index) {
        version (none) {
            console.writef("%d [ ", index);
            scope (exit) {
                console.writeln("]");
                console.writefln("recycle_indices = %s", recycle_indices[]);
                console.writefln("recycled_to_save= %s", recycle_indices
                        .recycled_blocks_which_needs_to_be_saved.keys.sort);
            }

            auto block_range = range(index);
            if (!block_range.empty) {
                check(block_range.front.head, format("Block @ %d is not pointing to the begin of a block sequency", index));
            }

        }
        @safe uint remove_sequency(bool first = false)(const uint index) {
            auto block = read(index);
            check(!recycle_indices.isRecyclable(index), format("Block %d has already been delete", index));

            static if (first) {
                // Check if this is the first block in a block sequency
                check(block.head, "Load index is not pointing to the begin of a block sequency");
            }
            version (blockfile_recycle)
                recycle_indices = index;
            if (block.size > DATA_SIZE) {
                return remove_sequency(block.next);
            }
            if (index >= masterblock.first_index) {
                masterblock.first_index = index + 1;
            }
            return block.next;
        }

        if (index !is INDEX_NULL) {
            return remove_sequency!true(index);
        }
        return INDEX_NULL;
    }

    uint end_index(const uint index) {
        @safe uint search(const uint index) {
            if (index !is INDEX_NULL) {
                const block = read(index);
                check(block.size > 0,
                        format("Bad data block @ %d the size is zero", index));
                if (block.size > DATA_SIZE) {
                    return search(block.next);
                }
                else {
                    return block.next;
                }
            }
            return INDEX_NULL;
        }

        return search(index);
    }

    /++
     + This object handles the allocation data-buffer.
     + By splitting the data buffer into a chain of blocks
     + If possible it recycling old deleted blocks
     +/
    class AllocatedChain {
        @recordType("ACHAIN") struct Chain {
            Buffer data;
            uint begin_index;
            mixin HiBONType;
        }

        protected Chain chain;
        this(const Document doc) {
            chain = Chain(doc);
        }

        inout(HiBON) toHiBON() inout {
            return chain.toHiBON;
        }

        final immutable(Buffer) data() const pure nothrow {
            return chain.data;
        }
        // This function reserves blocks and recycles blocks if possible
        protected void reserve(bool random_block)()
        in {
            assert(chain.begin_index == 0, "Block is already reserved");
        }
        do {
            immutable size = number_of_blocks(chain.data.length);
            chain.begin_index = recycle_indices.reserve_segment!random_block(size);
            _statistic(size);
        }

        this(immutable(Buffer) buffer, immutable bool random_block = random)
        in {
            assert(buffer.length > 0, "Buffer size can not be zero");
        }
        do {
            chain.data = buffer;
            if (random_block) {
                reserve!true;
            }
            else {
                reserve!false;
            }
        }

        string toInfo() const {
            return format("[%d..%d] blocks=%s size=%5d", chain.begin_index, end_index, number_of_blocks(
                    size), size);
        }

    final:

        uint begin_index() pure const nothrow {
            return chain.begin_index;
        }

        uint end_index() pure const nothrow {
            return chain.begin_index + number_of_blocks(chain.data.length);
        }

        uint size() pure const nothrow {
            import LEB128 = tagion.utils.LEB128;

            const leb128_size = LEB128.decode!ulong(chain.data);
            return cast(uint)(leb128_size.size);
        }

    }

    protected AllocatedChain[] allocated_chains;

    /++
     + Allocates new data block
     + Does not acctually update the BlockFile just reserves new block's
     +
     + Params:
     +     data = Data buffer to be reserved and allocated
     +/
    const(AllocatedChain) save(immutable(Buffer) data, bool random_block = random) {
        auto result = new AllocatedChain(data, random_block);
        allocated_chains ~= result;
        return result;
    }

    HiBON toHiBON() const {
        auto result = new HiBON;
        foreach (i, a; allocated_chains) {
            result[i] = a.toHiBON;
        }
        return result;
    }

    protected void fromDoc(const(Document) doc) {
        allocated_chains = null;

        

        .check(doc.isArray, "Document should be an array");
        foreach (a; doc[]) {
            const sub_doc = a.get!Document;
            allocated_chains ~= new AllocatedChain(sub_doc);
        }
    }

    /++
     +
     + This function will erase, write, update the BlockFile and update the recyle bin
     + Stores the list of AllocatedChain to the disk
     + If this function throws an Exception the Blockfile has not been updated
     +
     +/
    void store() {
        debug scope (exit) {
            bool failsafe(const uint index, const Fail f, const Block block, const bool recycle_block) @safe {
                if (f != Fail.NON) {
                    console.writefln("Data check fails on block @ [%d <- %d -> %d]: Fail:%s in %s",
                            block.previous, index, block.next, f, recycle_block ? "recycle block" : "data block");
                }
                return false;
            }

            assert(!inspect(&failsafe), "Should not fail here");
        }
        Block[uint] blocks;
        scope (success) {
            allocated_chains = null;
            recycle_indices.write;

            { //write_blocks_in_sorted_order
                auto sorted_indices = blocks.keys.dup.sort;
                sorted_indices.each!(index => write(index, blocks[index]));
            }

            writeMasterBlock;
            recycle_indices.build_segments;
        }

        {
            do_not_write = true;
            scope (exit) {
                do_not_write = false;
            }

            writeStatistic;
            // Sortes the blocks in order
            const(Block) local_read(const uint index) {
                if (index in blocks) {
                    return blocks[index];
                }
                else {
                    return read(index);
                }
            }

            void allocate_and_chain(SortedSegments)(
                    const(AllocatedChain[]) allocate,
            ref scope SortedSegments sorted_segments) @safe {
                if (allocate.length > 0) {
                    uint chain(
                            immutable(ubyte[]) data,
                    const uint current_index,
                    const uint previous_index,
                    const bool head) @trusted {
                        scope (success) {
                            recycle_indices.reclaim(current_index);
                        }
                        if (data !is null) {
                            // update_first_index(current_index);
                            if (data.length > DATA_SIZE) {
                                void update_first_index(uint current_index) {
                                    if ((masterblock.first_index > current_index) || (
                                            masterblock.first_index is INDEX_NULL)) {
                                        masterblock.first_index = current_index;
                                    }
                                }

                                uint previous = previous_index;
                                uint current = current_index;
                                bool h = head;
                                size_t from = 0;
                                while (from + DATA_SIZE < data.length) {
                                    auto to = from + DATA_SIZE;
                                    auto slice_data = data[from .. to];
                                    const next_index = current + 1;
                                    const size = cast(uint)(data.length - from);
                                    assert(size !is 0, "Block size should not be zero");
                                    blocks[current] = block(previous, next_index, size, slice_data, h);
                                    update_first_index(current);
                                    previous = current;
                                    current = next_index;
                                    h = false;
                                    from += DATA_SIZE;
                                }
                                if (from + DATA_SIZE >= data.length) {
                                    assert(data[from .. $].length !is 0, "Tail data block is zero size");
                                    immutable next_index = chain(data[from .. $], current, current - 1, false);
                                }

                            }
                            else {
                                auto next_index = chain(null, current_index + 1, current_index, false);
                                if (next_index == last_block_index) {
                                    // Make sure the last block is grounded
                                    next_index = INDEX_NULL;
                                }
                                blocks[current_index] = block(previous_index, next_index, cast(uint) data.length, data, head);

                            }
                            return current_index;
                        }
                        uint end_index = current_index;
                        if (!sorted_segments.empty && (
                                current_index is sorted_segments
                                .front.begin_index)) {
                            end_index = sorted_segments.front.end_index;
                        }
                        if (end_index < last_block_index) {
                            return end_index;
                        }
                        return INDEX_NULL;
                    }

                    auto ablock = allocate[0];
                    if (!sorted_segments.empty && (
                            sorted_segments.front.end_index < ablock.begin_index)) {
                        const current_segment = sorted_segments.front;
                        if (current_segment.begin_index > 1) {
                            // Block before the segments need to be rewired
                            immutable begin_block_index = current_segment.begin_index - 1;
                            const begin_block = local_read(begin_block_index);
                            if (begin_block.next !is current_segment.end_index) {
                                blocks[begin_block_index] = block(begin_block.previous, current_segment.end_index,
                                        begin_block.size, begin_block.data, begin_block.head);
                            }
                        }
                        const end_block = local_read(current_segment.end_index);
                        immutable previous_index = (current_segment.begin_index > 0) ? current_segment.begin_index - 1 : INDEX_NULL;
                        if (end_block.previous !is previous_index) {
                            blocks[current_segment.end_index] = block(previous_index, end_block.next, end_block.size, end_block
                                    .data, end_block.head);
                        }
                        sorted_segments.popFront;
                        allocate_and_chain(allocate, sorted_segments);
                    }
                    else {
                        if (!sorted_segments.empty && (
                                sorted_segments.front.end_index is ablock.begin_index)) {
                            chain(ablock.data, ablock.begin_index, sorted_segments.front.begin_index, true);
                        }
                        else {
                            immutable previous_index = (ablock.begin_index > 1) ? ablock.begin_index - 1 : INDEX_NULL;
                            chain(ablock.data, ablock.begin_index, previous_index, true);
                        }
                        allocate_and_chain(allocate[1 .. $], sorted_segments);
                    }
                }
            }
            // Puts data into block and chain the blocks
            sort!(q{a.begin_index < b.begin_index}, SwapStrategy.unstable)(allocated_chains);
            scope segments_needs_saving = array(recycle_indices.update_segments[]).sort!(
                    q{a.end_index < b.begin_index});
            if (!segments_needs_saving.empty && (
                    segments_needs_saving[$ - 1].end_index >= last_block_index)) {
                last_block_index = segments_needs_saving[$ - 1].begin_index;
            }
            allocate_and_chain(allocated_chains, segments_needs_saving);
            recycle_indices.trim_last_block_index(blocks);

            // Write new allocated blocks to the file
        }

        version (none) {
            recycle_indices.write;

            { //write_blocks_in_sorted_order
                auto sorted_indices = blocks.keys.dup.sort;
                sorted_indices.each!(index => write(index, blocks[index]));
            }

            writeMasterBlock;
            recycle_indices.build_segments;
        }
    }

    /++
     + Returns:
     +     General block iterator
     +/
    BlockRange range(const uint index) {
        return BlockRange(this, index);
    }

    /++
     + Returns:
     +     A range which can iterate through the recyclable blocks in the BlockFile
     +/
    BlockRange recycleRange() {
        return range(masterblock.recycle_header_index);
    }

    /++
     + Returns:
     +     A range which can iterate through the used blocks in the BlockFile
     +/
    BlockRange blockRange() {
        return range(masterblock.first_index);
    }

    /++
     + Returns:
     +     A range while iterate through all the data-block in the BlockFile
     +/
    ChainRange chainRange(uint index = INDEX_NULL) {
        if (index is INDEX_NULL) {
            index = masterblock.first_index;
        }
        return ChainRange(this, index);
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
    bool inspect(bool delegate(const uint index, const Fail f, const Block block, const bool recycle_chain) @safe trace) {
        scope bool[uint] visited;
        scope bool end;
        bool failed;
        @safe
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
                if (previous) {
                    if (current.previous >= r.index) {
                        failed = true;
                        end |= trace(r.index, Fail.INCREASING, current, check_recycle_mode);
                    }
                    static if (check_recycle_mode) {
                        if (current.head) {
                            failed = true;
                            end |= trace(r.index, Fail.RECYCLE_HEADER, current, check_recycle_mode);
                        }
                        if (current.size != 0) {
                            failed = true;
                            end |= trace(r.index, Fail.RECYCLE_NON_ZERO, current, check_recycle_mode);
                        }
                    }
                    else {
                        if (!current.head) {
                            if (previous.size != current.size + DATA_SIZE) {
                                failed = true;
                                end |= trace(r.index, Fail.SEQUENCY, current, check_recycle_mode);
                            }
                        }
                        else if (previous.size > DATA_SIZE) {
                            end |= trace(current.previous, Fail.BAD_SIZE, previous, check_recycle_mode);
                        }
                    }
                    if (r.index != previous.next) {
                        failed = true;
                        end |= trace(r.index, Fail.LINK, current, check_recycle_mode);
                    }

                }
                if (!failed) {
                    end |= trace(r.index, Fail.NON, current, check_recycle_mode);
                }
                previous = r.front;
                r.popFront;
            }
        }

        BlockRange r = blockRange;
        check_data!false(r);
        r = recycleRange;
        check_data!true(r);
        return failed;
    }

    /++
     + Range of Block's
     +/
    struct BlockRange {
        private BlockFile owner;
        private uint _index;
        private Block current;
        this(BlockFile owner, const uint index) {
            this.owner = owner;
            if (index !is INDEX_NULL) {
                _index = index;
                current = owner.read(_index);
            }
        }

        bool empty() pure const nothrow {
            return current is null;
        }

        uint index() pure const nothrow {
            return _index;
        }

        void popFront() {
            if (!empty) {
                _index = current.next;
                if (index !is INDEX_NULL) {
                    current = owner.read(_index);
                    return;
                }
            }
            _index = INDEX_NULL;
            current = null;
        }

        Block front() {
            return current;
        }

        int opApply(scope int delegate(const uint index, const(Block) block) @safe dg) {
            for (; !empty; popFront) {
                if (dg(index, front)) {
                    return -1;
                }
            }
            return 0;
        }
    }

    /++
     + Range of data-buffer's
     +/
    struct ChainRange {
        private BlockFile owner;
        private Buffer buffer;
        private uint _index;
        this(BlockFile owner, const uint index) {
            this.owner = owner;
            _index = index;
            popFront;
        }

        bool empty() const pure nothrow {
            return _index is INDEX_NULL;
        }

        Buffer front() const pure nothrow {
            return buffer;
        }

        void popFront() {
            if (!empty) {
                buffer = owner.load(_index);
                _index = owner.end_index(_index);
            }
        }
    }

    enum BlockSymbol {
        file_header = 'H',
        header = 'h',
        empty = '_',
        recycle = 'X',
        data = '#',
        none_existing = 'Z',

    }

    BlockSymbol getSymbol(const scope Block block, const uint index) const pure nothrow {
        if (block) {
            if (index == 0) {
                return BlockSymbol.file_header;
            }
            else if (block.head) {
                return BlockSymbol.header;
            }
            else if (recycle_indices.isRecyclable(index)) {
                return BlockSymbol.recycle;
            }
            else if (block.size == 0) {
                return BlockSymbol.empty;
            }
            else {
                return BlockSymbol.data;
            }
        }
        else {
            return BlockSymbol.none_existing;
        }

    }
    /++
     + Used for debuging only to dump the Block's
     +/
    void dump(const uint block_per_line = 16) {
        auto line = new char[block_per_line];
        foreach (index; 0 .. ((last_block_index / block_per_line) + (
                (last_block_index % block_per_line == 0) ? 0 : 1)) * block_per_line) {
            immutable pos = index % block_per_line;
            if ((index % block_per_line) == 0) {
                line[] = 0;
            }

            scope block = read(index);
            line[pos] = getSymbol(block, index);

            if (pos + 1 == block_per_line) {
                writefln("%04X] %s", index - pos, line);
            }
        }
    }

    // Block index 0 is means null
    enum INDEX_NULL = 0;
    // The first block is use as BlockFile header
    unittest {
        enum SMALL_BLOCK_SIZE = 0x40;
        import std.format;

        /// Test of BlockFile.create and BlockFile.opCall
        {
            immutable filename = fileId("create").fullpath;
            BlockFile.create(filename, "create.unittest", SMALL_BLOCK_SIZE);
            writefln("BlockFile %s", filename);
            auto blockfile_load = BlockFile(filename);
            scope (exit) {
                blockfile_load.close;
            }
        }

        alias B = Tuple!(string, "label", uint, "blocks");
        Buffer generate_block(const BlockFile blockfile, const B b) {
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
            File file = File(fileId.fullpath, "w");
            auto blockfile = new BlockFile(file, SMALL_BLOCK_SIZE);
            assert(!blockfile.hasHeader);
            blockfile.createHeader("This is a Blockfile unittest");
            assert(blockfile.hasHeader);
            file.close;
        }

        {
            // Check the header exists
            auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);
            assert(blockfile.hasHeader);
            blockfile.close;
        }

        bool failsafe(const uint index, const Fail f, const Block block, const bool recycle_block) @safe {
            assert(f == Fail.NON, format("Data check fails on block @ %d: Fail:%s in %s",
                    index, f, recycle_block ? "recycle block" : "data block"));
            return false;
        }

        {
            {
                auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);
                blockfile.inspect(&failsafe);

                B[] allocators = [
                    B("++++Block 0", 5), // 0

                    B("++++Block 1", 2), // 1

                    B("++++Block 2", 1), // 2
                    B("++++Block 3", 3), // 3

                    B("++++Block 4", 2), // 4
                    B("++++Block 5", 1), // 5
                    B("++++Block 6", 2), // 6
                    B("++++Block 7", 4), // 7
                    B("++++Block 8", 4), // 8
                    B("++++Block 9", 9), // 9

                    B("++++Block 10", 8), // 10
                    B("++++Block 11", 4), // 11
                    B("++++Block 12", 1), // 12
                    B("++++Block 13", 3), // 13
                    B("++++Block 14", 2), // 14
                    B("++++Block 15", 3), // 15
                    B("++++Block 16", 5) // 16 Last data block

                ];

                foreach (b; allocators) {
                    blockfile.save(generate_block(blockfile, b));
                }

                // Note the state block is written after the last block
                blockfile.store;

                blockfile.close;
            }

            { /// Check the blockfile
                auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);
                blockfile.inspect(&failsafe);
                blockfile.close;
            }

        }

        void erase(BlockFile blockfile, immutable(uint[]) erase_list) {
            void local_erase(const uint index, immutable(uint[]) erase_list, immutable uint no = 0) {
                if ((index !is INDEX_NULL) && (erase_list.length > 0)) {
                    if (no is erase_list[0]) {
                        immutable end_index = blockfile.erase(index);
                        local_erase(end_index, erase_list[1 .. $], no + 1);
                    }
                else {
                        immutable end_index = blockfile.end_index(index);
                        local_erase(end_index, erase_list, no + 1);
                    }
                }

            }

            local_erase(blockfile.masterblock.first_index, erase_list);
        }

        { // Remove block
            auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);
            blockfile.inspect(&failsafe);
            // Erase chain of block
            erase(blockfile, [0, 2, 6, 13, 16]);
            blockfile.store;

            blockfile.close;
        }

        version (none) { // Check the recycle list
            auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);

            assert(equal(blockfile.recycle_indices[], [
                1, 2, 3, 4, 5, 6,
                10, 11,
                21, 22, 23,
                60, 61, 62,
                69, 70, 71, 72, 73, 74, 75, 76, 77
            ]));
            blockfile.close;
        }

        {
            auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);

            blockfile.erase(blockfile.masterblock.statistic_index);

            blockfile.close;
        }

        { // Write block again
            auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);
            // The statistic block is erased before writing
            // Erase to stat block so it will be recycled
            immutable old_statistic_index = blockfile.masterblock.statistic_index;

            B[] allocators = [
                B("++++Block 17", 9), // 17
                B("++++Block 18", 4), // 18
                B("++++Block 19", 2), // 19
                B("++++Block 20", 1), // 20
                B("++++Block 21", 3), // 21
                B("++++Block 22", 3), // 22
                B("++++Block 23", 4) // 23
            ];

            foreach (b; allocators) {
                blockfile.save(generate_block(blockfile, b));
            }

            blockfile.store;

            blockfile.close;

        }

        { // Check that all block are written
            auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);

            blockfile.inspect(&failsafe);

            blockfile.close;
        }

        {
            auto blockfile = new BlockFile(fileId.fullpath, SMALL_BLOCK_SIZE);
            immutable uint[uint] size_stats = [
                6: 2, 2: 4, 3: 9, 10: 2, 5: 5, 4: 1, 9: 1
            ]; //[5:6, 4:1, 3:10, 2:4, 10:2, 9:1];
            foreach (size, count; blockfile.statistic.histogram) {
                assert(size in size_stats);
                assert(count is size_stats[size]);
            }

            immutable result = blockfile.statistic.result;
            assert(rint(result.mean * 1_00000) == 4_37500);
            assert(rint(result.sigma * 1_00000) == 2_39224);
            assert(result.N == 24);
            blockfile.close;
        }
    }
}
