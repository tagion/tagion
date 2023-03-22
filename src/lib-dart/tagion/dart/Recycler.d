module tagion.dart.Recycler;

import std.container.rbtree : RedBlackTree;
import std.range;
import std.typecons : tuple;
import std.stdio;
import std.traits : PointerTarget;

import tagion.basic.Types : Buffer;
import tagion.dart.BlockFile : BlockFile, Index;
import tagion.hibon.HiBONRecord : HiBONRecord, label, recordType;
import std.algorithm;

enum Type : int {
    NONE = 0, /// NO Recycler instruction
    REMOVE = -1, /// Should be removed from recycler
    ADD = 1, /// should be added to recycler
}

@safe @recordType("RecycleSegment")
struct Segment {
    Index index; // Block file index
    uint size;
    @label("") Type type;

    Index end() const pure nothrow @nogc {
        return Index(index + size);
    }

    mixin HiBONRecord!(q{
        this(const Index index, const uint size, const Type type=Type.NONE) {
            this.index = index;
            this.size = size;
            this.type = type;
        }
    });
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

    protected void insert(Segment* segment) {
        indices.insert(segment);
        segments.insert(segment);
    }

    protected void remove(Segment* segment) {
        indices.removeKey(segment);
        segments.removeKey(segment);
    }

    void recycle(R)(R recycle_segments)
        if (isInputRange!R && is(ElementType!R == Segment*)) {

        if (indices.empty) {
            insert(recycle_segments);
            return;
        }
        
        writefln("came to here ");

        Indices new_segments = new Indices(recycle_segments);
        
        foreach(segment; new_segments[]) {
            auto lower_range = indices.lowerBound(segment);
            auto upper_range = indices.upperBound(segment);


            if (segment.type == Type.REMOVE) {
                auto equal_range = indices.equalRange(segment);
                assert(!equal_range.empty, "Cannot call remove with segment where index in recycler does not exist");

                if (equal_range.front.index == segment.index) {
                    Segment* add_segment = new Segment(Index(equal_range.front.index + segment.size), equal_range
                            .front.size - segment.size);
                    remove(equal_range.front);
                    insert(add_segment);
                }
            }
            else if (segment.type == Type.ADD) {
                if (lower_range.front.end == segment.index) {
                    //  ###
                    //  ###A 
                    if (upper_range.front.index == segment.end) {
                        // ### ###
                        // ###A###
                        Segment* add_segment = new Segment(lower_range.front.index, lower_range.front.size + segment
                                .size + upper_range.front.size);
                        remove(lower_range.front);
                        remove(upper_range.front);
                        insert(add_segment);
                    }
                    else {
                        // ### 
                        // ###A
                        Segment* add_segment = new Segment(lower_range.front.index, lower_range.front.size + segment
                                .size);
                        remove(lower_range.front);
                        insert(add_segment);
                    }

                }
                else if (upper_range.front.index == segment.end) {
                    //  ###
                    // A###
                    Segment* add_segment = new Segment(segment.index, upper_range.front.size + segment
                            .size);
                    remove(upper_range.front);
                    insert(add_segment);
                }
                else {
                    // ###        ###
                    // ###    A   ###
                    insert(segment);
                }
            }
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

unittest {
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    Segment*[] add_segments = [
        new Segment(Index(1UL), 5, Type.ADD),
        new Segment(Index(10UL), 5, Type.ADD),
        new Segment(Index(17UL), 5, Type.ADD),
    ];

    recycler.recycle(add_segments);
    recycler.dump();

    writefln("####");
    Segment*[] remove_segments = [
        new Segment(Index(1UL), 2, Type.REMOVE),
    ];

   
    recycler.recycle(remove_segments);

    recycler.dump();
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
