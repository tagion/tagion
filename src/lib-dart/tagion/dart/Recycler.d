/// Recycler for the blockfile.
module tagion.dart.Recycler;

import std.algorithm;
import std.container.rbtree : RedBlackTree;
import std.format;
import std.range;
import std.stdio;
import std.traits : PointerTarget, isImplicitlyConvertible;
import std.typecons : tuple;
import tagion.basic.Types : Buffer;
import tagion.dart.BlockFile : BlockFile, Index, check;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONRecord : HiBONRecord, exclude, label, recordType;

/** 
 * The segments used for the recycler.
 * They contain a next pointer that points to the next recycler segment index. 
 * As well as a index for where it is located.
 */
@safe @recordType("R")
struct RecycleSegment {
    Index next;
    ulong size;
    @exclude Index index;
    Index end() const pure nothrow @nogc {
        return Index(index + size);
    }

    mixin HiBONRecord!(q{
        @disable this();
        this(const Index index, const ulong size, Index next = Index.init) pure nothrow {
            this.index = index;
            this.size = size;
            this.next = next;
        }
        this(BlockFile blockfile, const Index _index) 
        in (_index != Index.init) 
        do
        {
            blockfile.seek(_index);
            const doc = blockfile.file.fread();
            check(RecycleSegment.isRecord(doc), "The loaded segment was not of type segment doc");
            next = doc[GetLabel!(next).name].get!Index;
            size = doc[GetLabel!(size).name].get!ulong;
            index = _index;
          
        }
        this(const(Document) doc, const(Index) _index) 
        in (_index != Index.init)
        do
        {
            index = Index(_index);
            this(doc);

        }
    });

    /// We never want to create a segment with a size smaller than zero.
    version (DART_RECYCLER_INVARINAT) {
        invariant {
            assert(size > 0);
        }
        /// We never want to create a index at Index.init.
        invariant {
            assert(index != Index.init, "RecycleSegment cannot be inserted at index 0");
        }
    }
}

/// Indices in the recycler: sorted by index
alias Indices = RedBlackTree!(RecycleSegment*, (a, b) => a.index < b.index); // RecycleSegment: sorted by size.

/** 
 * Used for disposing and claiming segments from the blockfile. 
 * Therefore responsible for keeping track of unused segments.
 * and making sure these are used so the file does not continue.
 * growing.
 */
@safe
struct Recycler {
    /** 
     * Checks if the recycler has overlapping segments.
     */
    version (DART_RECYCLER_INVARINAT) {
        invariant {
            assert(noOverlaps, "Recycle segments has overlaps");
        }
        /** 
     * Checks if the indicies and segments are the same length;
     */
        invariant {
            assert(indices.length == segments.length);
        }
    }
    protected {
        BlockFile owner; /// The blockfile owner
        Indices indices; /// Indices that are stored in the blockfile.
        RecycleSegment*[] segments; /// The other way to sort. Sorted by segment size therefore allowing overlaps.
        RecycleSegment*[] to_be_recycled; /// RecycleSegments that are disposed and need to be added to the recycler.
    }
    @disable this();
    this(BlockFile owner) pure nothrow
    in (owner !is null)

