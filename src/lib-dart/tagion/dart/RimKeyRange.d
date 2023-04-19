module tagion.dart.RimKeyRange;

//import std.stdio;
import std.algorithm;
import std.range;
import std.traits;
import std.container.array;
import std.typecons : Flag, Yes, No;

import tagion.dart.Recorder : RecordFactory, Archive, GetType, Neutral;
import tagion.basic.Types : isBufferType, Buffer;
import tagion.utils.Miscellaneous : hex;
import tagion.basic.Debug;

/++
 + Gets the rim key from a buffer
 +
 + Returns;
 +     fingerprint[rim]
 +/
@safe
ubyte rim_key(F)(F rim_keys, const uint rim) pure if (isBufferType!F) {
    if (rim >= rim_keys.length) {
        debug __write("%s rim=%d", rim_keys.hex, rim);
    }
    return rim_keys[rim];
}

@safe
RimKeyRange!Range rimKeyRange(Range)(Range range, const Flag!"undo" undo = Yes.undo)
        if (isInputRange!Range && is(ElementType!Range : const(Archive))) {
    return RimKeyRange!Range(range, undo);
}

@safe
auto rimKeyRange(const(RecordFactory.Recorder) rec, const Flag!"undo" undo = Yes.undo) {

    return rimKeyRange(rec[], undo);
}

// Range over a Range with the same key in the a specific rim
@safe
struct RimKeyRange(Range) if (isInputRange!Range && isImplicitlyConvertible!(ElementType!Range, const(Archive))) {
    alias archive_less = RecordFactory.Recorder.archive_sorted;

    @safe
    final class RangeContext {
        Range range;
        Archive[] _added_archives;
        AdderRange added_range;
        this(Range range) pure nothrow {
            this.range = range;
            added_range = new AdderRange(0);
        }

        protected this(RangeContext rhs) {
            _added_archives = rhs._added_archives;
            range = rhs.range;
            added_range = new AdderRange(rhs.added_range.index);
        }

        pure nothrow {
            /**
             * Checks if the range is empty
             * Returns: true if empty
             */
            bool empty() @nogc {
                return range.empty && added_range.empty;
            }

            /**
             *  Progress one archive
             */
            void popFront() {
                if (!added_range.empty && !range.empty) {
                    if (archive_less(added_range.front, range.front)) {
                        added_range.popFront;
                    }
                    else {
                        range.popFront;
                    }
                }
                else if (!range.empty) {
                    range.popFront;
                }
                else if (!added_range.empty) {
                    added_range.popFront;
                }
            }
            /**
             * Gets the current archive in the range
             * Returns: current archive and return null if the range is empty
             */
            const(Archive) front() {
                if (!added_range.empty && !range.empty) {
                    if (archive_less(added_range.front, range.front)) {
                        return added_range.front;
                    }
                    return range.front;
                }
                if (!range.empty) {
                    return range.front;
                }
                else if (!added_range.empty) {
                    return added_range.front;
                }
                return Archive.init;
            }

            RangeContext save() {
                return new RangeContext(this);
            }

        }
        @safe @nogc
        final class AdderRange {
            size_t index;
            this(size_t index) pure nothrow {
                this.index = index;
            }

            bool empty() pure const nothrow @nogc {
                return index >= _added_archives.length;
            }

            Archive front() pure nothrow @nogc {
                return _added_archives[index];
            }

            void popFront() pure nothrow @nogc {
                if (!empty) {
                    index++;
                }
            }
        }
    }

    //bool identical() pure nothrow {
    bool identical() {
        if (rim < 0 || ctx.empty) {
            return false;
        }
        const _index = ctx.added_range.index;
        auto _range = ctx.range;
        scope (exit) {
            ctx.added_range.index = _index;
            ctx.range = _range;
        }
        const first = ctx.front;
        popFront;
        return !empty && this.all!((a) => first.fingerprint == a.fingerprint);
    }

    bool oneLeft() {
        if (rim < 0 || ctx.empty) {
            return false;
        }
        const _index = ctx.added_range.index;
        auto _range = ctx.range;
        scope (exit) {
            ctx.added_range.index = _index;
            ctx.range = _range;
        }

        return this.take(2).walkLength == 1;
    }

