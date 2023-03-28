module tagion.dart.Recycler;

import std.container.rbtree : RedBlackTree;
import std.range;
import std.typecons : tuple;
import std.stdio;
import std.traits : PointerTarget;

import tagion.basic.Types : Buffer;
import tagion.dart.BlockFile : BlockFile, Index;
import tagion.hibon.HiBONRecord : HiBONRecord, label, recordType, fwrite;
import std.algorithm;

enum Type : int {
    NONE = 0, /// NO Recycler instruction
    REMOVE = -1, /// Should be removed from recycler
    ADD = 1, /// should be added to recycler
    UPDATE = 2,
}

@safe @recordType("RecycleSegment")
struct Segment {
    Index index; // Block file index
    uint size;
    Index next = Index.init;
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
alias Indices = RedBlackTree!(Segment*, (a, b) => a.index < b.index); // Segment: sorted by size.
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
        Indices to_be_recycled;
    }
    @disable this();
    this(BlockFile owner) pure nothrow
    in (owner !is null)

    do {
        this.owner = owner;
        indices = new Indices;
        segments = new Segments;
        to_be_recycled = new Indices;
    }

    protected void insert(Indices.Range segment_range) {
        indices.stableInsert(segment_range);
        segments.stableInsert(segment_range);
    }

    protected void insert(Segment* segment) {
        indices.insert(segment);
        segments.insert(segment);
    }

    protected void remove(Segment* segment) {
        indices.removeKey(segment);
        segments.removeKey(segment);
    }

    void recycle(Indices.Range recycle_segments) {

        if (indices.empty) {
            assert(recycle_segments.filter!(s => s.type != Type.ADD)
                    .take(2)
                    .walkLength == 0, "cannot remove segments from empty indices");
            insert(recycle_segments);
            return;
        }
        assert(recycle_segments.filter!(s => s.type == Type.NONE)
                .take(2)
                .walkLength == 0, "cannot insert type.NONE element");

        foreach (segment; recycle_segments) {
            if (segment.type == Type.REMOVE) {
                auto equal_range = indices.equalRange(segment);
                assert(!equal_range.empty, "Cannot call remove with segment where index in recycler does not exist");

                if (equal_range.front.size == segment.size) {
                    remove(equal_range.front);
                    continue;
                }

                Segment* add_segment = new Segment(
                    Index(equal_range.front.index + segment.size), equal_range
                        .front.size - segment.size);

                remove(equal_range.front);
                insert(add_segment);
                continue;
            }

            if (segment.type == Type.ADD) {
                auto lower_range = indices.lowerBound(segment);
                auto upper_range = indices.upperBound(segment);

                if (
                    lower_range.empty) {
                    // A ###
                    assert(!upper_range.empty, "there must be something in the upper range if the lower range is empty.");
                    if (segment.end == upper_range.front.index) {
                        Segment* add_segment = new Segment(segment.index, upper_range.front.size + segment
                                .size);
                        remove(upper_range.front);
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
                    if (lower_range.back.end == segment
                        .index) {
                        Segment* add_segment = new Segment(
                            lower_range.back.index, segment.size + lower_range.back.size);
                        remove(lower_range.back);
                        insert(add_segment);
                        continue;
                    }
                    else {
                        insert(segment);
                        continue;
                    }
                }
                if (
                    lower_range.back.end == segment.index) {
                    //  ###
                    //  ###A 
                    if (upper_range.front.index == segment.end) {
                        // ### ###
                        // ###A###
                        Segment* add_segment = new Segment(
                            lower_range.front.index, lower_range.front.size + segment.size + upper_range
                                .front.size);
                        remove(lower_range.front);
                        remove(upper_range.front);
                        insert(add_segment);
                        continue;
                    }
                    else {
                        // ### 
                        // ###A
                        Segment* add_segment = new Segment(lower_range.front.index, lower_range.front.size + segment
                                .size);
                        remove(lower_range.front);
                        insert(add_segment);
                        continue;
                    }

                }
                if (upper_range.front.index == segment.end) {
                    //  ###
                    // A###
                    Segment* add_segment = new Segment(segment.index, upper_range.front.size + segment
                            .size);
                    remove(upper_range.front);
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
            const current_index = pair.front
                .index;
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
            writefln("INDEX: %s", segment
                    .index);
            writefln("END: %s", segment
                    .end);
            writefln("NEXT: %s", segment.next);
        }
    }

    bool isRecyclable(const Index index) const pure nothrow {
        return false;
    }

    void read(const Index index) {
        /// Reads the recycler at index
    }

    /** 
     * Writes the data to the file. First it calls recycler with the to_be_recycled. Afterwards it goes through and updated the pointer chain.
     * Params:
     *   index = Index of the blockfile???
     */
    void write() nothrow {
        assumeWontThrow(recycle(to_be_recycled[]));
        to_be_recycled.clear;
        assumeWontThrow(writeln("###"));
        assumeWontThrow(dump());

        foreach (segment; indices) {
            auto upper_range = indices.upperBound(segment);

            if (!upper_range.empty) {
                if (segment.next != upper_range.front.index) {
                    segment.next = upper_range.front.index;
                }
            }
        }
        assumeWontThrow(writeln("@@@"));
    }

    /// The recycler to the blockfile

    /**
     * Claims a free segment. Priority is first to use segments already in the recycler. 
     * Therefore removing a segment from the recycler. 
     * Secondly if no available segments then it appends a new segment to the blockfile.
     * Params:
     *   segment_size = in number of blocks.
     * Returns: 
     *   Index pointer a free segment
     */
    const(Index) claim(
        const uint segment_size) nothrow {
        scope (success) {
            owner._last_block_index += segment_size;
        }

        // Either adds or removes from the recycler. 
        assumeWontThrow(to_be_recycled.insert(
                new Segment(owner._last_block_index, segment_size, Type.ADD)));
        return owner._last_block_index;

    }
    /** 
     * Disposes a used segment. This means adding a NEW segment to the recycler.
     * Params:
     *   index = index to the block
     *   segment_size = in number of blocks.
     */
    void dispose(const(Index) index, const uint segment_size) nothrow {
        // If the index is 0 then it is because we have returned a Leave.init. 
        // This should be ignored.
        if (index == 0) {
            return;
        }
        assumeWontThrow(to_be_recycled.insert(new Segment(index, segment_size, Type.ADD)));
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
    immutable filename = fileId(
        "recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
        filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
        blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.ADD),
        new Segment(Index(10UL), 5, Type.ADD),
        new Segment(Index(17UL), 5, Type.ADD),
    ];
    Indices dispose_indices = new Indices(
        dispose_segments);
    recycler.recycle(
        dispose_indices[]);
    // recycler.dump();

    // writefln("####");
    Segment*[] claim_segments = [
        new Segment(Index(1UL), 2, Type.REMOVE),
    ];
    Indices claim_indices = new Indices(
        claim_segments);
    recycler.recycle(
        claim_indices[]);

    assert(
        recycler.indices.front.index == Index(
            3UL));
    assert(
        recycler.indices.front.end == 6);
    // recycler.dump();
}

@safe
unittest {
    // add extra test
    immutable filename = fileId(
        "recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
        filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
        blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.ADD),
        new Segment(Index(10UL), 5, Type.ADD),
        new Segment(Index(17UL), 5, Type.ADD),
    ];
    Indices dispose_indices = new Indices(
        dispose_segments);
    recycler.recycle(
        dispose_indices[]);
    recycler.write();
    recycler.dump();

    writefln("###########");
    Segment*[] extra_segments = [
        new Segment(Index(6UL), 2, Type.ADD),
        new Segment(Index(25UL), 6, Type.ADD),
        new Segment(Index(22UL), 3, Type.ADD),
    ];
    Indices extra_indices = new Indices(
        extra_segments);
    recycler.recycle(
        extra_indices[]);
    recycler.write();
    recycler.dump();
    writefln("#########");
    Segment*[] expected_segments = [
        new Segment(Index(1UL), 8, Type.NONE),
        new Segment(Index(10UL), 5, Type.NONE),
        new Segment(Index(17UL), 31 - 17, Type
                .NONE),
    ];
    Indices expected_indices = new Indices(
        expected_segments);

    assert(expected_indices.length == recycler.indices.length, "Got other indices than expected");
    (() @trusted {
        assert(expected_indices.opEquals(
            recycler.indices), "elements should be the same");
    }());
}

@safe
unittest {
    // middle add segment
    immutable filename = fileId(
        "recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
        filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
        blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.ADD),
        new Segment(Index(10UL), 5, Type
                .ADD),
    ];
    Indices dispose_indices = new Indices(
        dispose_segments);
    recycler.recycle(
        dispose_indices[]);
    // recycler.dump();

    Segment*[] remove_segments = [
        new Segment(Index(6UL), 4, Type
                .ADD),
    ];
    Indices remove_indices = new Indices(
        remove_segments);
    recycler.recycle(
        remove_indices[]);
    // recycler.dump();

    assert(recycler.indices.length == 1, "should only be one segment after middle insertion");
    assert(recycler.indices.front.index == Index(1UL) && recycler.indices.front.end == Index(
            15UL), "Middle insertion not valid");
}