    do {
        this.owner = owner;
        indices = new Indices;
    }
    /** 
     * Function to sort the segments by their size. It returns a assumeSorted of the segments.
     */
    protected auto sortedRecycleSegments() {
        // check if the segments are already sorted. If not then sort.
        version(WITHOUT_SORTING) {
        } else {
            if (!segments.isSorted!((a, b) => a.size < b.size)) {
                segments.sort!((a, b) => a.size < b.size);
            }
        }
        return assumeSorted!((a, b) => a.size < b.size)(segments);
    }
    private ptrdiff_t findIndex(RecycleSegment* segment) pure nothrow @nogc {
        ptrdiff_t start = 0;
        ptrdiff_t end = cast(ptrdiff_t) segments.length - 1;
        while (start <= end) {
            ptrdiff_t mid = (start + end) / 2;
            if (segments[mid].size == segment.size) {
                return mid;
            }
            else if (segments[mid].size < segment.size) {
                start = mid + 1;
            }
            else {
                end = mid - 1;
            }
        }
        return end + 1;
    }

    
    /** 
     * Insert a single segment into the recycler.
     * Params:
     *   segment = segment to be inserted.
     */
    protected void insert(RecycleSegment* segment) {
        indices.insert(segment);

        version(WITHOUT_SORTING) {
            import core.stdc.string : memcpy;
            const index = findIndex(segment);

            segments.insertInPlace(index, segment);
            // segments.length++;
            // if (index < cast(ptrdiff_t) segments.length -1) {
            //     const byte_size = (segments.length - index - 1) * size_t.sizeof;
            //     memcpy(&segments[index+1], &segments[index], byte_size);
            // }
            // segments[index] = segment;
        } else {
            segments ~= segment;
        }
    }
    /** 
     * Inserts a range of segments into the recycler.
     * Params:
     *   segment_range = Range of segments. Must be ElementType = RecycleSegment*
     */
    protected void insert(R)(R segment_range)
            if (isInputRange!R && isImplicitlyConvertible!(ElementType!R, RecycleSegment*)) {
        indices.stableInsert(segment_range);
        version(WITHOUT_SORTING) {
            foreach(seg; segment_range) {
                insert(seg);
            }
        } else {
            segments ~= segment_range;
        }
    }
    /** 
     * Removes a segment from the recycler.
     * Params:
     *   segment = segment to be removed
     */
    protected void remove(RecycleSegment* segment) {
        auto remove_segment = indices.equalRange(segment).front;

        indices.removeKey(remove_segment);
        segments = segments.remove(segments.countUntil(remove_segment));
    }
    /** 
     * Recycles the segments. Goes over the list of recycle_segments. 
     * First it takes the lowerbound. If there is a element in the 
     * lowerbound, the index of the current segment is changed to the one
     * of the lowerbound.back and the `lower_range.back` is removed.
     * The same step is used for the upperbound using the front of the elements.
     * We go over all the new segments that needs to be recycled.
     * First we get `lowerBound` in the `indices`. The `indices` are sorted by
     * index meaning we get all sgements by indexes as a range
     * that are smaller or equal to our segment. If the segments connext
     * we add remove it and create a new one. The same procedure is used for
     * the upperrange.
     *
     * Params:
     *   recycle_segments = newly disposed segments
     */
    void recycle(RecycleSegment*[] recycle_segments) {

        foreach (insert_segment; recycle_segments) {
            auto lower_range = indices.lowerBound(insert_segment);
            if (!lower_range.empty && lower_range.back.end == insert_segment.index) {

                insert_segment.index = lower_range.back.index;
                insert_segment.size = lower_range.back.size + insert_segment.size;
                // remove the lowerrange segment since we have created a new segment 
                // that incorporates this segment.
                remove(lower_range.back);
            }

            auto upper_range = indices.upperBound(insert_segment);
            if (!upper_range.empty && upper_range.front.index == insert_segment.end) {
                insert_segment.size = upper_range.front.size + insert_segment.size;
                remove(upper_range.front);
            }
            // lastly we insert the new segment.
            insert(insert_segment);

        }
    }

