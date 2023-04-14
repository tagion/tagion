module tagion.dart.RimKeyRange;

import std.stdio;
import std.algorithm;
import std.range;
import std.traits;
import std.container.array;
import tagion.dart.Recorder;
import tagion.basic.Types : isBufferType;
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
RimKeyRange!Range rimKeyRange(Range)(Range range, const GetType get_type = Neutral)
        if (isInputRange!Range && isImplicitlyConvertible!(ElementType!Range, Archive)) {
    return RimKeyRange!Range(range, get_type);
}

@safe
auto rimKeyRange(Rec)(Rec rec, const GetType get_type = Neutral)
        if (isImplicitlyConvertible!(Rec, const(RecordFactory.Recorder))) {

    return rimKeyRange(rec[], get_type);
}

// Range over a Range with the same key in the a specific rim
@safe
struct RimKeyRange(Range) if (isInputRange!Range && isImplicitlyConvertible!(ElementType!Range, Archive)) {
    alias archive_less = RecordFactory.Recorder.archive_sorted;

    //alias Archives=RecordFactory.Recorder.Archives;
    @safe
    final class RangeContext {
        int count;
        Range range;
        Archive[] _added_archives;
        AdderRange added_range;
        this(Range range) pure nothrow {
            count = 5;
            this.range = range;
            added_range = new AdderRange(0);
        }

        protected this(RangeContext rhs) {
            count = 5;
            _added_archives = rhs._added_archives;
            range = rhs.range;
            added_range = new AdderRange(added_range.index);
        }

        pure nothrow {
            /**
             * Checks if the range is empty
             * Returns: true if empty
             */
            bool empty() const @nogc {
                __write("range.empty=%s added_range.empty=%s count=%d", range.empty, added_range.empty, count);
                if (count < 0)
                    return true;
                return range.empty && added_range.empty;
            }

            /**
             *  Progress one archive
             */
            void popFront() {
                count--;
                __write("popFront %d", count);
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
            Archive front() {
                if (!added_range.empty && !range.empty) {
                    if (archive_less(added_range.front, range.front)) {
                        return added_range.front;
                    }
                    return range.front;
                }
                if (!range.empty) {
                    __write("front !range.empty");
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

    protected RangeContext ctx;
    const ubyte rim_key;
    const int rim;
    const GetType get_type;
    @disable this();

    void add(Archive archive)
    in (rim_key == archive.fingerprint.rim_key(rim))
    do {
        ctx._added_archives ~= (archive);
    }

    private this(RimKeyRange rhs, const int rim) {
        ctx = rhs.ctx;
        rim_key = rhs.rim_key;
        this.rim = rim;
        get_type = rhs.get_type;

    }

    private this(Range range, const GetType get_type) {

        this.get_type = get_type;
        rim = -1;
        //auto range_save=_range.save;
        ctx = new RangeContext(range);
        rim_key = 0;
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
            __write("...empty ctx.empty=%s count=%d", ctx.empty, ctx.count);
            if (ctx.empty) {
                return true;
            }
            __write("rim_key %s", (rim >= 0) && (rim_key != ctx.front.fingerprint.rim_key(rim)));

            return (rim >= 0) && (rim_key != ctx.front.fingerprint.rim_key(rim));
        }

        void popFront() {
            __write("...popFront");
            if (!empty) {
                ctx.popFront;
            }
        }

        Archive front() {
            __write("... ... front ctx.empty %s", ctx.empty);
            __write("... ... front empty %s", empty);
            __write("... ... ctx.front %s", ctx.front is null);
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
        return this;
    }

    static assert(isInputRange!RimKeyRange);
    static assert(isForwardRange!RimKeyRange);

}

@safe
unittest {
    import std.stdio;
    import tagion.dart.DARTFakeNet;

    const net = new DARTFakeNet;
    auto factory = RecordFactory(net);

    const table = [

        0xABCD_1334_5678_9ABCUL,
        0xABCD_1335_5678_9ABCUL,
        0xABCD_1336_5678_9ABCUL,

        // Archives which add added in to the RimKeyRange
        0xABCD_1334_AAAA_AAAAUL,
        0xABCD_1335_5678_AAAAUL,

    ];
    const documents = table
        .map!(t => DARTFakeNet.fake_doc(t))
        .array;

    { // Test with ADD's only
        writefln("--- RimKeyRange");
        // Create a recorder from the first 9 documents 
        auto rec = factory.recorder(documents.take(3), Archive.Type.ADD);
        { // Check the the rim-key range is the same as the recorder
            /*
            Archive abcd133456789abc ADD
            Archive abcd133556789abc ADD
            Archive abcd133656789abc ADD
            */
            auto rim_key_range = rimKeyRange(rec);
            rec[].each!q{a.dump};
            writefln("xxxx ");
            rim_key_range.each!q{a.dump};
            writefln("xxxx ");
            rim_key_range.each!q{a.dump};
            writefln("xxxx ");
            assert(equal(rec[].map!q{a.fingerprint}, rim_key_range.map!q{a.fingerprint}));
            // Check forward save
            auto rim_copy = rim_key_range.save;
            rim_key_range.popFront;
            rim_key_range.each!q{a.dump};
            writefln("xx");
            rim_copy.popFront;
            rim_copy.each!q{a.dump};

            writefln("xx");

            assert(equal(rim_copy.map!q{a.fingerprint}, rim_key_range.map!q{a.fingerprint}));
        }
        version (none) { // Add one to the rim_key range and check if it is range is ordered correctly
            auto rim_key_range = rimKeyRange(rec);
            auto rec_copy = rec.dup;
            rec_copy.insert(documents[3], Archive.Type.ADD);
            writefln("Recorder add 10");
            rec_copy.dump;
            rim_key_range.add(rec.archive(documents[3], Archive.Type.ADD));
            /*
            Archive abcd133456789abc ADD
            Archive abcd1334aaaaaaaa ADD <- This has been added in between
            Archive abcd133556789abc ADD
            Archive abcd133656789abc ADD
            */
            writefln("Recorder add 10");
            rim_key_range.save.each!q{a.dump};
            //assert(equal(rec_copy[].map!q{a.fingerprint}, rim_key_range.map!q{a.fingerprint}));
            writefln("Recorder add 10-");
            rim_key_range.each!q{a.dump};
            writefln("Recorder add 10X");
            rim_key_range.save.each!q{a.dump};

        }

        version (none) { //  Add two to the rim_key range and check if it is range is ordered correctly
            auto rim_key_range = rimKeyRange(rec);
            auto rec_copy = rec.dup;

            rec_copy.insert(documents[3 .. 5], Archive.Type.ADD);
            writefln("Recorder add 11");
            rec_copy.dump;
            rim_key_range.add(rec.archive(documents[3], Archive.Type.ADD));
            rim_key_range.add(rec.archive(documents[4], Archive.Type.ADD));

            writefln("Recorder add 11");
            rim_key_range.save.each!q{a.dump};
            assert(equal(rec_copy[].map!q{a.fingerprint}, rim_key_range.map!q{a.fingerprint}));

        }

        // Checks that the 
        { // 

        }
    }
}
