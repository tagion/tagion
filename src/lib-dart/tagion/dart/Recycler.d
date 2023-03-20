module tagion.dart.Recycler;

import std.typecons : Typedef;
import std.container.rbtree : RedBlackTree;

import tagion.basic.Types : Buffer;
import tagion.hibon.Document;
import tagion.dart.BlockFile : BlockFile;

import tagion.dart.BlockSegment : Index, NullIndex;


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
    import tagion.dart.BlockFile;
    import tagion.basic.Types : FileExtension;
    import std.range : iota;
    import std.algorithm.iteration : map;

    enum SMALL_BLOCK_SIZE = 0x40;
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