    bool moreThanOneADD() {
        if (rim < 0 || ctx.empty) {
            return false;
        }
        const _index = ctx.added_range.index;
        auto _range = ctx.range;
        scope (exit) {
            ctx.added_range.index = _index;
            ctx.range = _range;
        }
        return this.filter!((a) => a.type == Archive.Type.ADD).take(2).walkLength > 1;
    }

    protected RangeContext ctx;
    const Buffer rim_keys;
    const int rim;
    const Flag!"undo" undo;
    @disable this();

    void add(Archive archive)
    in ((rim < 0) || (rim_keys == archive.fingerprint[0 .. rim + 1]))
    do {
        ctx._added_archives ~= (archive);
    }

    private this(RimKeyRange rhs, const uint rim) {
        ctx = rhs.ctx;
        rim_keys = (rhs.empty) ? Buffer.init : rhs.front.fingerprint[0 .. rim + 1];
        this.rim = rim & int.max;
        undo = rhs.undo;

    }

    private this(RimKeyRange rhs) pure nothrow {
        ctx = rhs.ctx.save;
        rim_keys = rhs.rim_keys;
        rim = rhs.rim;
        undo = rhs.undo;
    }

    private this(Range range, const Flag!"undo" undo) {
        this.undo = undo;
        rim = -1;
        //auto range_save=_range.save;
        ctx = new RangeContext(range);
        rim_keys = null;
    }

    RimKeyRange selectRim(const uint rim) pure nothrow {
        return RimKeyRange(this, rim);
    }

    RimKeyRange nextRim() pure nothrow {
        return RimKeyRange(this, rim + 1);
    }
    /**
     * Checks if all the archives in the range are of the type REMOVE
     * Params:
     *   get_type = archive type get function
     * Returns: true if all the archives are removes
     */
    version (none) bool onlyRemove(const GetType get_type) const pure {
        return current
            .all!(a => get_type(a) is Archive.Type.REMOVE);
    }

    pure nothrow {
        /** 
             * Checks if the range only contains one archive 
             * Returns: true range if single
             */
        version (none) bool oneLeft() const @nogc {
            return length == 1;
        }

        /**
             * Checks if the range is empty
             * Returns: true if empty
             */
        bool empty() @nogc {
            return ctx.empty || (rim >= 0) && (rim_keys != ctx.front.fingerprint[0 .. rim + 1]);
        }

        void popFront() {
            if (!empty) {
                ctx.popFront;
            }
        }

        const(Archive) front() {
            return ctx.front;
        }

        /**
             * Force the range to be empty
             */
        version (none) void force_empty() {
            current = null;
        }

        /**
             * Number of archive left in the range
             * Returns: size of the range
             */
        version (none) size_t length() const {
            return range.length + added_archives.length;
        }
    }
    /**
         *  Creates new range at the current position
         * Returns: copy of this range
         */
    RimKeyRange save() pure nothrow {
        return RimKeyRange(this);
    }

    static assert(isInputRange!RimKeyRange);
    static assert(isForwardRange!RimKeyRange);

}

version (unittest) {
    import std.stdio;

    @safe
    void traverse(const(RecordFactory.Recorder) recorder, const bool undo = false) {
        void inner_traverse(RimRange)(RimRange rim_key_range) {
            while (!rim_key_range.empty) {
                if (rim_key_range.oneLeft) {
                    const first = rim_key_range.front;
                    rim_key_range.popFront;
                }
                else if (rim_key_range.front.type == Archive.Type.REMOVE) {
                    writefln("Remove");
                    rim_key_range.front.dump;
                    rim_key_range.popFront;
                }
                else {
                    writefln("Range rim=%d rim_keys=%s", rim_key_range.rim, rim_key_range.rim_keys.hex);
                    rim_key_range.save.each!q{a.dump};
                    inner_traverse(rim_key_range.nextRim);
                }
            }
        }

        inner_traverse(rimKeyRange(recorder));
    }

}

