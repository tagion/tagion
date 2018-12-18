module tagion.vault.DARTAngle;

import tagion.hashgraph.GossipNet : SecureNet;
import tagion.utils.BSON : HBSON, Document;
import tagion.hashgraph.ConsensusExceptions;

import tagion.Keywords;
import std.conv : to;

import tagion.Base : cutHex;
import tagion.crypto.Hash : toHexString;
import std.stdio;
@safe
void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) {
    if (!flag) {
        throw new EventConsensusException(code, file, line);
    }
}

@safe
uint cover(const uint n) pure nothrow {
    uint local_cover(immutable uint width, immutable uint step) pure nothrow {
        immutable uint result=1 << width;
        if ( step != 0 ) {
            if ( result > n ) {
                if ( (result >> 1) >= n ) {
                    return local_cover(width-step, step >> 1);
                }
            }
            else if ( result < n ) {
                return local_cover(width+step, step >> 1);
            }
        }
        return result;
    }
    immutable width=(uint.sizeof*8) >> 1;
    return local_cover(width, width >> 1);
}

unittest {
    assert(cover(0x1FFF) == 0x2000);
    assert(cover(0x1200) == 0x2000);
    assert(cover(0x210) == 0x400);
    assert(cover(0x1000) == 0x1000);
}


@safe
class DARTAngle {
    private SecureNet _net;
    private ushort _from_sector;
    private ushort _to_sector;
    private Bucket[] _root_buckets;
    enum bucket_max=1 << (ubyte.sizeof*8);
    enum uint bucket_rim=cast(uint)ushort.sizeof;
    enum sector_max = ushort.max;

    this(SecureNet net, const ushort from_sector, const ushort to_sector) {
        _net=net;
        _from_sector=from_sector;
        _to_sector=to_sector;
        _root_buckets=new Bucket[calc_sector_size(_from_sector, _to_sector)];
    }

    ushort root_sector(immutable(ubyte[]) data) pure const nothrow {
        return data[1] | (data[0] << 8);
    }

    ushort sector_to_index(const ushort sector) const pure nothrow {
        return (sector-_from_sector) & ushort.max;
    }