unittest {
    // remove illegal element
    immutable filename = fileId(
        "recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
        filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
        blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.ADD),
        new Segment(Index(10UL), 5, Type.ADD),
    ];
    Indices dispose_indices = new Indices(
        dispose_segments);
    recycler.recycle(
        dispose_indices[]);
    // recycler.dump;
    Indices non_valid;

    non_valid = new Indices([
        new Segment(Index(20UL), 4, Type
                .REMOVE)
    ]);
    assertThrown!Throwable(
        recycler.recycle(
            non_valid[]));

    non_valid = new Indices(
        [
        new Segment(Index(3UL), 5, Type
            .REMOVE)
    ]);
    assertThrown!Throwable(
        recycler.recycle(
            non_valid[]));

    non_valid = new Indices(
        [
        new Segment(Index(6UL), 4, Type
            .REMOVE)
    ]);
    assertThrown!Throwable(
        recycler.recycle(
            non_valid[]));
}

unittest {
    // empty lowerrange connecting
    immutable filename = fileId(
        "recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
        filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
        blockfile);

    Indices add_indices;
    add_indices = new Indices(
        [
        new Segment(Index(10UL), 5, Type
            .ADD)
    ]);
    recycler.recycle(
        add_indices[]);
    // recycler.dump;
    add_indices = new Indices(
        [
        new Segment(Index(2UL), 8, Type
            .ADD)
    ]);
    recycler.recycle(
        add_indices[]);

    assert(recycler.indices.length == 1, "should have merged segments");
    assert(recycler.indices.front.index == Index(
            2UL), "Index not correct");
    assert(
        recycler.indices.front.end == Index(
            15UL));

    // upperrange empty connecting
    add_indices = new Indices(
        [
        new Segment(Index(15UL), 5, Type
            .ADD)
    ]);
    recycler.recycle(
        add_indices[]);
    assert(recycler.indices.length == 1, "should have merged segments");
    assert(recycler.indices.front.index == Index(
            2UL));
    assert(
        recycler.indices.front.end == Index(
            20UL));
    // recycler.dump;    
}

