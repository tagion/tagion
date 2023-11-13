/// This module handels the rim selector used in the DART modify function
module tagion.dart.RimKeyRange;

import std.algorithm;
import std.range;
import std.traits;
import std.container.array;
import std.typecons : Flag, Yes, No;

import tagion.dart.Recorder : RecordFactory, Archive, GetType, Neutral, Flip;
import tagion.basic.Types : isBufferType, Buffer;
import tagion.utils.Miscellaneous : hex;
import tagion.basic.Debug;

/**
 * Gets the rim key from a buffer
 *
 * Returns;
 *     fingerprint[rim]
 */
@safe
ubyte rim_key(F)(F rim_keys, const uint rim) pure if (isBufferType!F) {
    return rim_keys[rim];
}

/**
 * Creates a rim selector from a range
 * Params:
 *   range = range to be used
 *   undo = Yes if the range should be undone
 * Returns: 
 */
@safe
RimKeyRange!Range rimKeyRange(Range)(Range range, const Flag!"undo" undo = No.undo, const GetType get_type = null)
        if (isInputRange!Range && is(ElementType!Range : const(Archive))) {
    return RimKeyRange!Range(range, undo, get_type);
}

/**
 * Creates a rim selector range from a Recorder
 * Params:
 *   rec = recorder 
 *   undo = Yes of the recorder should be undone
 */
@safe
auto rimKeyRange(Flag!"undo" undo = No.undo)(const(RecordFactory.Recorder) rec) {
    static if (undo) {
        return rimKeyRange(rec[].retro, undo, Flip);
    }
    else {
        return rimKeyRange(rec[], undo);
    }
}

/// Range over a Range with the same key in the a specific rim
@safe
struct RimKeyRange(Range) if (isInputRange!Range && isImplicitlyConvertible!(ElementType!Range, const(Archive))) {
    alias archive_less = RecordFactory.Recorder.archive_sorted;
    @safe
    final class RangeContext {
        Range range;
        const(Archive)[] _added_archives;
        AdderRange added_range;
        const GetType get_type;
        pure nothrow {
            this(Range range, const GetType _get_type = null) {
                this.range = range;
                added_range = new AdderRange(0);
                get_type = (_get_type) ? _get_type : Neutral;
            }

            protected this(RangeContext rhs, const GetType _get_type = null) {
                _added_archives = rhs._added_archives;
                range = rhs.range;
                added_range = new AdderRange(rhs.added_range.index);
                get_type = (_get_type) ? _get_type : rhs.get_type;
            }

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
            const(Archive) front()
            out (archive) {
                assert(!archive.dart_index.empty);
            }
            do {
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

            Archive.Type type() {
                if (!added_range.empty && !range.empty) {
                    if (archive_less(added_range.front, range.front)) {
                        return added_range.front.type;
                    }
                    return get_type(range.front);
                }
                if (!range.empty) {
                    return get_type(range.front);
                }
                else if (!added_range.empty) {
                    return get_type(added_range.front);
                }
                return Archive.Type.NONE;

            }
        }
        @safe @nogc
        final class AdderRange {
            size_t index;
            pure nothrow {
                this(size_t index) {
                    this.index = index;
                }

                bool empty() {
                    return index >= _added_archives.length;
                }

                const(Archive) front() {
                    return _added_archives[index];
                }

                void popFront() {
                    if (!empty) {
                        index++;
                    }
                }
            }
        }
    }

    @disable this();
    protected RangeContext ctx;
    const Buffer rim_keys;
    const int rim;
    const Flag!"undo" undo;

