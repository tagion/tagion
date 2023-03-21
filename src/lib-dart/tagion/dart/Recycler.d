module tagion.dart.Recycler;

import std.container.rbtree : RedBlackTree;

import tagion.basic.Types : Buffer;
import tagion.dart.BlockFile : BlockFile;

import tagion.dart.BlockSegment : Index, NullIndex;

import std.stdio;

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

    invariant {
        assert(index != Index(0), "Segment cannot be inserted at index 0");
    }
}

@safe
struct Recycler {
    // Indices: sorted by index
    alias Indices = RedBlackTree!(Segment*, (a, b) => a.index < b.index);
    // Segment: sorted by size.
    alias Segments = RedBlackTree!(Segment*, (a, b) => a.size < b.size, true);

    /** 
     * Checks if the recycler has overlapping segments.
     */
    invariant {
        assert(noOverlaps, "Recycle segments has overlaps");
    }
    /** 
     * Checks if the indicies and segments are the same length;
     */
    invariant {
        assert(indices.length == segments.length);
    }

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
    /** 
     * Inserts the segment pointer into the RedBlackTree. 
     * Params:
     *   segment = Pointer to the segment.
     */
    protected void insert(Segment* segment) pure {
        indices.insert(segment);
        segments.insert(segment);
    }
    /** 
     * Takes a segment that is being used and should be added to the recycler.
     * Params:
     *   segment = Segment that has been removed.
     */
    void recycle(Segment* segment) {
        // if the recycler is empty we add the segment as is.
        if (indices.empty) {
            insert(segment);
            return;
        }

        // this part is not working but needs redoing anyway
        auto previous_range = indices.lowerBound(segment);
        if (previous_range.empty) {
            insert(segment);
            return;
        }

    }

    /** 
    * Gets the previous index
    * Params:
    *   segment = segment to check the previous segment from this.
    * Returns: The previous segment
    */
    Index previousIndex(Segment* segment) pure @safe const {  
        auto lower_range = indices.lowerBound(segment);
        if (lower_range.empty) {
            return NullIndex;
        }
        return lower_range.back.index;
    }
    /** 
     * Gets the next index
     * Params:
     *   segment = segment to check the next segment from this.
     * Returns: Next index
     */
    Index nextIndex(Segment* segment) pure @safe const {
        auto upper_range = indices.upperBound(segment);
        if (upper_range.empty) {
            return NullIndex;
        }
        return upper_range.front.index;
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
    /** 
     * Dumps the segments in the recycler.
     */
    void dump() {
        import std.stdio;
        foreach(segment; indices) {
            writefln("INDEX: %s", segment.index);
            writefln("END: %s", segment.end);
        }
    }

}

version (unittest) {
    import tagion.dart.BlockFile;
    import tagion.basic.Types : FileExtension;
    import std.range : iota;
    import std.algorithm.iteration : map;

    enum SMALL_BLOCK_SIZE = 0x40;
}

import std.exception;


unittest {
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    // insert one segment.
    auto segment = new Segment(Index(32UL), 128);
    recycler.recycle(segment);

    auto after_segment = new Segment(segment.end, 128);

    assert(recycler.previousIndex(after_segment) == segment.index);
    assert(recycler.nextIndex(after_segment) == NullIndex);

    auto before_segment = new Segment(Index(1), 122);
    assert(recycler.previousIndex(before_segment) == NullIndex);
    assert(recycler.nextIndex(before_segment) == segment.index);

}

unittest {
    // checks for single overlap.
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    // insert one segment.
    auto segment = new Segment(Index(1UL), 128);
    recycler.recycle(segment);
    // insert another segment just after previous.
    auto just_after_segment = new Segment(segment.end, 128);
    recycler.insert(just_after_segment);

    assert(recycler.indices.length == 2);

    // try to insert a segment overlapping just_after_segment.
    auto non_valid_segment = new Segment(Index(just_after_segment.end-1), 128);
    
    // assertThrown!Throwable(recycler.insert(non_valid_segment));

    // recycler.insert(non_valid_segment);
    recycler.dump();
}

unittest {
    // checks for double overlap.
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    // insert one segment.
    auto segment = new Segment(Index(1UL), 128);
    recycler.recycle(segment);
    // insert another segment just after previous.
    auto just_after_segment = new Segment(segment.end, 128);
    recycler.insert(just_after_segment);

    assert(recycler.indices.length == 2);

    // try to insert a segment overlapping just_after_segment.
    auto non_valid_segment = new Segment(Index(64), 128);
    
    // assertThrown!AssertError(recycler.insert(non_valid_segment));

    recycler.dump();
}

unittest {
    // checks that lengths of segments and indices is always the same.
    import std.exception;
    import core.exception : AssertError;
    import std.range;

    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    // insert one segment.
    auto segment = new Segment(Index(1UL), 128);
    recycler.recycle(segment);
    // insert another segment just after previous.
    auto just_after_segment = new Segment(segment.end, 128);
    recycler.insert(just_after_segment);

    assert(recycler.indices.length == 2);

    // assertThrown!AssertError(recycler.indices.removeFront());

    recycler.dump();    
}

unittest {
    // check that archive cannot be inserted at index=0.

    // assertThrown!AssertError(new Segment(Index(0), 128));
}

unittest {
    // recycler with only one segment in beginning. Insert segment after and see that the segments are put together.
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    // insert one segment.
    auto segment = new Segment(Index(1UL), 128);
    recycler.recycle(segment);

    assert(recycler.indices.length == 1);

    auto just_after_segment = new Segment(segment.end, 128);
    // assert(recycler.indices.length == 1, "The segments should be merged");
  
}