    /**
    Returns: true if the segments overlaps in the indices
    */
    private bool noOverlaps() const pure nothrow @nogc {
        import std.algorithm.iteration : map;
        import std.algorithm.searching : any;
        import std.range : slide;

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

    const(ulong) length() const pure nothrow @nogc {
        return indices.length;

    }
    /** 
     * Dumps the segments in the recycler.
     */
    void dump(File fout = stdout) {

        if (indices.empty) {
            fout.writefln("indices empty");
            return;
        }

        foreach (segment; indices) {
            fout.writef("INDEX: %s |", segment
                    .index);
            fout.writef("END: %s |", segment
                    .end);
            fout.writefln("NEXT: %s ", segment.next);
        }
    }
    /** 
     * Dumps the segments in the to_be_recycled array.
     */
    void dumpToBeRecycled(File fout = stdout) {
        import std.stdio;

        if (to_be_recycled.empty) {
            fout.writefln("indices empty");
            return;
        }

        foreach (segment; to_be_recycled) {
            fout.writef("INDEX: %s |", segment
                    .index);
            fout.writef("END: %s |", segment
                    .end);
            fout.writefln("NEXT: %s ", segment.next);
        }
    }

    /** 
     * Reads an element from the blockfile. 
     * Params:
     *   index = 
     */
    void read(Index index) {
        // First we reset the indices and segments
        indices = new Indices;
        segments = null;
        // If the index is Index(0) we return. 
        if (index == Index(0)) {
            return;
        }
        // The last element points to a Index.init. 
        // Therefore we continue until we reach this.
        while (index != Index.init) {
            auto add_segment = new RecycleSegment(owner, index);
            insert(add_segment);
            index = add_segment.next;
        }
    }

    /** 
    * Writes the data to the file. First it calls recycler with the to_be_recycled. 
    * Afterwards it goes through and updates the pointer chain.
    * Returns: the index of the first recycler index.
    */
    Index write() nothrow {
        assumeWontThrow(recycle(to_be_recycled[]));
        to_be_recycled = null;

        if (indices.empty) {
            return Index.init;
        }

        Index next;
        bool first = true;
        foreach_reverse (segment; indices) {
            if (segment.next != next || first) {
                segment.next = next;
                assumeWontThrow(owner.seek(segment.index));
                assumeWontThrow(owner.file.fwrite(*segment));
                first = false;
            }
            next = segment.index;
        }

        return indices[].front.index;
    }

    /**
     * Claims a free segment. Priority is first to use segments already in the disposed list 
     * from to_be_recycled. Next is to use a element in the recycler indices. 
     * Therefore removing a segment from the recycler. 
     * Secondly if no available segments then it appends a new segment to the blockfile and changes
     * the owners last block index.
     * Params:
     *   segment_size = in number of blocks.
     * Returns: 
     *   Index pointer of a free segment
     */
    const(Index) claim(const ulong segment_size) nothrow
    in (segment_size > 0)

    out (result) {
        assert(result != Index.init);

    }
    do {
        try {
            // First we check the to_be_recycled. 
            auto seg_index = to_be_recycled.countUntil!(seg => seg.size == segment_size);
            if (seg_index >= 0) {
                scope (exit) {
                    to_be_recycled = to_be_recycled.remove(seg_index);
                }
                return to_be_recycled[seg_index].index;
            }

            auto sorted_segments = sortedRecycleSegments();
            auto search_segment = new RecycleSegment(Index.max, segment_size);

            auto equal_range = sorted_segments.equalRange(search_segment);

            if (!equal_range.empty) {
                // there is a element equal.
                const index = equal_range.front.index;
                remove(equal_range.front);
                return index;
            }

            auto upper_range = sorted_segments.upperBound(search_segment);
            if (!upper_range.empty) {
                const index = upper_range.front.index;
                auto add_segment = new RecycleSegment(Index(index + segment_size), upper_range.front.size - segment_size);

                remove(upper_range.front);

                insert(add_segment);
                return index;
            }
        }
        catch (Exception e) {
            assert(0, e.msg);
        }

        scope (success) {
            owner._last_block_index = Index(owner._last_block_index + segment_size);
        }

        return owner._last_block_index;

    }
    /** 
     * Disposes a used segment. This means adding a NEW segment to the recycler.
     * Params:
     *   index = index to the block
     *   segment_size = in number of blocks.
     */
    void dispose(const(Index) index, const ulong segment_size) nothrow {
        // If the index is 0 then it is because we have returned a Leave.init. 
        // This should not be added to the recycler.
        if (index == 0) {
            return;
        }

        auto seg = new RecycleSegment(index, segment_size);
        // The segment should not already be in the list of the to_be_recycled.
        assert(!(to_be_recycled.canFind(seg)), assumeWontThrow(
                format("segment already in dispose list index: %s", index)));
        to_be_recycled ~= seg;
    }

}

version (unittest) {
    import std.algorithm.iteration : map;
    import std.range : iota;
    import tagion.basic.Types : FileExtension;
    import tagion.basic.basic : forceRemove;
    import tagion.dart.BlockFile;

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

    RecycleSegment*[] dispose_segments = [
        new RecycleSegment(Index(1UL), 5),
        new RecycleSegment(Index(6UL), 5),
        new RecycleSegment(Index(17UL), 5),
    ];

    // add the segments with the recycler function.
    recycler.recycle(dispose_segments);
    // recycler.dump();

    // writefln("####");

    const(Index) claim_index = recycler.claim(5);
    assert(claim_index == Index(17UL));
    assert(recycler.indices.length == 1);
    assert(recycler.segments.length == 1);

    auto seg = recycler.indices.front;
    assert(seg.index == Index(1UL));
    assert(seg.end == Index(seg.index + seg.size));

}

@safe
unittest {
    // add extra test
    immutable filename = fileId("recycle").fullpath;
    filename.forceRemove;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
            filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
            blockfile);

