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
    CLAIM = -1, /// Should be removed from recycler
    DISPOSE = 1, /// should be added to recycler
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
// Indices: sorted by index
alias Indices = RedBlackTree!(Segment*, (a, b) => a.index < b.index);
// Segment: sorted by size.
alias Segments = RedBlackTree!(Segment*, (a, b) => a.size < b.size, true);
@safe
struct Recycler {

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

    protected void claim(Segment* segment) {
        indices.removeKey(segment);
        segments.removeKey(segment);
    }

    void recycle(R)(R recycle_segments)
        if (isInputRange!R && is(ElementType!R == Segment*)) {

        if (indices.empty) {
            insert(recycle_segments);
            return;
        }
        Indices new_segments = new Indices(recycle_segments);

        foreach (segment; new_segments[]) {
            if (segment.type == Type.CLAIM) {
                auto equal_range = indices.equalRange(segment);
                assert(!equal_range.empty, "Cannot call remove with segment where index in recycler does not exist");
                Segment* add_segment = new Segment(Index(equal_range.front.index + segment.size), equal_range
                        .front.size - segment.size);
                claim(equal_range.front);
                insert(add_segment);
                continue;
            }

            if (segment.type == Type.DISPOSE) {
                auto lower_range = indices.lowerBound(segment);
                auto upper_range = indices.upperBound(segment);

                if (lower_range.empty) {
                    // A ###
                    assert(!upper_range.empty, "there must be something in the upper range if the lower range is empty.");
                    if (segment.end == upper_range.front.index) {
                        Segment* add_segment = new Segment(segment.index, upper_range.front.size + segment
                                .size);
                        claim(upper_range.front);
                        insert(add_segment);
                        continue;
                    }
                    else {
                        insert(segment);
                        continue;
                    }
                }
                if (upper_range.empty) {
                    // ### A empty forever
                    assert(!lower_range.empty, "there must be something in the lower range if the upper range is empty.");
                    if (lower_range.back.end == segment.index) {
                        Segment* add_segment = new Segment(lower_range.back.index, segment.size + lower_range
                                .back.size);
                        claim(lower_range.back);
                        insert(add_segment);
                        continue;
                    }
                    else {
                        insert(segment);
                        continue;
                    }
                }
                if (lower_range.back.end == segment.index) {
                    //  ###
                    //  ###A 
                    if (upper_range.front.index == segment.end) {
                        // ### ###
                        // ###A###
                        Segment* add_segment = new Segment(lower_range.front.index, lower_range.front.size + segment
                                .size + upper_range.front.size);
                        claim(lower_range.front);
                        claim(upper_range.front);
                        insert(add_segment);
                        continue;
                    }
                    else {
                        // ### 
                        // ###A
                        Segment* add_segment = new Segment(lower_range.front.index, lower_range.front.size + segment
                                .size);
                        claim(lower_range.front);
                        insert(add_segment);
                        continue;
                    }

                }
                if (upper_range.front.index == segment.end) {
                    //  ###
                    // A###
                    Segment* add_segment = new Segment(segment.index, upper_range.front.size + segment
                            .size);
                    claim(upper_range.front);
                    insert(add_segment);
                    continue;
                }
                else {
                    // ###        ###
                    // ###    A   ###
                    insert(segment);
                    continue;
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

    void read(const Index index) {
        /// Reads the recycler at index
    }

    void write(const Index index) const nothrow {
        /// The recycler to the blockfile
    }

    void reclaim(const Index index, const uint size) {
        /// Should implemented    
    }

    /**
     * 
     * Params:
     *   size = in number of blocks
     * Returns: 
     *   Index pointer a free segment
     */
    const(Index) reserve_segment(const uint size) nothrow {
        scope (success) {
            owner._last_block_index += size;
        }
        return owner._last_block_index;
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
    // remove test
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.DISPOSE),
        new Segment(Index(10UL), 5, Type.DISPOSE),
        new Segment(Index(17UL), 5, Type.DISPOSE),
    ];

    recycler.recycle(dispose_segments);
    // recycler.dump();

    // writefln("####");
    Segment*[] claim_segments = [
        new Segment(Index(1UL), 2, Type.CLAIM),
    ];
    recycler.recycle(claim_segments);

    assert(recycler.indices.front.index == Index(3UL));
    assert(recycler.indices.front.end == 6);
    // recycler.dump();
}

@safe
unittest {
    // add extra test
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.DISPOSE),
        new Segment(Index(10UL), 5, Type.DISPOSE),
        new Segment(Index(17UL), 5, Type.DISPOSE),
    ];

    recycler.recycle(dispose_segments);
    // recycler.dump();

    writefln("####");
    Segment*[] extra_segments = [
        new Segment(Index(6UL), 2, Type.DISPOSE),
        new Segment(Index(25UL), 6, Type.DISPOSE),
        new Segment(Index(22UL), 3, Type.DISPOSE),
    ];
    recycler.recycle(extra_segments);
    // recycler.dump();

    Segment*[] expected_segments = [
        new Segment(Index(1UL), 8, Type.NONE),
        new Segment(Index(10UL), 5, Type.NONE),
        new Segment(Index(17UL), 31 - 17, Type.NONE),
    ];
    Indices expected_indices = new Indices(expected_segments);

    assert(expected_indices.length == recycler.indices.length, "Got other indices than expected");
    (() @trusted {
        assert(expected_indices.opEquals(recycler.indices), "elements should be the same");
    }());
}

@safe
unittest {
    // middle add segment
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.DISPOSE),
        new Segment(Index(10UL), 5, Type.DISPOSE),
    ];

    recycler.recycle(dispose_segments);
    // recycler.dump();

    Segment*[] remove_segment = [
        new Segment(Index(6UL), 4, Type.DISPOSE),
    ];
    recycler.recycle(remove_segment);
    // recycler.dump();

    assert(recycler.indices.length == 1, "should only be one segment after middle insertion");
    assert(recycler.indices.front.index == Index(1UL) && recycler.indices.front.end == Index(15UL), "Middle insertion not valid");
}

