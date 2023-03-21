module tagion.dart.Recycler;

import std.container.rbtree : RedBlackTree;

import tagion.basic.Types : Buffer;
import tagion.dart.BlockFile : BlockFile;

import tagion.dart.BlockSegment : Index, NullIndex;
import std.range;
import std.typecons : tuple;
import std.stdio;
import std.traits : PointerTarget;

@safe
struct Segment {
    Index index; // Block file index
    uint size;
    bool joined;

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

    protected void insert(R)(R insert_segments)
        if (isInputRange!R && is(ElementType!R == Segment*)) {
        indices.insert(insert_segments);
        segments.insert(insert_segments);
    }

    /** 
     * Takes a segment that is being used and should be added to the recycler.
     * Params:
     *   segment = Segment that has been removed.
     */
    void recycle(R)(R recycle_segments)
        if (isInputRange!R && is(ElementType!R == Segment*)) {
        
        insert(recycle_segments);

        Segment*[] segments_to_add;
        pragma(msg, "RBRange ", indices.Range);   
        pragma(msg, "RBRange.Node ", indices.Range.Node);   
        pragma(msg, "RBRange.Elem ", indices.Range.Elem);   
    ///alias NullSegmentT=PointerTarget!(typeof(indices[].front));
            ///PointerTarget
//pragma(msg, "Null : ", NullSegmentT);
            //auto _s = new Segment;
            //auto s = new Indices.Range(_s, _s);
            //auto newly_added = indices[].sequence!((a, n) => tuple(a[n-1], a[1], a[2]))(s, s);
                    
            //auto newly_added = indices[].recurrence!(q{tuple(a[n], a[n-1], a[n-2])})(s,s);

            foreach(seg; indices[]) {
            writefln("test %s", *seg);

            } 
version(none)
            foreach(test; newly_added.take(5)) {
                writefln("test %s", test[0]);
                writefln("test %s", typeof(test[0]).stringof);
//                writefln("test %s", test[0].front);
                writefln("test[1] %s", typeof(test[1]).stringof);
                writefln("test[2] %s", typeof(test[2]).stringof);
                writef("%s ", *test[0]);
                writef("%s ", *test[1]);
                writef("%s ", *test[2]);
        writeln;
            }

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

        foreach (segment; indices) {
            writefln("INDEX: %s", segment.index);
            writefln("END: %s", segment.end);
        }
    }