    RecycleSegment*[] dispose_segments = [
        new RecycleSegment(Index(1UL), 5),
        new RecycleSegment(Index(10UL), 5),
        new RecycleSegment(Index(17UL), 5),
    ];

    recycler.recycle(dispose_segments);
    recycler.write();

    RecycleSegment*[] extra_segments = [
        new RecycleSegment(Index(6UL), 2),
        new RecycleSegment(Index(25UL), 6),
        new RecycleSegment(Index(22UL), 3),
    ];

    recycler.recycle(extra_segments);
    recycler.write();

    RecycleSegment*[] expected_segments = [
        new RecycleSegment(Index(1UL), 8),
        new RecycleSegment(Index(10UL), 5),
        new RecycleSegment(Index(17UL), 31 - 17),
    ];
    Indices expected_indices = new Indices(expected_segments);

    assert(expected_indices.length == recycler.indices.length, "Got other indices than expected");
    (() @trusted { assert(expected_indices.opEquals(
            recycler.indices), "elements should be the same"); }());
}

@safe
unittest {
    // middle add segment
    immutable filename = fileId(
            "recycle").fullpath;
    filename.forceRemove;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
            filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
            blockfile);

    RecycleSegment*[] dispose_segments = [
        new RecycleSegment(Index(1UL), 5),
        new RecycleSegment(Index(10UL), 5),
    ];

    recycler.recycle(dispose_segments);
    // recycler.dump();

    RecycleSegment*[] remove_segments = [
        new RecycleSegment(Index(6UL), 4),
    ];

    recycler.recycle(remove_segments);
    // recycler.dump();

    assert(recycler.indices.length == 1, "should only be one segment after middle insertion");
    assert(recycler.indices.front.index == Index(1UL) && recycler.indices.front
            .end == Index(15UL), "Middle insertion not valid");
}

unittest {
    // empty lowerrange connecting
    immutable filename = fileId(
            "recycle").fullpath;
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
            filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
            blockfile);

    RecycleSegment*[] add_indices;
    add_indices =
        [
            new RecycleSegment(Index(10UL), 5)
        ];
    recycler.recycle(add_indices);
    // recycler.dump;
    add_indices =
        [
            new RecycleSegment(Index(2UL), 8)
        ];
    recycler.recycle(add_indices);

    assert(recycler.indices.length == 1, "should have merged segments");
    assert(recycler.indices.front.index == Index(2UL), "Index not correct");
    assert(recycler.indices.front.end == Index(15UL));

    // upperrange empty connecting
    add_indices =
        [
            new RecycleSegment(Index(15UL), 5)
        ];
    recycler.recycle(add_indices);
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
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
            filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
            blockfile);
    RecycleSegment*[] add_indices;
    add_indices =
        [
            new RecycleSegment(Index(10UL), 5)
        ];
    recycler.recycle(add_indices);
    // recycler.dump;
    add_indices =
        [
            new RecycleSegment(Index(2UL), 5)
        ];
    recycler.recycle(
            add_indices);

    assert(recycler.indices.length == 2, "should NOT have merged types");
    assert(recycler.indices.front.index == Index(
            2UL), "Index not correct");
    // recycler.dump

    // upper range NOT connecting
    add_indices =
        [
            new RecycleSegment(Index(25UL), 5)
        ];
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
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
            filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
            blockfile);

    RecycleSegment*[] add_indices =
        [
            new RecycleSegment(Index(10UL), 5),
            new RecycleSegment(Index(1UL), 1)
        ];
    recycler.recycle(add_indices);
    // recycler.dump;
    add_indices =
        [
            new RecycleSegment(Index(5UL), 5)
        ];
    recycler.recycle(add_indices);
    // recycler.dump;
    assert(recycler.indices.length == 2, "should have merged segments");

    // upperrange not empty connecting
    add_indices =
        [
            new RecycleSegment(Index(25UL), 5)
        ];
    recycler.recycle(add_indices);
    add_indices =
        [
            new RecycleSegment(Index(17UL), 2)
        ];
    recycler.recycle(
            add_indices);
    assert(
            recycler.indices.length == 4);
}