    pure nothrow {
        /**
         * Construct an copy of an existing range
         * Params:
         *   rhs = Range to be copied
         *   rim = Sets the rim for the new copy
         */
        private this(RimKeyRange rhs, const uint rim) {
            ctx = rhs.ctx;
            if (rim + 1 > rhs.front.dart_index.length) {
                __write("rim=%d  size=%d %(%02X %)", rim, rhs.front.dart_index.length, rhs.front.dart_index);
            }
            rim_keys = (rhs.empty) ? Buffer.init : rhs.front.dart_index[0 .. rim + 1];
            this.rim = rim & int.max;
            undo = rhs.undo;
        }

        /**
         * Construct an copy of an existing range
         * Params:
         *   rhs = Range to be copied
         */
        private this(RimKeyRange rhs) {
            ctx = rhs.ctx.save;
            rim_keys = rhs.rim_keys;
            rim = rhs.rim;
            undo = rhs.undo;
        }
        /**
         * 
         * Params:
         *   range = Range to be selected from 
         *   undo = if Yes it will revert the range
         *   get_type = set the archive type set function
         */
        private this(Range range, const Flag!"undo" undo, const GetType get_type = null) {
            this.undo = undo;
            rim = -1;
            //auto range_save=_range.save;
            ctx = new RangeContext(range, get_type);
            rim_keys = null;
        }

        /**
         * Checks if only one archives are left in the range
         * Returns: 
         */
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

        /**
         * Adds an archive to the current range
         * The archives should be in the same rim
         * Params:
         *   archive = the added element
         */
        void add(const(Archive) archive)
        in ((rim < 0) || (rim_keys == archive.dart_index[0 .. rim + 1]))
        do 
        {
            ctx._added_archives ~= archive;
        }

        /**
         * Create a new range from this range at the rim
         * Params:
         *   rim = the rim to be use in the new range
         * Returns: Range for the selected rim 
         */
        RimKeyRange selectRim(const uint rim) {
            return RimKeyRange(this, rim);
        }

        /**
         * Create a new range from this range at the next rim 
         * 
         * Returns: Next range an the rim+1 
         */
        RimKeyRange nextRim() {
            return RimKeyRange(this, rim + 1);
        }

        /**
         * Checks if the range is empty
         * Returns: true if empty
         */
        bool empty() @nogc {
            return ctx.empty || (rim >= 0) && (rim_keys != ctx.front.dart_index[0 .. rim + 1]);
        }

        /**
         * Progress to the next archive in the list 
         */
        void popFront() {
            if (!empty) {
                ctx.popFront;
            }
        }

        /**
         * 
         * Returns: first archive in the range
         */
        const(Archive) front() {
            return ctx.front;
        }

        /**
         * 
         * Returns: first archive in the range
         */
        const(Archive.Type) type() {
            return ctx.type;
        }

        /**
         * Creates new range at the current position
         * Returns: copy of this range
         */
        RimKeyRange save() {
            return RimKeyRange(this);
        }
    }
    static assert(isInputRange!RimKeyRange);
    static assert(isForwardRange!RimKeyRange);

}

version (unittest) {
    import std.typecons : Tuple;
    import tagion.dart.DARTBasic : DARTIndex;

    alias TraverseData = Tuple!(DARTIndex, "dart_index", Archive.Type, "type");
    @safe
    TraverseData[] traverse(
            const(RecordFactory.Recorder) recorder,
            const Flag!"undo" undo = No.undo) {
        TraverseData[] result;

        void inner_traverse(RimRange)(RimRange rim_key_range) {
            while (!rim_key_range.empty) {
                if (rim_key_range.oneLeft) {
                    result ~= TraverseData(rim_key_range.front.dart_index, rim_key_range.type);
                    rim_key_range.popFront;
                }
                else if (rim_key_range.front.type == Archive.Type.REMOVE) {
                    result ~= TraverseData(rim_key_range.front.dart_index, rim_key_range.type);
                    rim_key_range.popFront;
                }
                else {
                    inner_traverse(rim_key_range.nextRim);
                }
            }
        }

        if (undo) {
            inner_traverse(rimKeyRange!(Yes.undo)(recorder));
        }
        else {
            inner_traverse(rimKeyRange(recorder));

        }
        return result;
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
            assert(equal(rec[].map!q{a.dart_index}, rim_key_range.map!q{a.dart_index}));
            // Check save in forward-range
            assert(equal(rec[].map!q{a.dart_index}, rim_key_range_saved.map!q{a.dart_index}));
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
            assert(equal(rec_copy[].map!q{a.dart_index}, rim_key_range.map!q{a.dart_index}));
            // Check save in forward-range
            assert(equal(rec_copy[].map!q{a.dart_index}, rim_key_range_saved.map!q{a.dart_index}));

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
            assert(equal(rec_copy[].map!q{a.dart_index}, rim_key_range.map!q{a.dart_index}));
            // Check save in forward-range
            assert(equal(rec_copy[].map!q{a.dart_index}, rim_key_range_saved.map!q{a.dart_index}));

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

        { /// Check selectRim
            auto rim_key_range = rimKeyRange(rec);
            { // Check the range lengths of rim = 00 
                auto rim_key_copy = rim_key_range.save;
                const rim = 00;
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
        rec.insert(documents[rec_len], Archive.Type.REMOVE);
        rec.insert(documents[rec_len + 1], Archive.Type.REMOVE);

        { // Check that the order of the archives are the same in the rim-key-range
            const result = traverse(rec);
            assert(equal(rec[].map!q{a.dart_index}, result.map!q{a.dart_index}));
            assert(equal(rec[].map!q{a.type}, result.map!q{a.type}));

        }

        { // Checks the undo
            // The order should be reversed and the type should be flipped ADD<->REMOVE
            const result = traverse(rec, Yes.undo);
            assert(equal(rec[].retro.map!q{a.dart_index}, result.map!q{a.dart_index}));
            assert(equal(rec[].retro.map!(a => Flip(a)), result.map!q{a.type}));
        }

    }

}