    bool isRecyclable(const Index index) const pure nothrow {
        return false;
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

@safe
unittest {
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);
    
    Segment*[] segments = [
    new Segment(Index(1UL), 5), 
    new Segment(Index(10UL), 5),
    new Segment(Index(17UL), 5),
    ];

    recycler.recycle(segments);

    
}


// unittest {
//     immutable filename = fileId("recycle").fullpath;
//     BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
//     auto blockfile = BlockFile(filename);
//     scope (exit) {
//         blockfile.close;
//     }
//     auto recycler = Recycler(blockfile);

//     // insert one segment.
//     auto segment = new Segment(Index(32UL), 128);
//     recycler.recycle(segment);

//     auto after_segment = new Segment(segment.end, 128);

//     assert(recycler.previousIndex(after_segment) == segment.index);
//     assert(recycler.nextIndex(after_segment) == NullIndex);

//     auto before_segment = new Segment(Index(1), 122);
//     assert(recycler.previousIndex(before_segment) == NullIndex);
//     assert(recycler.nextIndex(before_segment) == segment.index);

//     auto inside_segment = new Segment(Index(35UL), 122);
//     recycler.dump();

// }

// unittest {
//     // checks for single overlap.
//     immutable filename = fileId("recycle").fullpath;
//     BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
//     auto blockfile = BlockFile(filename);
//     scope (exit) {
//         blockfile.close;
//     }
//     auto recycler = Recycler(blockfile);

//     // insert one segment.
//     auto segment = new Segment(Index(1UL), 128);
//     recycler.recycle(segment);
//     // insert another segment just after previous.
//     auto just_after_segment = new Segment(segment.end, 128);
//     recycler.insert(just_after_segment);

//     assert(recycler.indices.length == 2);

//     // try to insert a segment overlapping just_after_segment.
//     auto non_valid_segment = new Segment(Index(just_after_segment.end-1), 128);

//     // assertThrown!Throwable(recycler.insert(non_valid_segment));

//     // recycler.insert(non_valid_segment);
//     // recycler.dump();
// }

// unittest {
//     // checks for double overlap.
//     immutable filename = fileId("recycle").fullpath;
//     BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
//     auto blockfile = BlockFile(filename);
//     scope (exit) {
//         blockfile.close;
//     }
//     auto recycler = Recycler(blockfile);

//     // insert one segment.
//     auto segment = new Segment(Index(1UL), 128);
//     recycler.recycle(segment);
//     // insert another segment just after previous.
//     auto just_after_segment = new Segment(segment.end, 128);
//     recycler.insert(just_after_segment);

//     assert(recycler.indices.length == 2);

//     // try to insert a segment overlapping just_after_segment.
//     auto non_valid_segment = new Segment(Index(64), 128);

//     // assertThrown!AssertError(recycler.insert(non_valid_segment));

//     // recycler.dump();
// }

// unittest {
//     // checks that lengths of segments and indices is always the same.
//     import std.exception;
//     import core.exception : AssertError;
//     import std.range;

//     immutable filename = fileId("recycle").fullpath;
//     BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
//     auto blockfile = BlockFile(filename);
//     scope (exit) {
//         blockfile.close;
//     }
//     auto recycler = Recycler(blockfile);

//     // insert one segment.
//     auto segment = new Segment(Index(1UL), 128);
//     recycler.recycle(segment);
//     // insert another segment just after previous.
//     auto just_after_segment = new Segment(segment.end, 128);
//     recycler.insert(just_after_segment);

//     assert(recycler.indices.length == 2);

//     // assertThrown!AssertError(recycler.indices.removeFront());

//     // recycler.dump();    
// }

// unittest {
//     // check that archive cannot be inserted at index=0.

//     // assertThrown!AssertError(new Segment(Index(0), 128));
// }

// unittest {
//     // recycler with only one segment in beginning. Insert segment after and see that the segments are put together.
//     immutable filename = fileId("recycle").fullpath;
//     BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
//     auto blockfile = BlockFile(filename);
//     scope (exit) {
//         blockfile.close;
//     }
//     auto recycler = Recycler(blockfile);

//     // insert one segment.
//     auto segment = new Segment(Index(1UL), 128);
//     recycler.recycle(segment);

//     assert(recycler.indices.length == 1);

//     auto just_after_segment = new Segment(segment.end, 128);
//     // assert(recycler.indices.length == 1, "The segments should be merged");

// }

// auto lower_range = indices.lowerBound(segment);
// auto upper_range = indices.upperBound(segment);
// Segment lower_elem;
// Segment upper_elem;

// if (!lower_range.empty) {
//     lower_elem = lower_range.back;
// } else {
//     lower_elem = Segment.init;
// }

// if (!upper_range.empty) {
//     upper_elem = upper_range.front;
// } else {
//     upper_elem = Segment.init;
// }

// if (lower_elem.end == segment.index) {
//     if (upper_elem.index == segment.end) {
//         remove(&upper_elem);
//         remove(&lower_elem);
//         Segment middle_segment = new Segment(lower_elem.index, lower_elem.size + segment.size + upper_elem.size);
//         insert(middle_segment);
//         return;
//     }
//     remove(&lower_elem);
//     Segment connect_right_segment = new Segment(lower_elem.index, lower_elem.size + segment.size);
//     insert(connect_right_segment);
//     return;
// }
// if (upper_elem.index == segment.end) {
//     remove(&upper_elem);
//     Segment connect_left_segment = new Segment(segment.index, segment.size + upper_elem.size);
//     insert(connect_left_segment);
//     return;
// }