unittest {
    immutable filename = fileId(
            "recycle").fullpath;
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(
            filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(
            blockfile);

    RecycleSegment*[] add_indices =
        [
            new RecycleSegment(Index(10UL), 5),
        ];
    recycler.recycle(add_indices);

    recycler.claim(5);
    assert(recycler.indices.length == 0);
}

unittest {
    // test the full recycler flow.
    immutable filename = fileId("recycle").fullpath;
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    auto recycler = Recycler(blockfile);
    scope (exit) {
        blockfile.close;
    }
    // add some segments
    recycler.dispose(Index(1UL), 5);
    recycler.dispose(Index(6UL), 5);
    recycler.dispose(Index(25UL), 10);
    assert(recycler.to_be_recycled.length == 3, "all elements not added to recycler");

    const(Index) begin = recycler.write();
    // writefln("BEGIN INDEX: %s", begin);
    // recycler.dump();
    assert(recycler.to_be_recycled.empty, "should be empty after being recycled");
    assert(begin == Index(1UL), "should be 1UL");

    RecycleSegment*[] expected_segments = [
        new RecycleSegment(Index(1UL), 11, Index(25UL)),
        new RecycleSegment(Index(25UL), 10, Index.init),
    ];
    Indices expected_indices = new Indices(expected_segments);
    assert(expected_indices == recycler.indices);

}

version (unittest) {
    @safe @recordType("D")
    static struct Data {

        string text;

        mixin HiBONRecord!(q{
            this(string text) {
                this.text = text;
            }
        });
    }

}
@safe
unittest {
    {
        // try to read / load indices.
        immutable filename = fileId("recycle").fullpath;
        filename.forceRemove;

        BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
        auto blockfile = BlockFile(filename);
        // auto recycler = Recycler(blockfile);
        scope (exit) {
            blockfile.close;
        }
        // add some segments

        Data[] datas = [
            Data("abc"),
            Data("1234"),
            Data("wowo"),
            Data("hugo"),
        ];

        foreach (data; datas) {
            const index = blockfile.save(data).index;
            // writefln("block index = %s", index);
        }
        blockfile.store();
        assert(blockfile.recycler.indices.length == 0, "since we only added blocks to empty recycler nothing should be in recycler");
        assert(blockfile.recycler.to_be_recycled.length == 0, "to be recycled should be empty");
        const doc = blockfile.load(Index(2));
        // writefln("document: %s", doc["text"].get!string);
        assert(doc["text"].get!string == "1234");

        blockfile.dispose(Index(2));
        blockfile.dispose(Index(3));

        // writefln("before recycleDump");
        // blockfile.recycleDump;
        blockfile.store();
        // writefln("after recycleDump");
        // blockfile.recycleDump;
        // writefln("entire blockfile dump");
        // blockfile.dump;

        assert(blockfile.recycler.to_be_recycled.length == 0);
        // the reason why this becomes one is because the middle gap is filled with the recycler and statistic block.
        // |D index(1) size(1)|S index(2) size(1)|S index(3) size(1)|D index(4) size(1)|R index(5) size(2)|M index(7) size(1)|

        assert(blockfile.recycler.indices.length == 1, "should contain one recycler segment for the new statistic blocks. ");

        blockfile.close();
        blockfile = BlockFile(filename);
        assert(blockfile.recycler.indices.length == 1, "should be the same after loading");

        // writeln("recycle dump");
        // blockfile.recycler.dump;

        // close and open blockfile again.
    }

}

@safe
unittest {
    /// saving to empty an empty blockfile.
    // try to read / load indices.
    immutable filename = fileId("recycle").fullpath;
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    // auto recycler = Recycler(blockfile);
    scope (exit) {
        blockfile.close;
    }

    Data[] datas = [
        Data("abc"),
        Data("1234"),
        Data("wowo"),
        Data("hugo"),
    ];

    foreach (data; datas) {
        blockfile.save(data);
    }

    blockfile.store();
    /// No elements should have been added to the recycler.
    assert(blockfile.recycler.indices.length == 0);

}

@safe
// version(none)
unittest {
    immutable filename = fileId("recycle").fullpath;
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    RecycleSegment*[] dispose_segments = [
        new RecycleSegment(Index(1UL), 5),
        new RecycleSegment(Index(10UL), 5),
        new RecycleSegment(Index(17UL), 5),
        new RecycleSegment(Index(25UL), 5),
    ];

    recycler.insert(dispose_segments[]);
    assert(recycler.indices.length == 4);
    assert(recycler.segments.length == 4, format("length should be 4 was %s", recycler.segments.length));

    auto remove_segment = new RecycleSegment(Index(17UL), 5);

    recycler.remove(remove_segment);

    assert(recycler.indices.length == 3);
    assert(recycler.segments.length == 3);

    RecycleSegment*[] segs = [
        new RecycleSegment(Index(1UL), 5),
        new RecycleSegment(Index(10UL), 5),
        // new RecycleSegment(Index(17UL), 5, Type.NONE), // This is the one that should be removed
        new RecycleSegment(Index(25UL), 5),
    ];

    // recycler.indices[].array
    //     .sort!((a, b) => a < b)
    //     .each!writeln;

    // recycler.segments[].array
    //     .sort!((a, b) => a < b)
    //     .each!writeln;

    assert(equal(recycler.indices[].array.sort!((a, b) => a < b), recycler.segments[].array.sort!((a, b) => a < b)));

}

@safe
unittest {
    // save claim save on same segment.
    immutable filename = fileId("recycle").fullpath;
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }

    const data = Data("abc");
    const index = blockfile.save(data).index;
    blockfile.store();
    // blockfile.dump;
    assert(blockfile.recycler.indices.length == 0, "Should be empty");

    blockfile.dispose(index);
    blockfile.save(data);
    blockfile.store();
    // blockfile.dump;

}