unittest {
    // remove illegal element
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.DISPOSE),
        new Segment(Index(10UL), 5, Type.DISPOSE),
    ];

    recycler.recycle(dispose_segments);
    // recycler.dump;

    assertThrown!Throwable(recycler.recycle([
        new Segment(Index(20UL), 4, Type.CLAIM)
    ]));
    assertThrown!Throwable(recycler.recycle([
        new Segment(Index(3UL), 5, Type.CLAIM)
    ]));
    assertThrown!Throwable(recycler.recycle([
        new Segment(Index(6UL), 4, Type.CLAIM)
    ]));
}

unittest {
    // empty lowerrange connecting
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    recycler.recycle([new Segment(Index(10UL), 5, Type.DISPOSE)]);
    // recycler.dump;
    recycler.recycle([new Segment(Index(2UL), 8, Type.DISPOSE)]);

    assert(recycler.indices.length == 1, "should have merged segments");
    assert(recycler.indices.front.index == Index(2UL), "Index not correct");
    assert(recycler.indices.front.end == Index(15UL));

    // upperrange empty connecting
    recycler.recycle([new Segment(Index(15UL), 5, Type.DISPOSE)]);
    assert(recycler.indices.length == 1, "should have merged segments");
    assert(recycler.indices.front.index == Index(2UL));
    assert(recycler.indices.front.end == Index(20UL));
    // recycler.dump;    
}

unittest {
    // empty lowerrange NOT connecting
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    recycler.recycle([new Segment(Index(10UL), 5, Type.DISPOSE)]);
    // recycler.dump;
    recycler.recycle([new Segment(Index(2UL), 5, Type.DISPOSE)]);

    assert(recycler.indices.length == 2, "should NOT have merged types");
    assert(recycler.indices.front.index == Index(2UL), "Index not correct");
    // recycler.dump

    // upper range NOT connecting
    recycler.recycle([new Segment(Index(25UL), 5, Type.DISPOSE)]);
    assert(recycler.indices.length == 3, "Should not have merged");
    assert(recycler.indices.back.index == Index(25UL), "Should not have merged");

}

unittest {
    // NOT empty upperrange and lowerrange connecting
    // empty lowerrange connecting
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    recycler.recycle([
        new Segment(Index(10UL), 5, Type.DISPOSE), new Segment(Index(1UL), 1)
    ]);
    // recycler.dump;
    recycler.recycle([new Segment(Index(5UL), 5, Type.DISPOSE)]);
    // recycler.dump;
    assert(recycler.indices.length == 2, "should have merged segments");

    // upperrange not empty connecting
    recycler.recycle([new Segment(Index(25UL), 5, Type.DISPOSE)]);
    recycler.recycle([new Segment(Index(17UL), 2, Type.DISPOSE)]);
    assert(recycler.indices.length == 4);
}
