module tagion.dart.Recycler;

import std.typecons : Typedef;
import std.container.rbtree : RedBlackTree;

import std.stdio;

import tagion.hibon.Document;
import tagion.dart.BlockFile : BlockFile;

import LEB128 = tagion.utils.LEB128;

/// BlockFile file position index
alias Index = Typedef!(ulong, ulong.init, "BINDEX");

enum NullIndex = Index.init;

@safe
struct Segment {
    Index index; // Block file index
    uint size;
    invariant {
        assert(size > 0);
    }

    Index end() const pure nothrow @nogc {
        return Index(index + size);
    }
}

@safe
struct Recycler {
    alias Indices = RedBlackTree!(const(Segment)*, (a, b) => a.index < b.index);
    alias Segments = RedBlackTree!(const(Segment)*, (a, b) => a.size < b.size, true);
    protected {
        BlockFile owner;
        Indices indices;
        Segments segments;
    }
    @disable this();
    this(BlockFile owner) pure nothrow
    in (owner !is null)
    do {
        this.owner = owner;
        indices = new Indices;
        segments = new Segments;
    }

    protected void insert(const(Segment)* segment) pure {
        indices.insert(segment);
        segments.insert(segment);
    }

    void recycle(const(Segment)* segment) {
        if (indices.empty) {
            insert(segment);
            return;
        }
        auto previous_range = indices.lowerBound(segment);
        if (previous_range.empty) {
            insert(segment);
            return;
        }

    }

    invariant {
        assert(noOverlaps, "Recycle segments has overlaps");
    }

    /**
    Returns: true if the segments overlaps
*/
    private bool noOverlaps() const pure nothrow @nogc {
        import std.range : slide;
        import std.algorithm.searching : any;
        import std.algorithm.iteration : map;

        if (indices.length <= 1) {
            return true;
        }
        /// Check a pair of segments overlaps
        static bool overlaps(R)(ref R pair) pure nothrow @nogc {
            const prev_end = pair.front.end;
            pair.popFront;
            const current_index = pair.front.index;
            return prev_end > current_index;
        }

        return !indices[]
            .slide(2)
            .map!(slice => overlaps(slice))
            .any;
    }
}

version (unittest) {
    enum SMALL_BLOCK_SIZE = 0x40;
    import Basic = tagion.basic.Basic;
    import tagion.basic.Types : FileExtension;

    const(Basic.FileNames) fileId(T = BlockFile)(string prefix = null) @safe {
        return Basic.fileId!T(FileExtension.block, prefix);
    }
}

@safe
unittest {
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

}

@safe
struct BlockSegment {
    ulong previous; /// Previous block index
    ulong next; /// Next block index
    Document doc;
    //    Buffer data;   
    //ulong size; /// size in bytes
    //uint number_of_blocks; /// Number of blocks
    invariant {
        assert(previous < next);
    }

    ulong totalSize() const pure nothrow @nogc {
        return LEB128.calc_size(previous) + LEB128.calc_size(next) + doc.full_size;
    }

    uint blocks(const uint block_size) const pure nothrow @nogc {
        const total_size = totalSize;
        return total_size / block_size + (total_size % block_size == 0) ? 0 : 1;
    }

    void write(ref File file) const {
        file.write(LEB128.encode(previous));
        file.write(LEB128.encode(next));
        file.write(doc.serialize);
    }

    this(ref File file) {
        enum MIN_SIZE = 3 * (ulong.sizeof + 3); // 3 time leb128 ulong
        ubyte[MIN_SIZE] _pre_buf;
        ubyte[] pre_buf = _pre_buf;
        //file.rawRead(buf);
        /+
{ // previous
        const dec_leb = decode!ulong(pre_buf);
        previous=dec_leb.value;
        dec_leb = decode!ulong(pre_buf);
        pre_buf
        pre_buf
        next=dec_leb.value;
        dec_leb = decode!ulong(pre_buf);
        doc_size=dec_leb.value;

        +/

    }
}