@safe
unittest {
    import std.typecons;
    import std.algorithm.searching : until;
    import tagion.dart.DARTFakeNet;

    const net = new DARTFakeNet;
    auto factory = RecordFactory(net);

    { // Test with ADD's only in the RimKeyRange root (rim == -1)
        const table = [

            0xABCD_1334_5678_9ABCUL,
            0xABCD_1335_5678_9ABCUL,
            0xABCD_1336_5678_9ABCUL, // Archives which add added in to the RimKeyRange
            0xABCD_1334_AAAA_AAAAUL,
            0xABCD_1335_5678_AAAAUL,

        ];
        const documents = table
            .map!(t => DARTFakeNet.fake_doc(t))
            .array;

        { /// identical 
            auto rec_identical = factory.recorder;
            { // empty rim_key_range should not be identical
                auto rim_key_range = rimKeyRange(rec_identical);
                assert(rim_key_range.empty);
                assert(!rim_key_range.identical);
            }
            rec_identical.insert(documents[1], Archive.Type.ADD);
            { // with one archive rim_key_range should be identical
                auto rim_key_range = rimKeyRange(rec_identical);
                assert(!rim_key_range.empty);
                assert(!rim_key_range.identical);
                assert(!rim_key_range.selectRim(00).identical);
            }
            rec_identical.insert(documents[1], Archive.Type.REMOVE);
            { // with two archives one ADD and one REMOVE with same fingerprint should be identical
                auto rim_key_range = rimKeyRange(rec_identical);
                assert(!rim_key_range.empty);
                assert(!rim_key_range.identical);
                assert(rim_key_range.selectRim(00).identical);
            }

            rec_identical.insert(documents[2], Archive.Type.ADD);
            { // If not all the archives have the with same fingerprint should be identical
                auto rim_key_range = rimKeyRange(rec_identical);
                assert(!rim_key_range.empty);
                assert(!rim_key_range.identical);
                assert(!rim_key_range.selectRim(00).identical);
            }

        }
        // Create a recorder from the first 9 documents 
        auto rec = factory.recorder(documents.take(3), Archive.Type.ADD);
        { // Check the the rim-key range is the same as the recorder
            /*
            Archive abcd133456789abc ADD
            Archive abcd133556789abc ADD
            Archive abcd133656789abc ADD
            */
            auto rim_key_range = rimKeyRange(rec);
            auto rim_key_range_saved = rim_key_range.save;
            assert(equal(rec[].map!q{a.fingerprint}, rim_key_range.map!q{a.fingerprint}));
            // Check save in forward-range
            assert(equal(rec[].map!q{a.fingerprint}, rim_key_range_saved.map!q{a.fingerprint}));
        }

        { // Add one to the rim_key range and check if it is range is ordered correctly
            auto rim_key_range = rimKeyRange(rec);
            auto rec_copy = rec.dup;
            rec_copy.insert(documents[3], Archive.Type.ADD);
            rim_key_range.add(rec.archive(documents[3], Archive.Type.ADD));
            /*
            Archive abcd133456789abc ADD
            Archive abcd1334aaaaaaaa ADD <- This has been added in between
            Archive abcd133556789abc ADD
            Archive abcd133656789abc ADD
            */
            auto rim_key_range_saved = rim_key_range.save;
            assert(equal(rec_copy[].map!q{a.fingerprint}, rim_key_range.map!q{a.fingerprint}));
            // Check save in forward-range
            assert(equal(rec_copy[].map!q{a.fingerprint}, rim_key_range_saved.map!q{a.fingerprint}));

        }

        { // Add two to the rim_key range and check if it is range is ordered correctly
            auto rim_key_range = rimKeyRange(rec);
            auto rec_copy = rec.dup;
            rim_key_range.add(rec.archive(documents[3], Archive.Type.ADD));
            rim_key_range.add(rec.archive(documents[4], Archive.Type.ADD));
            /*
            Archive abcd133456789abc ADD 
            Archive abcd1334aaaaaaaa ADD <- This has beend added
            Archive abcd133556789abc ADD 
            Archive abcd13355678aaaa ADD <- This has been added
            Archive abcd133656789abc ADD 
            */
            rec_copy.insert(documents[3 .. 5], Archive.Type.ADD);

            auto rim_key_range_saved = rim_key_range.save;
            assert(equal(rec_copy[].map!q{a.fingerprint}, rim_key_range.map!q{a.fingerprint}));
            // Check save in forward-range
            assert(equal(rec_copy[].map!q{a.fingerprint}, rim_key_range_saved.map!q{a.fingerprint}));

        }
    }
    {
        const table = [

            ulong.min, // 0                      |00|..
            //00 01 02  03   ........
            0xAB_CC_13_34_56789ABCUL, // 1    |AB|CC|..
            0xAB_CD_13_35_56789ABCUL, // 2    |AB|CD|13|..
            0xAB_CD_13_36_56789ABCUL, // 3    |AB|CD|14|..
            //00 01 02 03  04  ........           00 01 02 03 04  
            0xAB_CD_13_37_56_789ABCUL, // 4    |AB|CD|13|37|56|..
            0xAB_CD_13_37_58_789ABCUL, // 5    |AB|CD|13|37|58|..
            0xAB_CD_13_37_60_789ABCUL, // 6    |AB|CD|13|37|60|..
            //00 01 02 03 04 05  06  ...          00 01 02 03 04 05 06  
            0xAB_CD_13_37_69_78_9B_BCUL, // 7  |AB|CD|13|37|69|78|9B|..
            0xAB_CD_13_37_69_78_9C_BEUL, // 8  |AB|CD|13|37|69|78|9C|.. 
            0xAB_CD_13_37_69_78_9D_BFUL, // 9  |AB|CD|13|37|69|78|9D|.. 

            ulong.max, // 11 |FF|..
            // Archives which add added in to the RimKeyRange
            0xAB_CD_1334_AAAA_AAAAUL,
            0xAB_CD_1335_5678_AAAAUL,

        ];
        const documents = table
            .map!(t => DARTFakeNet.fake_doc(t))
            .array;

        auto rec = factory.recorder(
                documents
                .until!(doc => doc == DARTFakeNet.fake_doc(ulong.max))(No.openRight),
                Archive.Type.ADD);

        version (none) { /// Check selectRim
            auto rim_key_range = rimKeyRange(rec);
            { // Check the range lengths of rim = 00 
                auto rim_key_copy = rim_key_range.save;
                const rim = 00;
                assert(rim_key_copy.selectRim(rim).identical);
                assert(rim_key_copy.selectRim(rim).walkLength == 1);
                assert(rim_key_copy.selectRim(rim).walkLength == 9);
                assert(rim_key_copy.selectRim(rim).walkLength == 1);
            }

            { // Check the range lengths of rim = 01 
                auto rim_key_copy = rim_key_range.save;
                const rim = 01;
                assert(rim_key_copy.selectRim(rim).walkLength == 1);
                assert(rim_key_copy.selectRim(rim).walkLength == 1);
                assert(rim_key_copy.selectRim(rim).walkLength == 8);
                assert(rim_key_copy.selectRim(rim).walkLength == 1);
            }

        }
        const rec_len = rec.length;
        // Checks that the 
        rec.insert(documents[3], Archive.Type.REMOVE);
        rec.insert(documents[5], Archive.Type.REMOVE);

        {
            auto rim_key_range = rimKeyRange(rec);
            traverse(rec);
        }

        { //
            auto rim_key_range = rimKeyRange(rec[]);
            traverse(rec, true);
        }

    }

}

/*
Archive 00000000eca47f6c000000000000000000000000000000000000000000000000 ADD 7FB6D8B0BF40
Archive 0000857d724359c0000000000000000000000000000000000000000000000000 ADD 7FB6D8B0BFC0
Archive 226b8f02cdf58b17000000000000000000000000000000000000000000000000 ADD 7FB6D8B183C0
Archive 264462670b047457000000000000000000000000000000000000000000000000 ADD 7FB6D8B181C0
Archive 3a4b19acadb38259000000000000000000000000000000000000000000000000 ADD 7FB6D8B18340
Archive 4b4d46990ab7aeff000000000000000000000000000000000000000000000000 ADD 7FB6D8B18040
Archive 57a0159df5522c06000000000000000000000000000000000000000000000000 ADD 7FB6D8B180C0
Archive 8715fb635891de6d000000000000000000000000000000000000000000000000 ADD 7FB6D8B18140
Archive 9efb5341ed4f7037000000000000000000000000000000000000000000000000 ADD 7FB6D8B18240
Archive df2dede8a0350f3d000000000000000000000000000000000000000000000000 ADD 7FB6D8B182C0
*/