unittest {
    // empty lowerrange NOT connecting
    immutable filename = fileId(
        "recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
        filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
        blockfile);
    Indices add_indices;
    add_indices = new Indices(
        [
        new Segment(Index(10UL), 5, Type
            .ADD)
    ]);
    recycler.recycle(
        add_indices[]);
    // recycler.dump;
    add_indices = new Indices(
        [
        new Segment(Index(2UL), 5, Type
            .ADD)
    ]);
    recycler.recycle(
        add_indices[]);

    assert(recycler.indices.length == 2, "should NOT have merged types");
    assert(recycler.indices.front.index == Index(
            2UL), "Index not correct");
    // recycler.dump

    // upper range NOT connecting
    add_indices = new Indices(
        [
        new Segment(Index(25UL), 5, Type
            .ADD)
    ]);
    recycler.recycle(
        add_indices[]);
    assert(recycler.indices.length == 3, "Should not have merged");
    assert(recycler.indices.back.index == Index(
            25UL), "Should not have merged");

}

unittest {
    // NOT empty upperrange and lowerrange connecting
    // empty lowerrange connecting
    immutable filename = fileId(
        "recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
        filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
        blockfile);

    Indices add_indices = new Indices(
        [
        new Segment(Index(10UL), 5, Type.ADD),
        new Segment(Index(1UL), 1, Type
            .ADD)
    ]);
    recycler.recycle(
        add_indices[]);
    // recycler.dump;
    add_indices = new Indices(
        [
        new Segment(Index(5UL), 5, Type
            .ADD)
    ]);
    recycler.recycle(
        add_indices[]);
    // recycler.dump;
    assert(recycler.indices.length == 2, "should have merged segments");

    // upperrange not empty connecting
    add_indices = new Indices(
        [
        new Segment(Index(25UL), 5, Type
            .ADD)
    ]);
    recycler.recycle(
        add_indices[]);
    add_indices = new Indices(
        [
        new Segment(Index(17UL), 2, Type.ADD)
    ]);
    recycler.recycle(
        add_indices[]);
    assert(
        recycler.indices.length == 4);
}
