module tagion.dart.RimKeyRange;
import std.range;
import tagion.dart.Recorder;
import std.traits : ReturnType;
import std.random;
import std.algorithm : filter, map, joiner;
import std.stdio : writefln;


auto filterArchive(ref Archive[] current) pure nothrow {

    static auto filterArchivesByType(ref Archive[] current, const Archive.Type type) pure nothrow {
        return current.filter!(a => a.type == type);
    }
    return current;
}


// Range over a Range with the same key in the a specific rim
@safe
struct RimKeyRange {
    protected Archive[] current;
    protected ReturnType!filterArchive archive_range;

    version(none) {
        @disable this();

        protected this(Archive[] current) pure nothrow {
            this.current = current;

            this.archive_range = filterArchive(this.current);        
        }
    }

    this(Range)(ref Range range, const uint rim) {
        if (!range.empty) {
            immutable key = range.front.fingerprint.rim_key(rim);
            static if (is(Range == RimKeyRange)) {
                auto reuse_current = range.current;
                /** 
                    * Builds the range going recursively through all keys in rim. 
                    * When the range is empty and the rim key is no longer a fingerprint. Then we return.
                    * Params:
                    *   range = The range we are popping through
                    *   no = used for getting the length of the range
                    */
                void build(ref Range range, const uint no = 0) @safe {
                    if (!range.empty && (range.front.fingerprint.rim_key(rim) is key)) {
                        auto a = range.front;
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
            else {
                void build(ref Range range, const uint no = 0) @safe {
                    if (!range.empty && (range.front.fingerprint.rim_key(rim) is key)) {
                        auto a = range.front;
                        range.popFront;
                        build(range, no + 1);
                        (() @trusted { current[no] = cast(Archive) a; })();
                    }
                    else {
                        current = new Archive[no];
                    }
                }
                build(range);
            }
        }
        archive_range = filterArchive(current);

    }

    /**
    * Checks if all the archives in the range are of the type REMOVE
    * Params:
    *   get_type = archive type get function
    * Returns: true if all the archives are removes
    */
    bool onlyRemove(const GetType get_type) pure {
        return !archive_range.empty && archive_range.front.type == Archive.Type.REMOVE;
    }

    @nogc pure nothrow {
        /** 
            * Checks if the range only contains one archive 
            * Returns: true range if single
            */
        bool oneLeft() {
            return archive_range.take(2).walkLength == 1;
        }

        /**
            * Checks if the range is empty
            * Returns: true if empty
            */
        bool empty() {
                return archive_range.empty;
        }

        /**
            *  Progress one archive
            */
        void popFront() {
            archive_range.popFront;
        }

        /**
            * Gets the current archive in the range
            * Returns: current archive and return null if the range is empty
            */
        Archive front() {
            return archive_range.front;
        }

        /**
            * Force the range to be empty
            */
        void force_empty() {
            archive_range = archive_range.init;
            current = null;
        }

        /**
            * Number of archive left in the range
            * Returns: size of the range
            */
        
        size_t length() {
            return archive_range.save.walkLength;
        }
    }
    /**
        *  Creates new range at the current position
        * Returns: copy of this range
        */
    RimKeyRange save() pure nothrow {
        RimKeyRange result;
        result.current = this.current;
        result.archive_range = this.archive_range.save;

        return result;
    }

}

unittest {
    import std.format;
    import tagion.hibon.HiBONJSON;
    import tagion.dart.DARTFakeNet;
    import tagion.utils.Miscellaneous : toHex = toHexString;

    import tagion.utils.Random;
    
    auto net = new DARTFakeNet;


    auto getDocs(const ulong random_number, const uint amount) {
        auto start = Random!ulong(random_number);
        auto rand_range = recurrence!(q{a[n-1].drop(1)})(start);

        auto rand_range_result = rand_range
                            .take(amount)
                            .map!q{a.take(1)}
                            .joiner; 
        return rand_range_result.map!(r => DARTFakeNet.fake_doc(r));
    }
    

    auto archives_ADD = getDocs(0x1234, 100).array.map!(d => new Archive(net, d, Archive.Type.ADD));
    auto archives_REMOVE = getDocs(0x1234, 100).array.map!(d => new Archive(net, d, Archive.Type.REMOVE));
    
    {
        auto archives = chain(archives_ADD, archives_REMOVE);
        // foreach(archive; archives) {
        //     writefln("%s", archive);
        // }
    }

    {
        auto archives = chain(archives_REMOVE, archives_ADD);
    }

    // {
    //     auto archives = chain(archives_ADD, archives_REMOVE).array.randomShuffle(MinstdRand0(45));
    // }

    

}