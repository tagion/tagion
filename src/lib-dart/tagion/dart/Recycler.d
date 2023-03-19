module tagion.dart.Recycler;

import std.typecons : Typedef;
import std.container.rbtree : RedBlackTree;

import std.stdio;

import tagion.basic.Types : Buffer;
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
    ulong previous; /** Block index of the previous block-segment
                    * If this is 0 then this is the first segment    
                    */
    ulong next; /** Block index of the next block 
                 * If this is 0 then this is the last segment
                 */
    Document doc; /// Document stored in the segment
    invariant {
        assert(((previous == 0 ) && (next == 0)) || (previous < next));
    }

    ulong totalSize() const pure nothrow @nogc {
        return LEB128.calc_size(previous) + LEB128.calc_size(next) + doc.full_size;
    }

    version(none)
    uint blocks(const uint block_size) const pure nothrow @nogc {
        const total_size = totalSize;
        return total_size / block_size + (total_size % block_size == 0) ? 0 : 1;
    }

    void write(ref File file) const {  
        file.rawWrite(LEB128.encode(previous));
        file.rawWrite(LEB128.encode(next));
        file.rawWrite(doc.serialize);
    }

    @disable this();
    this(const Document doc, const ulong previous, const ulong next) {
        this.previous = previous;
        this.next = next;
        this.doc = doc;
    }

    this(ref File file) {
        enum MIN_SIZE = 3 * (ulong.sizeof + 3); // 3 time leb128 ulong
        ubyte[MIN_SIZE] _pre_buf;
        ubyte[] pre_buf = _pre_buf;
        const segment_start = file.tell;
        file.rawRead(pre_buf);

        previous = LEB128.read!ulong(pre_buf).value;
        next = LEB128.read!ulong(pre_buf).value;
        // Set the file position indicator to where start of doc
        file.seek(segment_start + MIN_SIZE - pre_buf.length);

        Buffer readDoc() @trusted {
            import std.exception : assumeUnique;

            const doc_size = LEB128.read!size_t(pre_buf);
            auto doc_data = new ubyte[doc_size.size + doc_size.value];
            file.rawRead(doc_data);
            return assumeUnique(doc_data);
        }

        doc = readDoc;
    }

}
