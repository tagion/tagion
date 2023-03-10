module tagion.dart.Recycler;

import std.typecons : Typedef;

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
        return index + size;
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
        recycle_segments = new Segments;
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
        segments.insert(segement);
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

    bool isValid() {
        return segment_overlap = indeces[]
            .recurrence!q{a[n-1].end < a[n].index}
            .all;

    }
}

version (unittest) {
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
