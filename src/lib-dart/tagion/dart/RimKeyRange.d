module tagion.dart.RimKeyRange;

import std.stdio;
import std.algorithm;
import std.range;
import std.traits;

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
Range rimKeyRange(Range)(Range range, const uint rim) {
    return RimKeyRangeT!Range(range, rim);
}

// Range over a Range with the same key in the a specific rim
@safe
struct RimKeyRange(Range) if (isInputeRange!Range && isImplicitlyConvertible!(ElementType!Range, Archive)) {
    protected Archives added_archives;
    protected Range range;
    const ubyte rim_key;
    const uint rim;
    const GetType get_type;
    @disable this();
    version (none) protected this(Archive[] current) pure nothrow @nogc {
        this.current = current;
    }

    version (none) this(ref RimKeyRange range, const uint rim) {
        this.rim = rim;
        if (!range.empty) {
            rim_key = range.front.fingerprint.rim_key(rim);
            auto reuse_current = range.current;
            void build(ref RimKeyRange range, const uint no = 0) @safe {
                if (!range.empty && (range.front.fingerprint.rim_key(rim) is rim_key)) {
                    range.popFront;
                    build(range, no + 1);
                }
                else {
                    // Reuse the parent current
                    current = reuse_current[0 .. no];
                }
            }

            build(range);
        }
    }

    void add(Archive archive)
    in (rim_key == archive.front.fingerprint(rim))
    do {
        added_archives.insert(archive);
    }

    this(Range)(Range _range, const uint rim, const GetType get_type) {
        added_archives = new Archives;
        this.get_type = get_type;
        this.rim = rim;
        range = _range;
        if (!range.empty) {
            rim_key = range.front.fingerprint.rim_key(rim);
        }
        /+ 
            Archive[] _current;
            void build(ref Range range, const uint no = 0) @safe {
                if (!range.empty && (range.front.fingerprint.rim_key(rim) is rim_key)) {
                    auto a = range.front;
                    range.popFront;
                    build(range, no + 1);
                    (() @trusted { _current[no] = cast(Archive) a; })();
                }
                else {
                    _current = new Archive[no];
                }
            }

            auto _range = range;
            build(_range);
            writefln("Rim key before %02X", range.front.fingerprint.rim_key(rim));
            current = refRange(&range)
                .until!(a => a.fingerprint.rim_key(rim) !is rim_key)
                .map!(a => cast(Archive) a)
                .array;
            version (none)
                if (_range.empty) {
                    writefln("Rim key after %02X", _range.front.fingerprint.rim_key(rim));
                }
            writefln("current");

            writefln("rim_key=%02X rim=%d", rim_key, rim);
            //current.each!(a => writeln(a.fingerprint.toHex));
            writefln("_current");
            //_current.each!(a => writeln(a.fingerprint.toHex));
            //assert(equal(current, _current));
            //                range=_range;

        }
        +/
    }

    /**
     * Checks if all the archives in the range are of the type REMOVE
     * Params:
     *   get_type = archive type get function
     * Returns: true if all the archives are removes
     */
    bool onlyRemove(const GetType get_type) const pure {
        return current
            .all!(a => get_type(a) is Archive.Type.REMOVE);
    }

    @nogc pure nothrow {
        /** 
             * Checks if the range only contains one archive 
             * Returns: true range if single
             */
        bool oneLeft() const {
            return current.length == 1;
        }

        /**
             * Checks if the range is empty
             * Returns: true if empty
             */
        bool empty() const {
            return range.empty && added_archives.empty;
        }

        alias archive_less = RecordFactory.Recorder.archive_sorted;
        /**
             *  Progress one archive
             */
        void popFront() {
            if (!added_archives.empty && !range.empty) {
                if (archive_less(added_archives.front, range.front)) {
                    added_archive.popFront;
                }
                else {
                    range.popFront;
                }
            }
            else if (!range.empty) {
                range.popFront;
            }
            else if (!added_archives.empty) {
                added_archive.popFront;
            }
        }

        /**
             * Gets the current archive in the range
             * Returns: current archive and return null if the range is empty
             */
        inout(Archive) front() inout {
            if (!added_archives.empty && !range.empty) {
                if (archive_less(added_archives.front, range.front)) {
                    return added_archive.front;
                }
                    return range.front;
            }
            if (!range.empty) {
                return range.front;
            }
            else if (!added_archives.empty) {
                return added_archive.front;
            }
            return Archive.init;
       }

        /**
             * Force the range to be empty
             */
        void force_empty() {
            current = null;
        }

        /**
             * Number of archive left in the range
             * Returns: size of the range
             */
        size_t length() const {
            return current.length;
        }
    }
    /**
         *  Creates new range at the current position
         * Returns: copy of this range
         */
    version (none) RimKeyRange save() pure nothrow @nogc {

        return RimKeyRange(current);
    }

}

@safe 
unittest {
    
}