    void add(ArchiveTab archive) {
        immutable sector=root_sector(archive.fingerprint);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            if ( _root_buckets[index] is null ) {
                _root_buckets[index]=new Bucket();
            }
            _root_buckets[index].add(archive, bucket_rim);
        }
    }

    void add(immutable(ubyte[]) data) {
        auto archive=new ArchiveTab(_net, data);
        add(archive);
    }

    void remove(const ArchiveTab archive) {
        immutable sector=root_sector(archive.fingerprint);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            if ( _root_buckets[index] ) {
                Bucket.remove(_root_buckets[index], archive);
            }
        }
    }

    void remove(immutable(ubyte[]) data) {
        auto archive=new ArchiveTab(_net, data);
        remove(archive);
    }

    ArchiveTab opIndex(immutable(ubyte[]) key) {
        immutable sector=root_sector(key);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            if ( _root_buckets[index] ) {
                return _root_buckets[index].find(key, bucket_rim);
            }
        }
        return null;
    }

    Bucket get(immutable(ubyte[]) key) {
        Bucket result;
        immutable sector=root_sector(key);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            result=_root_buckets[index];
        }
        return result;
    }

    static class ArchiveTab {
        immutable(ubyte[])  data;
        immutable(ubyte[])  fingerprint;
        Document document() const {
            return Document(data);
        }
        this(SecureNet net, immutable(ubyte[]) data) {
            fingerprint=net.calcHash(data);
            this.data=data;
        }
        // private ubyte index(const uint rim) const pure {
        //     return fingerprint[rim];
        // }
    }

    Bucket.Iterator iterator(ushort sector) {
        check(inRange(sector),  ConsensusFailCode.DART_ARCHIVE_SECTOR_NOT_FOUND);
        return _root_buckets[sector_to_index(sector)].iterator(bucket_rim);
    }

    void dump() const {
        immutable uint from=_from_sector;
        immutable uint to=(_to_sector==_from_sector)?_to_sector+sector_max+1:_to_sector;
        foreach(s;from..to) {
            immutable ushort sector=s & sector_max;
            immutable index=sector_to_index(sector);
            if ( _root_buckets[index] ) {
                writefln("Sector %04X", sector);
                _root_buckets[index].dump;
            }
        }
        writeln("###### ##### ######");
    }

    static class Bucket {
        private Bucket[] _buckets;
//        private uint _bucket_size;
        private ArchiveTab _archive;
//        immutable uint rim;
        // immutable size_t init_size;
        // immutable size_t extend;
        private immutable(ubyte)[]  _merkle_root;
        bool isBucket() const pure nothrow {
            return _buckets !is null;
        }

        // uint index() const pure {
        //     return index(rim);
        // }

        private ubyte index(const uint rim) const pure {
        //     in {
        //         assert(_rim <= rim);
        //     }
        // do {
            if ( isBucket ) {
                return _buckets[0].index(rim);
            }
            else {
                return _archive.fingerprint[rim];
            }
        }

        // immutable(ubyte[]) prefix() const pure {
        //     return prefix(rim);
        // }

        immutable(ubyte[]) prefix(immutable uint rim) const pure {
            if ( isBucket ) {
                return _buckets[0].prefix(rim);
            }
            else {
                return _archive.fingerprint[0..rim];
            }
        }

        private uint find_bucket_pos(const int index, const uint rim) const pure
            in {
                assert(index < ubyte.max);
                assert(index >= 0);
            }
        out(pos) {
            assert(pos <= _buckets.length);
        }
        do {
            int find_bucket_pos(immutable int search_j, immutable int division_j) {
                if ( search_j < _buckets.length ) {
                    immutable search_index=_buckets[search_j].index(rim);
                    if ( index == search_index ) {
                        return search_j;
                    }
                    else if ( division_j > 0 ) {
                        if ( index < search_index ) {
                            return find_bucket_pos(search_j-division_j, division_j/2);
                        }
                        else if ( index > search_index ) {
                            return find_bucket_pos(search_j+division_j, division_j/2);
                        }
                    }
                    else if ( index > search_index ) {
                        return search_j+1;
                    }
                }
                else if ( division_j > 0 ) {
                    if ( index > _buckets[$-1].index(rim) ) {
                        return cast(int)_buckets.length;
                    }
                    return find_bucket_pos(search_j-division_j, division_j/2);
                }
                return search_j;
            }
            immutable start_j=cover(cast(int)_buckets.length) >> 1;
            auto result=find_bucket_pos(start_j, start_j);
            if ( result < 0 ) {
                return 0;
            }
            return cast(uint)result;
        }

        version(none)
        unittest {
            import tagion.Base : Buffer;
            import std.typecons;
            static class TestNet : BlackHole!SecureNet {
                override immutable(Buffer) calcHash(immutable(ubyte[]) data) inout {
                    if ( data.length == ulong.sizeof ) {
                        return data;
                    }
                    else {
                        import std.digest.sha : SHA256;
                        import std.digest.digest;
                        return digest!SHA256(data).idup;
                    }
                }
            }
            auto net=new TestNet;

            immutable(ubyte[]) data(const ulong x) {
                import std.bitmanip;
                return nativeToBigEndian(x).idup;
            }
            immutable(ulong[]) table=[
            //  RIM 0 test
                0x20_21_00_10_30_40_50_80,
                0x20_21_01_11_30_40_50_80,
                0x20_21_07_12_30_40_50_80,
                0x20_21_08_0a_30_40_50_80,
                0x20_21_FF_0a_30_40_50_80
                ];

//            import std.algorithm.iteration : map;
            ArchiveTab create(const ulong a) {
                return new ArchiveTab(net, data(a));
            }

            ArchiveTab[table.length] archives;
            foreach(i,t;table) {
                archives[i]=new ArchiveTab(net, data(t));
            }

            writefln("Before");
            //writefln("archives=%s", archives);
            {
//                uint rim=0;
                auto bucket=new Bucket(2);
//                immutable rim=1;
                bucket.insert(new Bucket(archives[1], brim));
                bucket.dump;
                writeln("------- -------");
                bucket.insert(new Bucket(archives[0], rim));
                bucket.dump;
                writeln("------- -------");
                bucket.insert(new Bucket(archives[3], rim));

                bucket.dump;
                writeln("------- -------");

//                alias stringize = map!(to!string);

            }
        }

        static size_t calc_init_size(size_t rim) {
            switch ( rim ) {
            case 0, 1, 2:
                return 16;
                break;
            case 3:
                return 4;
                break;
            default:
                return 1;
            }
        }

        static size_t calc_extend(size_t rim) {
            switch ( rim ) {
            case 0, 1, 2:
                return 16;
                break;
            case 3:
                return 4;
                break;
            default:
                return 1;
            }
        }

        // size_t extend_size() pure const nothrow {
        //     immutable size=_buckets.length+extend;
        //     return (size <= ubyte.max)?size:ubyte.max+1;
        // }

        // size_t grow() {
        //     if ( _bucket_size+1 <= _buckets.length ) {
        //         return _buckets.length;
        //     }
        //     else {
        //         return extend_size;
        //     }
        // }

        version(none)
        private void insert(Bucket b)
            in {
                assert(_archive is null);
                //assert(_buckets);
                assert(b.rim == rim+1);
//                assert(
            }
        do {
//            immutable index=b.index;
            if ( _buckets is null ) {
//                _buckets=new Bucket[init_size];
                _buckets.length=1;
                _buckets[0]=b;
            }
            else {
                immutable pos=find_bucket_pos(b.index(rim));
                writefln("pos=%d index=%02x length=%d rim=%d", pos, b.index(rim), _buckets.length, rim);
//            assert( _buckets[pos].index != index );
                import std.array : insertInPlace;
                _buckets.insertInPlace(pos, b);
            }

            // if ( _bucket_size+1 < _buckets.length ) {
            //     _buckets[pos+1.._bucket_size+1]=_buckets[pos.._bucket_size];
            //     _buckets[pos]=b;
            //     _bucket_size++;
            // }
            // else {
            //     auto new_buckets=new Bucket[grow];
            //     new_buckets[0..pos]=_buckets[0..pos];
            //     new_buckets[pos+1.._bucket_size+1]=_buckets[pos.._bucket_size];
            //     new_buckets[pos]=b;
            //     _buckets=new_buckets;
            //     _bucket_size++;
            // }
        }

        private this() {
//            this.rim=rim;
            // init_size=calc_init_size(rim);
            // extend=calc_extend(rim);
        }

        private this(ArchiveTab archive) {
//            this(rim);
            _archive=archive;
        }

        // private this(ArchiveTab arcive, immutable uint rim) {
        //     this(rim);
        //     this._archive=archive
        // }
        // this(ArchiveTab archive, immutable uint rim) {
        //     this(rim);
        //     _archive=archive;
        // }

        this(Document doc, SecureNet net) {
            //this(doc[Keywords.rim].get!uint);
            if ( doc.hasElement(Keywords.buckets) ) {
                auto buckets_doc=doc[Keywords.buckets].get!Document;
                _buckets=new Bucket[buckets_doc.length];
                foreach(elm; buckets_doc[]) {
                    auto arcive_doc=elm.get!Document;
                    immutable index=elm.key.to!ubyte;
                    // this[index]=new Bucket(arcive_doc, net);
                }
            }
            else if (doc.hasElement(Keywords.tab)) {
                // Fixme check that the Doc is HBSON
                auto arcive_doc=doc[Keywords.tab].get!Document;
                _archive=new ArchiveTab(net, arcive_doc.data);
            }
        }


        enum indent_tab="  ";
        void dump() const {
            dump(2);
        }


        @trusted
        private void dump(const uint rim) const {
            writefln("bucket rim=%d cache=%d capacity=%d", rim, _buckets.length, _buckets.capacity);
            foreach(i, b;_buckets) {
                if ( b.isBucket ) {

                    writef("=>|%s ", b.prefix(rim+1).toHexString);
                    b.dump(rim+1);
                }
                else {
                    writefln("%s|%s b.rim=%d b.index(rim)=%02x  index(rim-1)=%02x", indent_tab, b._archive.fingerprint.toHexString,
                        rim, b.index(rim), index(rim-1));
                }
            }
            writefln("<=|%s rim=%d", prefix(rim).toHexString, rim);
        }

        HBSON toBSON() const {
            auto bson=new HBSON;
            //bson[Keywords.rim]=rim;
            if ( isBucket ) {
                HBSON[] buckets; //=new HBSON;
                foreach(b;_buckets) {
//                    auto b=_buckets[i];
                    buckets~=b.toBSON;
                }
                bson[Keywords.buckets]=buckets;
            }
            else if ( _archive ) {
                bson[Keywords.tab]=_archive.document;
            }
            return bson;
        }

        immutable(ubyte[]) serialize() const {
            return toBSON.serialize;
        }

        private ArchiveTab find(immutable(ubyte[]) key, const uint rim) {
//            writefln("find=%s %x rim=%d isBucket=%s", key.toHexString, key[rim], rim, isBucket);
            if ( isBucket ) {
                immutable pos=find_bucket_pos(key[rim], rim);
//                writefln("\t\tpos=%d bucket_size=%d rim=%d key=0x%x", pos, _buckets.length, rim, key[rim] );
//                dump;
                if ( (pos >= 0) && (pos < _buckets.length) && _buckets[pos] ) {
                    //writefln("\t\trim=%d key=%02x", _buckets[pos].rim, key[_buckets[pos].rim]);
                    return _buckets[pos].find(key, rim+1);
                }
            }
            else if ( _archive && (_archive.fingerprint == key) ) {
                return _archive;
            }
            if ( _archive ) {
                writefln("key=%s fingerprint=%s", key.toHexString, _archive.fingerprint.toHexString);
            }
            return null;
        }

//         void add(ArchiveTab archive) {
//             add(archive, rim);
// //            dump;
//         }

        private void add(ArchiveTab archive, const uint rim) {
            void insert(immutable int pos, ArchiveTab archive) {
                import std.array : insertInPlace;
                _buckets.insertInPlace(pos, new Bucket(archive));
            }

            bool same_index(const int pos, const ubyte index) pure {
                if ( (pos >= 0) && (pos < _buckets.length) ) {
                    return _buckets[pos].index(rim) == index;
                }
                return false;
            }

            _merkle_root=null;
            if ( isBucket ) {
                // immutable child_rim=rim+1;
                immutable index=archive.fingerprint[rim];
                immutable pos=find_bucket_pos(index, rim);

                if ( same_index(pos, index) ) {
                    _buckets[pos].add(archive, rim+1);
                }
                else {
                    insert(pos, archive);
                }
            }
            else if ( _archive is null ) {
                _archive=archive;
            }
            else {
                _buckets=new Bucket[1];
                if ( archive.fingerprint[rim] == _archive.fingerprint[rim] ) {
                    auto temp_bucket=new Bucket();
                    _buckets[0]=temp_bucket;
                    temp_bucket.add(_archive, rim+1);
                    temp_bucket.add(archive, rim+1);
                }
                else {
                    _buckets[0]=new Bucket(_archive);
                    add(archive, rim);
                }
                _archive=null;
            }
        }

        static void remove(ref Bucket bucket, const ArchiveTab archive) {
            bucket=Bucket.remove(bucket, archive, bucket_rim);
        }

        @trusted
        private static Bucket remove(Bucket bucket, const ArchiveTab archive, immutable uint rim) {
            import std.algorithm.mutation : array_remove=remove;
            scope(success) {
                if ( bucket ) {
                    bucket._merkle_root=null;
                }
            }
            if ( bucket.isBucket ) {
                immutable index=archive.fingerprint[rim];
                immutable pos=bucket.find_bucket_pos(index, rim);
                bucket.dump;
                writefln("remove pos=%d index=%02x archive.fingerprint=%s rim=%d length=%d", pos, index, archive.fingerprint.cutHex, rim, bucket._buckets.length);
                check(bucket._buckets[pos] !is null, ConsensusFailCode.DART_ARCHIVE_DOES_NOT_EXIST);
                bucket._buckets[pos]=Bucket.remove(bucket._buckets[pos], archive, rim+1);
                if ( bucket._buckets[pos] is null ) {
                    bucket._buckets=array_remove(bucket._buckets, pos);
                    //bucket._bucket_size--;
                    if ( bucket._buckets.length == 1 ) {
                        if ( !bucket._buckets[0].isBucket ) {
                            auto temp_bucket=new Bucket();
                            temp_bucket._archive=bucket._buckets[0]._archive;
                            bucket.destroy;
                            bucket=temp_bucket;
                        }
                    }
                    else if ( bucket._buckets.length == 0 ) {
                        bucket.destroy;
                        bucket=null;
                    }
                }
            }
            else {
                bucket.destroy;
                bucket=null;
            }
            return bucket;
        }

        immutable(ubyte[]) merkle_root(SecureNet net, const uint rim) {
            if ( _merkle_root ) {
                return _merkle_root;
            }
            else if ( isBucket ) {
                scope auto temp_buckets=new Bucket[bucket_max];
                // string indent;
                // foreach(j;0..rim) {
                //     indent~="\t";
                // }
                foreach(i;0.._buckets.length) {
                    auto b=_buckets[i];
                    temp_buckets[b.index(rim)]=b;
                    // writefln("%s %d key=%s rim=%d key=%s data=%s bucket=%s", indent, i, b.index(rim), rim, b._archive.fingerprint.cutHex, b._archive.data.cutHex, b.isBucket);

                }
                _merkle_root=sparsed_merkletree(net, temp_buckets, rim);
//                writefln("%s merkle_root=%s", indent, _merkle_root.cutHex);
                return _merkle_root;
            }
            else {
                return _archive.fingerprint;
            }
        }


        static immutable(ubyte[]) sparsed_merkletree(T)(SecureNet net, T[] table, const uint rim) {
            immutable(ubyte[]) merkletree(T[] left, T[] right) {
                scope immutable(ubyte)[] _left_fingerprint;
                scope immutable(ubyte)[] _right_fingerprint;
                // scope(exit ) {
                //     writefln("%sleft=%s right=%s", indent, _left_fingerprint.cutHex, _right_fingerprint.cutHex);
                // }
                if ( (left.length == 1) && (right.length == 1 ) ) {
                    auto _left=left[0];
                    auto _right=right[0];
                    if ( _left ) {
                        _left_fingerprint=_left.merkle_root(net, rim);
                    }
                    if ( _right ) {
                        _right_fingerprint=_right.merkle_root(net, rim);
                    }
                }
                else {
                    immutable left_mid=left.length >> 1;
                    immutable right_mid=right.length >> 1;
                    _left_fingerprint=merkletree(left[0..left_mid], left[left_mid..$]);
                    _right_fingerprint=merkletree(right[0..right_mid], right[right_mid..$]);
                }
                if ( _left_fingerprint is null ) {
                    return _right_fingerprint;
                }
                else if ( _right_fingerprint is null ) {
                    return _left_fingerprint;
                }
                else {
                    return net.calcHash(_left_fingerprint~_right_fingerprint);
                }
            }
            immutable mid=table.length >> 1;
            return merkletree(table[0..mid], table[mid..$]);
        }


        // uint length() const pure nothrow {
        //     return _count;
        // }
//        version(none) {
        private Iterator iterator(const uint rim) {
            return Iterator(this, rim);
        }

        struct Iterator {
            immutable uint rim;
            static class BucketStack {
                Bucket bucket;
                ubyte pos;
                BucketStack stack;
                this(Bucket b) {
                    bucket=b;
                }
            }

            this(Bucket b, immutable uint rim) {
                this.rim=rim;
                _stack=new BucketStack(b);
            }

            private void push(ref BucketStack b, Bucket bucket) {
                auto top_stack=new BucketStack(bucket);
                top_stack.stack=_stack;
                _stack=top_stack;
            }

            private void pop(ref BucketStack b) {
                _stack=b.stack;
            }

            private BucketStack _stack;
            private Bucket _current;
            void popFront() {
                if ( _stack ) {
                    if ( _stack.bucket.isBucket ) {
                        if ( _stack.pos < _stack.bucket._buckets.length ) {
                            _current=_stack.bucket._buckets[_stack.pos];
                            _stack.pos++;
                            if ( _current.isBucket ) {
                                push(_stack, _current);
                                popFront;
                            }
                        }
                        else {
                            pop(_stack);
                            popFront;
                        }
                    }
                    else {
                        _current=_stack.bucket;
                        pop(_stack);
                    }
                }
            }

            bool empty() const pure nothrow {
                return _stack is null;
            }

            const(Bucket) front()
            in {
                if ( _current ) {
                    assert(!_current.isBucket, "Should be an archive tab not bucket");
                }
            }
            do {
                return _current;
            }
        }


        version(none)
        invariant {
            if ( _buckets !is null ) {
                Bucket privious;
                immutable(ubyte)[] bucket_prefix;
                uint archive_rim;
                uint bucket_rim;

                foreach(i,b; _buckets) {
                    // if ( i > 0 ) {
                    //     if ( (_buckets[i-1]._buckets) && (_buckets[i]._buckets !is null) ){
                    //     if ( _buckets[i-1].rim != b.rim ) {
                    //         writefln("Bad rim %d %d i=%d %s %s", _buckets[i-1].rim, b.rim, i,
                    //             _buckets[i-1].prefix.toHexString,
                    //             b.prefix.toHexString,
                    //             );
                    //         writefln("\t%s %s", _buckets[i-1]._buckets !is null, _buckets[i]._buckets !is null);
                    //         writefln("\t%s %s", _buckets[i-1]._buckets.length, _buckets[i]._buckets.length);
                    //     }
                    //     }
                    //     // if ( !(_buckets[i-1].index(rim) < b.index(rim)) ) {
                    //     //     writefln("Index %02x < %02x", _buckets[i-1].index(rim), b.index(rim));

                    //     // }
                    //     // assert(_buckets[i-1].index(rim) < b.index(rim));
                    // }
                    version(none) {
                    if ( b._buckets  ) {
                        if ( bucket_prefix ) {
                            if (!(bucket_prefix == b.prefix)) {
                                writefln("Prefix %s %s", bucket_prefix.toHexString, b.prefix.toHexString);
                            }
                            if ( !(bucket_rim == b.rim) ) {
                                writefln("Bad rim %d %d", bucket_rim, b.rim);
                                writefln("%s %s", _buckets[0]._buckets !is null, _buckets[i]._buckets !is null);
                            }
                            assert(bucket_prefix == b.prefix);
                            assert(bucket_rim == b.rim);
                        }
                        else {
                            bucket_prefix=b.prefix;
                            bucket_rim=b.rim;
                        }
                    }
                    else {
                        if (  archive_prefix ) {
                            if (!(archive_prefix == b.prefix)) {
                                writefln("Prefix %s %s", archive_prefix.toHexString, b.prefix.toHexString);
                            }
                            if ( !(archive_rim == b.rim) ) {
                                writefln("Bad rim %d %d", archive_rim, b.rim);
                                                             writefln("%s %s", _buckets[0]._buckets !is null, _buckets[i]._buckets !is null);
                            }
                            assert(archive_prefix == b.prefix);
                            assert(archive_rim == b.rim );
                        }
                        else {
                            archive_prefix=b.prefix;
                            archive_rim=b.rim;
                        }
                    }


                    if ( i > 0 ) {
                        if ( !(_buckets[i-1].index(rim) < b.index(rim)) ) {
                            writefln("Index %02x < %02x", _buckets[i-1].index(rim), b.index(rim));
                        }
                        assert(_buckets[i-1].index(rim) < b.index(rim));
                    }
                }
                }
            }
        }
    }

    unittest { // Test of add, find, remove, merkle_root
        import tagion.Base;
        import std.typecons;
        static class TestNet : BlackHole!SecureNet {
            override immutable(Buffer) calcHash(immutable(ubyte[]) data) inout {
                if ( data.length == ulong.sizeof ) {
                    return data;
                }
                else {
                    import std.digest.sha : SHA256;
                    import std.digest.digest;
                    return digest!SHA256(data).idup;
                }
            }
        }

        immutable(ubyte[]) data(const ulong x) {
            import std.bitmanip;
            return nativeToBigEndian(x).idup;
        }

        import std.stdio;

        immutable(ulong[]) table=[
            //  RIM 2 test (rim=2)
            0x20_21_10_30_40_50_80_90,
            0x20_21_11_30_40_50_80_90,
            0x20_21_12_30_40_50_80_90,
            0x20_21_0a_30_40_50_80_90, // Insert before in rim 2

            // Rim 3 test (rim=3)
            0x20_21_20_30_40_50_80_90,
            0x20_21_20_31_40_50_80_90,
            0x20_21_20_34_40_50_80_90,
            0x20_21_20_20_40_50_80_90, // Insert before the first in rim 3

            0x20_21_20_32_40_50_80_90, // Insert just the last archive in the bucket  in rim 3


            // Rim 3 test (rim=3)
            0x20_21_22_30_40_50_80_90,
            0x20_21_22_31_40_50_80_90,
            0x20_21_22_34_40_50_80_90,
            0x20_21_22_20_40_50_80_90, // Insert before the first in rim 3
            0x20_21_22_36_40_50_80_90, // Insert after the first in rim 3

            0x20_21_22_32_40_50_80_90, // Insert between in rim 3

            // Add in first rim again
            0x20_21_11_33_40_50_80_90,

            // Rim 4 test
            0x20_21_20_32_30_40_50_80,
            0x20_21_20_32_31_40_50_80,
            0x20_21_20_32_34_40_50_80,
            0x20_21_20_32_20_40_50_80, // Insert before the first in rim 4

            0x20_21_20_32_32_40_50_80, // Insert just the last archive in the bucket  in rim 4

            ];

        auto net=new TestNet;
        DARTAngle add_array(immutable(ulong[]) array) {
            auto dart=new DARTAngle(net, 0x1000, 0x2022);
            foreach(a; array) {
                dart.add(data(a));
                auto key=data(a);
            }
            return dart;
        }

        void add_and_find_check(immutable(ulong[]) array) {
            auto dart=add_array(array);
            dart.dump;
            foreach(a; array) {
                auto d=dart[data(a)];
                assert(d, "Not found");
            }

        }

        import tagion.utils.Random;
        auto rand=Random(1234);
        immutable(ulong[]) shuffle(immutable(ulong[]) array, immutable uint count=127) {
            import std.algorithm.mutation : swap;
            ulong[] result=array.dup;
            immutable size=cast(uint)array.length;
            foreach(i;0..count) {
                immutable from=rand.value(size);
                immutable to=rand.value(size);
                swap(result[from], result[to]);
            }
            return result.idup;
        }

//        version(none) {
        // Add and find test
        { // First rim test one element
            writeln("###### Test 0 ######");
            auto dart=new DARTAngle(net, 0x1000, 0x2022);
            dart.add(data(table[0]));
            auto d=dart[data(table[0])];
            dart.dump;
        }

        // Add and find test
        { // First rim test one element
            writeln("###### Test 1 ######");
            add_and_find_check(table[0..1]);

        }



        { // rim 2 test two elements (First rim in the sector)
            writeln("###### Test 2 ######");
            add_and_find_check(table[0..2]);
        }


        { // Rim 2 test three elements
            writeln("###### Test 3 ######");
            add_and_find_check(table[0..3]);
        }



        { // Rim 2 test four elements (insert an element before all others)
            writeln("###### Test 4 ######");
            add_and_find_check(table[0..4]);
        }
        //   }

        { // Rim 3 test 2 elements
            writeln("###### Test 5 ######");
            add_and_find_check(table[4..6]);
        }

//        version(none) {
        { // Rim 3 test 3 elements
            writeln("###### Test 6 ######");
//            auto dart=add_array(table[4..7]);
//            dart.dump;
            add_and_find_check(table[4..7]);
        }

        { // Rim 3 test 4 elements (insert an element before all others)
            writeln("###### Test 7 ######");
            add_and_find_check(table[4..8]);
        }

        { // Rim 3 test 5 elements (insert an element in the middel)
            writeln("###### Test 8 ######");
            add_and_find_check(table[4..9]);
        }


        { // Rim 3 test 5 elements (Add insert element before the first and after the last element)
            writeln("###### Test 9 ######");
//            add_and_find_check(table[4..10]);
//            add_and_find_check(table[7..10]);
            add_and_find_check(table[9..14]);
        }

        { // Rim 3 test 6 elements ( add elememt in rim number 2)
            writeln("###### Test 10 ######");
//            add_and_find_check(table[4..10]);
//            add_and_find_check(table[7..10]);
            add_and_find_check(table[9..15]);
        }


        { // Rim 3 test 6 elements ( add elememt in rim number 2)
            writeln("###### Test 10a ######");
//            add_and_find_check(table[4..10]);
//            add_and_find_check(table[7..10]);
            add_and_find_check(table[16..21]);
        }



        { // Rim 3 test 6 all
            writeln("###### Test 11a ######");
//            auto dart=add_array(table[$-7..$-4]);
//            dart.dump;
//            add_and_find_check(table[4..10]);
//            add_and_find_check(table[7..10]);
            add_and_find_check(table[$-7..$]);
        }


        { // Rim 3 test 6 all
            writeln("###### Test 11b ######");
//            auto dart=add_array(table[$-7..$-4]);
//            dart.dump;
//            add_and_find_check(table[4..10]);
//            add_and_find_check(table[7..10]);
            add_and_find_check(table);
        }
        version(none){

        // Merkle root test
        { // Checks that the merkle root is indifferent from the order the archives is added
            // Without buckets
            writeln("###### Test 12 ######");
            immutable test_table=table[0..3];
            auto dart1=add_array(test_table);
            // Same but shuffled
            auto dart2=add_array(shuffle(test_table));
            immutable uint rim=2;
            immutable merkle_roo11=dart1.get(data(test_table[0])).merkle_root(net, rim);
            immutable merkle_roo12=dart2.get(data(test_table[0])).merkle_root(net, rim);
            assert(merkle_roo11 == merkle_roo12);
            // writefln("merkle_roo11=%s", merkle_roo11.cutHex);
            // writefln("merkle_roo12=%s", merkle_roo12.cutHex);
        }





        { // Checks that the merkle root is indifferent from the order the archives is added
            // With buckets
            writeln("###### Test 13a ######");
            immutable test_table=table[0..3]~table[15];

            auto dart1=add_array(test_table);
            writeln("DART1");
            dart1.dump;
            // Same but shuffled
            auto dart2=add_array(shuffle(test_table));
            writeln("DART2");
            dart2.dump;

            immutable uint rim=2;
            immutable merkle_roo11=dart1.get(data(test_table[0])).merkle_root(net, rim);
            immutable merkle_roo12=dart2.get(data(test_table[0])).merkle_root(net, rim);
            assert(merkle_roo11 == merkle_roo12);
            // writefln("merkle_roo11=%s", merkle_roo11.cutHex);
            // writefln("merkle_roo12=%s", merkle_roo12.cutHex);
        }
        //     }

        { // Checks that the merkle root is indifferent from the order the archives is added
            // With buckets
            writeln("###### Test 13b ######");
            immutable test_table=table;
            auto dart1=add_array(test_table);
            writeln("DART1");
            dart1.dump;
            // Same but shuffled
            auto dart2=add_array(shuffle(test_table));
            writeln("DART2");
            dart2.dump;

            immutable rim=2;

            immutable merkle_roo11=dart1.get(data(test_table[0])).merkle_root(net, rim);
            immutable merkle_roo12=dart2.get(data(test_table[0])).merkle_root(net, rim);
            assert(merkle_roo11 == merkle_roo12);
            dart2.dump;
            // writefln("merkle_roo11=%s", merkle_roo11.cutHex);
            // writefln("merkle_roo12=%s", merkle_roo12.cutHex);
        }
        }

        version(node) {

        // Remove test
        { // add and remove one archive
            writeln("###### Test 14 ######");
            auto dart=add_array(table[0..1]);
            // Find the arcive
            auto key=data(table[0]);
            auto a=dart[key];
            assert(a);
            dart.remove(a);
            a=dart[key];
            assert(!a);
        }
//        version(none)
        { // add two and remove one archive
            writeln("###### Test 15 ######");
            auto dart=add_array(table[0..2]);
            // Find the arcive
            auto key=data(table[0]);
            auto a=dart[key];
            assert(a);
            dart.get(key).dump;
            dart.remove(a);
            a=dart[key];
            assert(!a);
            immutable merkle_roo1=dart.get(data(table[1])).merkle_root(net);
            writefln("merkle_roo1=%s", merkle_roo1.cutHex);
            // For as single archive the merkle root is equal to the hash of the archive
            assert(merkle_roo1 == data(table[1]));
        }


        { // add three and remove one archive
            writeln("###### Test 16 ######");
            auto dart=add_array(table[0..3]);
            // Find the arcive
            auto key1=data(table[1]);
            auto a=dart[key1];
            assert(a);
            dart.get(key1).dump;
            // Remove
            dart.remove(a);
            a=dart[key1];
            assert(!a);
            // Checks if the rest is still in the dart
            auto key0=data(table[0]);
            a=dart[key0];
            assert(a);

            auto key2=data(table[2]);
            a=dart[key2];
            assert(a);

            // immutable merkle_roo1=dart.get(data(table[1])).merkle_root(net);
            // writefln("merkle_roo1=%s", merkle_roo1.cutHex);
            // // For as single archive the merkle root is equal to the hash of the archive
            // assert(merkle_roo1 == data(table[1]));
        }

        { // Remove all in one bucket in rim 2
            writeln("###### Test 17 ######");
            auto take_from_dart=add_array(table);
            immutable rim=2;
            uint count;
            foreach(t; table) {
                immutable key=data(t);
                if ( key[rim] == 0x20 ) {
                    count++;
                    writefln("\tcounting=%d %s", count, key.cutHex);
                    take_from_dart.remove(kuy);
                }
            }
            writefln("count=%d", count);

        }
        }
    }

    static uint calc_to_sector(const ushort from_sector, const ushort to_sector) pure nothrow {
        return to_sector+((from_sector >= to_sector)?sector_max:0);
    }

    static uint calc_sector_size(const ushort from_sector, const ushort to_sector) pure nothrow {
        immutable from=from_sector;
        immutable to=calc_to_sector(from_sector, to_sector);
        return to-from;
    }

    bool inRange(const ushort sector) const pure nothrow  {
        immutable ushort sector_origin=(sector-_from_sector) & ushort.max;
        immutable ushort to_origin=(_to_sector-_from_sector) & ushort.max;
        return ( sector_origin < to_origin );
    }

    unittest { // Check the inRange function
        import std.typecons : BlackHole;
        auto net=new BlackHole!SecureNet;

        enum from1=0x10;
        enum to1=0x8201;
        auto dart1=new DARTAngle(net, from1, to1);
        assert(dart1.inRange(from1));
        assert(dart1.inRange(to1-0x100));
        assert(dart1.inRange(to1-1));
        assert(!dart1.inRange(to1));

        enum from2=0xFF80;
        enum to2=0x10;
        auto dart2=new DARTAngle(net, from2, to2);
        assert(!dart2.inRange(from2-1));
        assert(dart2.inRange(from2));
        assert(dart2.inRange(0));
        assert(dart2.inRange(to2-1));
        assert(!dart2.inRange(to2));
        assert(!dart2.inRange(42));
    }

}