@safe
unittest {
    // pseudo random add remove blocks.
    immutable filename = fileId("recycle").fullpath;
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }

    import std.random;

    auto rnd = Random(1234);
    const number_of_elems = 100;
    const to_be_removed = 90;
    bool[Index] used;

    Data[] datas;
    foreach (i; 0 .. number_of_elems) {
        const number_of_chars = uniform(2, 1000, rnd);
        datas ~= Data(repeat('x', number_of_chars).array);
    }

    Index[] data_indexes;
    foreach (data; datas) {
        const data_idx = blockfile.save(data).index;
        assert(!(data_idx in used), "segment already recycled");
        used[data_idx] = true;
        data_indexes ~= data_idx;

    }
    blockfile.store;

    auto sample = randomSample(data_indexes[], to_be_removed).array;

    foreach (remove_index; sample) {
        blockfile.dispose(remove_index);
    }

    blockfile.store;
    // blockfile.recycleStatisticDump;
    blockfile.close;
    // writefln("dump after");
    // blockfile.dump;

}

@safe
unittest {
    // blocksegment range test.
    immutable filename = fileId("recycle").fullpath;
    filename.forceRemove;

    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }

    Data[] datas = [
        Data("abc"),
        Data("1234"),
        Data("wowo"),
        Data("hugo"),
    ];

    foreach (data; datas) {
        blockfile.save(data);
    }
    blockfile.store;

    import std.file;

    auto fout = File(deleteme, "w");
    scope (exit) {
        fout.close;
        deleteme.remove;
    }

    blockfile.dump(segments_per_line : 6, fout:
            fout);
    blockfile.recycleDump(fout);
    blockfile.statisticDump(fout);
    blockfile.recycleStatisticDump(fout);

    auto block_segment_range = blockfile.opSlice();
    assert(block_segment_range.walkLength == 7, "should contain 2 statistic, 1 master and 4 archives");

    foreach (i; 0 .. datas.length) {
        assert(block_segment_range.front.type == "D");
        block_segment_range.popFront;
    }
    assert(block_segment_range.walkLength == 3);
}
