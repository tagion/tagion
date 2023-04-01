module tagion.dart.Recycler;

import std.container.rbtree : RedBlackTree;
import std.range;
import std.typecons : tuple;
import std.stdio;
import std.traits : PointerTarget;

import tagion.basic.Types : Buffer;
import tagion.dart.BlockFile : BlockFile, Index, check;
import tagion.hibon.HiBONRecord : HiBONRecord, label, recordType, fwrite, fread;
import std.algorithm;
import tagion.hibon.HiBONJSON : toPretty;

enum Type : int {
    NONE = 0, /// NO Recycler instruction
    REMOVE = -1, /// Should be removed from recycler
    ADD = 1, /// should be added to recycler
    UPDATE = 2,
}

@safe @recordType("R")
struct Segment {
    Index next;
    uint size;
    @label("") Index index;
    @label("") Type type;
    Index end() const pure nothrow @nogc {
        return Index(index + size);
    }

    mixin HiBONRecord!(q{
        @disable this();
        this(const Index index, const uint size, const Type type=Type.NONE, Index next = Index.init) {
            this.index = index;
            this.size = size;
            this.type = type;
            this.next = next;
        }
        this(BlockFile blockfile, const Index _index) 
        in (_index != Index.init) 
        do
        {
            blockfile.seek(_index);
            const doc = blockfile.file.fread();
            // writeln(doc.toPretty);
            check(Segment.isRecord(doc), "The loaded segment was not of type segment doc");
            next = doc[GetLabel!(next).name].get!Index;
            size = doc[GetLabel!(size).name].get!uint;
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
    invariant {
        assert(size > 0);
    }

    invariant {
        assert(index != Index.init, "Segment cannot be inserted at index 0");
    }
}
// Indices: sorted by index
alias Indices = RedBlackTree!(Segment*, (a, b) => a.index < b.index); // Segment: sorted by size.
alias Segments = RedBlackTree!(Segment*, (a, b) => a.size < b.size, true);
@safe
struct Recycler {
    static bool print;

    void __write(Args...)(string fmt, Args args) nothrow @trusted {
        if (print) {
            assumeWontThrow(writefln(fmt, args));
        }
    }
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

    // protected void _remove(Segment* segment) {
    //     __write("before indices removekey");
    //     indices.removeKey(segment);
    //     __write("Going to remove segment");
    //     auto seg = segments.equalRange(segment).take(1);
    //     segments.remove(seg);
    // }

    protected void remove(Segment* segment) {
        auto r = indices.equalRange(segment).take(1);
        auto s = segments.equalRange(segment).take(1);
        indices.remove(r);
        segments.remove(s);
    }

    // protected void remove(Segment* segment) {
    //     indices.removeKey(segment);
    //     segments.removeKey(segment);
    // }

    // protected void remove(Segment* segment) {
    //     indices.removeKey(segment);
    //     Segment*[] remove_seg = [segment];
    //     Segments remove_segments = new Segments(remove_seg);
    //     segments.remove(remove_segments[].take(1));
    // }

    void recycle(Indices.Range recycle_segments) {

        if (indices.empty) {
            assert(recycle_segments.filter!(s => s.type != Type.ADD)
                    .take(2)
                    .walkLength == 0, "cannot remove segments from empty indices");
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

                if (lower_range.empty) {
                    // A ###
                    // assert(!upper_range.empty, "there must be something in the upper range if the lower range is empty.");
                    if (!upper_range.empty && segment.end == upper_range.front.index) {
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
                if (lower_range.back.end == segment.index) {
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

        if (indices.empty) {
            writefln("indices empty");
            return;
        }

        foreach (segment; indices) {
            writef("INDEX: %s |", segment
                    .index);
            writef("END: %s |", segment
                    .end);
            writefln("NEXT: %s ", segment.next);
        }
    }

    void dumpToBeRecycled() {
        import std.stdio;

        if (to_be_recycled.empty) {
            writefln("indices empty");
            return;
        }

        foreach (segment; to_be_recycled) {
            writef("INDEX: %s |", segment
                    .index);
            writef("END: %s |", segment
                    .end);
            writefln("NEXT: %s ", segment.next);
        }
    }

    bool isRecyclable(const Index index) const pure nothrow {
        return false;
    }

    void read(Index index) {
        indices = new Indices;
        segments = new Segments;
        if (index == Index(0)) {
            return;
        }
        while (index != Index.init) {

            auto add_segment = new Segment(owner, index);
            __write("read size: %s, index: %s", add_segment.size, add_segment.index);
            insert(add_segment);
            index = add_segment.next;
        }
    }

    void load(Index index) {
        return;
    }

    /** 
     * Writes the data to the file. First it calls recycler with the to_be_recycled. Afterwards it goes through and updated the pointer chain.
     * Params:
     *   index = Index of the blockfile???
     */
    Index write() nothrow {
        assumeWontThrow(recycle(to_be_recycled[]));
        // assumeWontThrow(__write("write to_be_recycled length = %s", to_be_recycled.length));
        to_be_recycled.clear;

        if (indices.empty) {
            return Index.init;
        }

        // __write("indices to be written");
        // if (print) {
        //     assumeWontThrow(dump);

        // }

        Index next;
        bool first = true;
        foreach_reverse (segment; indices) {
            if (segment.next != next || first) {
                if (first) {
                    __write("first time");
                }
                segment.next = next;
                __write("segment index <%s>, size <%s>", segment.index, segment.size);
                __write("next: %s", next);
                assumeWontThrow(owner.seek(segment.index));
                assumeWontThrow(owner.file.fwrite(*segment));
                first = false;
            }
            next = segment.index;
        }
        // if (print) {
        //     assumeWontThrow(recycler.dump);
        // }
        // assumeWontThrow(read(indices[].front.index));
        // __write("after read");
        // if (print) {
        //     assumeWontThrow(dump);
        // }
        // Index index = indices[].front.index;
        // while (index != Index.init) {
        //     __write("index: %s", index);
        //     assumeWontThrow(owner.seek(index));
        //     const doc = assumeWontThrow(owner.file.fread);
        //     __write("Document: %s", assumeWontThrow(doc.toPretty));
        //     index = Index(index + doc.full_size);
        // }

        // assumeWontThrow(writefln("wrote recycler with %s segments", indices.length));
        // assumeWontThrow(dump());
        // assumeWontThrow(writeln);
        return indices[].front.index;
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
    const(Index) claim(const uint segment_size) nothrow
    in (segment_size > 0)

    out (result) {
        assert(result != Index.init);
    }
    do {
        __write("claiming size: %s", segment_size);

        try {

            auto search_segment = new Segment(Index.max, segment_size);
            auto equal_range = segments.equalRange(search_segment);
            if (!equal_range.empty) {
                // there is a element equal.
                const index = equal_range.front.index;
                remove(equal_range.front);
                return index;
            }

            auto upper_range = segments.upperBound(search_segment);
            if (!upper_range.empty) {
                const index = upper_range.front.index;
                auto add_segment = new Segment(
                    Index(index + segment_size), upper_range.front.size - segment_size);
                __write("upper range index: %s, size %s", upper_range.front.index, upper_range
                        .front.size);
                remove(upper_range.front);
                insert(add_segment);
                return index;
            }
        }
        catch (Exception e) {
            assert(0, e.msg);
        }

        scope (success) {
            owner._last_block_index += segment_size;
        }
        return owner._last_block_index;

    }
    /** 
     * Disposes a used segment. This means adding a NEW segment to the recycler.
     * Params:
     *   index = index to the block
     *   segment_size = in number of blocks.
     */
    void dispose(const(Index) index, const uint segment_size) nothrow {
        assumeWontThrow(__write("disposing segment: index=%s, size=%s", index, segment_size));
        // If the index is 0 then it is because we have returned a Leave.init. 
        // This should be ignored.
        // assumeWontThrow(writefln("calling dispose with: Index= %s, segment_size = %s", index, segment_size));
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
    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.ADD),
        new Segment(Index(6UL), 5, Type.ADD),
        new Segment(Index(17UL), 5, Type.ADD),
    ];

    Indices dispose_indices = new Indices(dispose_segments);
    // add the segments with the recycler function.
    recycler.recycle(dispose_indices[]);
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

    Segment*[] extra_segments = [
        new Segment(Index(6UL), 2, Type.ADD),
        new Segment(Index(25UL), 6, Type.ADD),
        new Segment(Index(22UL), 3, Type.ADD),
    ];
    Indices extra_indices = new Indices(extra_segments);
    recycler.recycle(extra_indices[]);
    recycler.write();

    Segment*[] expected_segments = [
        new Segment(Index(1UL), 8, Type.NONE),
        new Segment(Index(10UL), 5, Type.NONE),
        new Segment(Index(17UL), 31 - 17, Type
                .NONE),
    ];
    Indices expected_indices = new Indices(expected_segments);

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
    assert(recycler.indices.front.index == Index(1UL) && recycler.indices.front
            .end == Index(
                15UL), "Middle insertion not valid");
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

unittest {
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
    ]
    );
    recycler.recycle(add_indices[]);

    recycler.claim(5);
    assert(recycler.indices.length == 0);
}

unittest {
    // test the full recycler flow.
    immutable filename = fileId("recycle").fullpath;
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

    Segment*[] expected_segments = [
        new Segment(Index(1UL), 11, Type.NONE, Index(25UL)),
        new Segment(Index(25UL), 10, Type.NONE, Index.init),
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
        Recycler.print = false;
        scope (exit) {
            Recycler.print = false;
        }
        // try to read / load indices.
        immutable filename = fileId("recycle").fullpath;
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
        assert(blockfile.recycler.indices.length == 2, "should contain one segment for middle blocks and one for statistic");

        blockfile.close();
        blockfile = BlockFile(filename);
        assert(blockfile.recycler.indices.length == 2, "should be the same after loading");

        // writeln("recycle dump");
        // blockfile.recycler.dump;

        // close and open blockfile again.
    }

}

@safe
unittest {
    writefln("UHA VI LAVER RECLAIM");
    // saving to empty blockfile therfore claiming.
    Recycler.print = true;

    scope (exit) {
        Recycler.print = false;
    }
    // try to read / load indices.
    immutable filename = fileId("recycle").fullpath;
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
        const index = blockfile.save(data).index;
        writefln("index: %s", index);
    }

    blockfile.store();

}

@safe
unittest {
    Recycler.print = true;
    scope (exit) {
        Recycler.print = false;
    }

    immutable filename = fileId("recycle").fullpath;
    BlockFile.create(filename, "recycle.unittest", SMALL_BLOCK_SIZE);
    auto blockfile = BlockFile(filename);
    scope (exit) {
        blockfile.close;
    }
    auto recycler = Recycler(blockfile);

    Segment*[] dispose_segments = [
        new Segment(Index(1UL), 5, Type.NONE),
        new Segment(Index(10UL), 5, Type.NONE),
        new Segment(Index(17UL), 5, Type.NONE),
        new Segment(Index(25UL), 5, Type.NONE),
    ];

    auto insert_indices = new Indices(dispose_segments);
    recycler.insert(insert_indices[]);
    assert(recycler.indices.length == 4);
    assert(recycler.segments.length == 4);

    auto remove_segment = new Segment(Index(17UL), 5);

    recycler.remove(remove_segment);

    assert(recycler.indices.length == 3);
    assert(recycler.segments.length == 3);

    Segment*[] segs = [
        new Segment(Index(1UL), 5, Type.NONE),
        new Segment(Index(10UL), 5, Type.NONE),
        // new Segment(Index(17UL), 5, Type.NONE), // This is the one that should be removed
        new Segment(Index(25UL), 5, Type.NONE),
    ];

    Segments expected_segments = new Segments(segs);
    Indices expected_indices = new Indices(segs);

    (() @trusted {
        assert(opEquals(expected_segments, recycler.segments));
        assert(opEquals(expected_indices, recycler.indices));
    }());

}
