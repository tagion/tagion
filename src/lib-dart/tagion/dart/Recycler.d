module tagion.dart.Recycler;

import std.typecons : Typedef;
import std.container.rbtree : RedBlackTree;

import std.stdio;

import tagion.dart.BlockFile : BlockFile;

/// BlockFile file position index
alias BlockIndex = Typedef!(ulong, ulong.init, "BINDEX");

enum NullIndex = BlockIndex.init;

@safe
struct Segment {
    BlockIndex index; // Block file index
    uint size;
    invariant {
        assert(size > 0);
    }

    BlockIndex end() const pure nothrow @nogc {
        return BlockIndex(index + size);
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

    version (none) BlockIndex next(const BlockIndex index) const pure {
        auto next_range = indices.lowerBound(index);
        if (next_range.empty) {
            return NullIndex;
        }
        return next_range.front;
    }

    version (none) BlockIndex previous(const BlockIndex index) const pure {
        auto previous_range = indices.upperBound(index);
        if (previous_range.empty) {
            return NullIndex;
        }
        return previous_range.back;
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
version(none)
        if (indices.length <= 1) {
            return false;
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

import std.traits;
import std.range;

Recurrence!(fun, CommonType!(State), State.length)
_recurrence(alias fun, State...)(State initial) {
    pragma(msg, "State ", State);
    pragma(msg, "CommonType!State ", CommonType!State);
    CommonType!(State)[State.length] state;
    foreach (i, Unused; State) {
        state[i] = initial[i];
    }
    return typeof(return)(state);
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
