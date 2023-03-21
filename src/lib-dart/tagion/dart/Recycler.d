module tagion.dart.Recycler;

import std.container.rbtree : RedBlackTree;

import tagion.basic.Types : Buffer;
import tagion.dart.BlockFile : BlockFile;

import tagion.dart.BlockSegment : Index, NullIndex;
import std.range;
import std.typecons : tuple;
import std.stdio;
import std.traits : PointerTarget;


enum Type : int {
    NONE = 0, /// NO Recycler instruction
    REMOVE = -1, /// Should be removed from recycler
    ADD = 1, /// should be added to recycler
}
@safe
struct Segment {


    Index index; // Block file index
    uint size;
    Type type;

    Index end() const pure nothrow @nogc {
        return Index(index + size);
    }

    invariant {
        assert(size > 0);
    }
    invariant {
        assert(index != Index(0), "Segment cannot be inserted at index 0");
    }
}

@safe
struct Recycler {
    // Indices: sorted by index
    alias Indices = RedBlackTree!(Segment*, (a, b) => a.index < b.index || ((a.index == b.index) && (a.size > b.size)), true);
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


    void recycle(R)(R recycle_segments)
        if (isInputRange!R && is(ElementType!R == Segment*)) {
        
        insert(recycle_segments);

        // Segment*[] new_segments;
        // auto rs = indices[];
        // Segment* segment_ADD = null;

        // while (!rs.empty) {
        //     if (rs.current.type == Type.REMOVE && rs.previous.index == rs.current.index) {
        //         new_segments ~= new Segment(Index(rs.current.index+rs.current.size), rs.previous.size - rs.current.size);
        //         rs.previous.type = Type.REMOVE;
        //     }
        //     // else if (rs.current.type == Type.ADD) {
        //     //     if (segment_ADD !is null) {
        //     //         if (segment_ADD.end == )
        //     //     }                

        //     // }


        //     rs.popFront;
        // }


    }
    struct RecyclerRange {
        Segment* previous;
        Segment* current;

        Indices.Range indices_range;
        
        this(Indices indices)
        in (indices.length > 2) 
        do {
            this.indices_range = indices[];
            popFront();
            popFront();
        }

        void popFront() {
            previous = current;
            current = indices_range.front;
            indices_range.popFront;
        }

        Segment* front() {
            return indices_range.front;
        }

        bool empty() {
            return indices_range.empty;
        }

        RecyclerRange save() {
            return this;
        }

    }

    RecyclerRange opSlice() {
        return RecyclerRange(indices);
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

