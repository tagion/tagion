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

    inout(Bucket) get(immutable(ubyte[]) key) inout {
        uint sector_rim=bucket_rim;
        return get(key, sector_rim);
    }

    inout(Bucket) get(immutable(ubyte[]) key, ref uint rim) inout
        in {
            assert(rim >= bucket_rim);
        }
    do {
        uint found_rim=rim;
        inout(Bucket) search(inout(Bucket) bucket, const uint search_rim) pure inout {
            if ( bucket.isBucket ) {
                found_rim=search_rim;
                int index=key[rim];
                immutable pos=bucket.find_bucket_pos(index, search_rim+1);
                if ( (pos < bucket._buckets.length) && (key[rim] == bucket._buckets[pos].index(rim)) ) {
                    return search(bucket._buckets[pos], search_rim+1);
                }
            }
            return bucket;
        }

        immutable sector=root_sector(key);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            auto result=_root_buckets[index];
            if ( rim >= bucket_rim ) {
                return search(result, rim);
            }
        }
        return null;
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

        private ubyte index(const uint rim) const pure {
            if ( isBucket ) {
                return _buckets[0].index(rim);
            }
            else {
                return _archive.fingerprint[rim];
            }
        }

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
                assert(index <= ubyte.max);
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

        private this() {
            /* empty */
        }

        private this(ArchiveTab archive) {
            _archive=archive;
        }

        this(Document doc, SecureNet net) {
            //this(doc[Keywords.rim].get!uint);
            if ( doc.hasElement(Keywords.buckets) ) {
                auto buckets_doc=doc[Keywords.buckets].get!Document;
                _buckets=new Bucket[buckets_doc.length];
                foreach(elm; buckets_doc[]) {
                    auto arcive_doc=elm.get!Document;
                    immutable index=elm.key.to!ubyte;
                }
            }
            else if (doc.hasElement(Keywords.tab)) {
                // Fixme check that the Doc is HBSON
                auto arcive_doc=doc[Keywords.tab].get!Document;
                _archive=new ArchiveTab(net, arcive_doc.data);
            }
        }


        void dump() const {
            dump(bucket_rim);
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
                    writefln("  |%s b.rim=%d b.index(rim)=%02x  index(rim-1)=%02x", b._archive.fingerprint.toHexString,
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
            if ( isBucket ) {
                immutable pos=find_bucket_pos(key[rim], rim);
                if ( (pos >= 0) && (pos < _buckets.length) && _buckets[pos] ) {
                    return _buckets[pos].find(key, rim+1);
                }
            }
            else if ( _archive && (_archive.fingerprint == key) ) {
                return _archive;
            }
            // if ( _archive ) {
            //     writefln("key=%s fingerprint=%s", key.toHexString, _archive.fingerprint.toHexString);
            // }
            return null;
        }

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
//                bucket.dump;
//                writefln("remove pos=%d index=%02x archive.fingerprint=%s rim=%d length=%d", pos, index, archive.fingerprint.cutHex, rim, bucket._buckets.length);
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
                foreach(i;0.._buckets.length) {
                    auto b=_buckets[i];
                    temp_buckets[b.index(rim)]=b;
                }
                _merkle_root=sparsed_merkletree(net, temp_buckets, rim);
                return _merkle_root;
            }
            else {
                return _archive.fingerprint;
            }
        }

        static immutable(ubyte[]) sparsed_merkletree(SecureNet net, Bucket[] table, const uint rim) {
            immutable(ubyte[]) merkletree(Bucket[] left, Bucket[] right) {
                scope immutable(ubyte)[] _left_fingerprint;
                scope immutable(ubyte)[] _right_fingerprint;
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
        DARTAngle add_array(const(ulong[]) array) {
            auto dart=new DARTAngle(net, 0x1000, 0x2022);
            foreach(a; array) {
                dart.add(data(a));
                auto key=data(a);
            }
            return dart;
        }

        DARTAngle add_and_find_check(const(ulong[]) array) {
            auto dart=add_array(array);
//            dart.dump;
            foreach(a; array) {
                auto d=dart[data(a)];
                assert(d, "Not found");
            }
            return dart;
        }

        import tagion.utils.Random;
        auto rand=Random(1234);
        immutable(ulong[]) shuffle(const(ulong[]) array, immutable uint count=127) {
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

        // Add and find test
        { // First rim test one element
            auto dart=new DARTAngle(net, 0x1000, 0x2022);
            dart.add(data(table[0]));
            auto d=dart[data(table[0])];
            assert(d);
        }

        // Add and find test
        { // First rim test one element
            add_and_find_check(table[0..1]);
        }

        { // rim 2 test two elements (First rim in the sector)
            add_and_find_check(table[0..2]);
        }

        { // Rim 2 test three elements
            add_and_find_check(table[0..3]);
        }

        { // Rim 2 test four elements (insert an element before all others)
            add_and_find_check(table[0..4]);
        }

        { // Rim 3 test 2 elements
            add_and_find_check(table[4..6]);
        }

        { // Rim 3 test 3 elements
            add_and_find_check(table[4..7]);
        }

        { // Rim 3 test 4 elements (insert an element before all others)
            add_and_find_check(table[4..8]);
        }

        { // Rim 3 test 5 elements (insert an element in the middel)
            add_and_find_check(table[4..9]);
        }

        { // Rim 3 test 5 elements (Add insert element before the first and after the last element)
            add_and_find_check(table[9..14]);
        }

        { // Rim 3 test 6 elements ( add elememt in rim number 2)
            add_and_find_check(table[9..15]);
        }

        { // Rim 3 test 6 elements ( add elememt in rim number 2)
            add_and_find_check(table[16..21]);
        }

        { // Rim 3 test 6 all
            add_and_find_check(table[$-7..$]);
        }


        { // Rim 3 test 6 all
            add_and_find_check(table);
        }


        // Merkle root test
        { // Checks that the merkle root is indifferent from the order the archives is added
            immutable test_table=table[0..3];
            auto dart1=add_array(test_table);
            // Same but shuffled
            auto dart2=add_array(shuffle(test_table));
            immutable uint rim=2;
            immutable merkle_root1=dart1.get(data(test_table[0])).merkle_root(net, bucket_rim);
            immutable merkle_root2=dart2.get(data(test_table[0])).merkle_root(net, bucket_rim);
            assert(merkle_root1);
            assert(merkle_root1 == merkle_root2);
        }

        { // Checks that the merkle root is indifferent from the order the archives is added
            immutable test_table=table[0..3]~table[15];

            auto dart1=add_array(test_table);
            // Same but shuffled
            auto dart2=add_array(shuffle(test_table));

            immutable uint rim=2;
            immutable merkle_root1=dart1.get(data(test_table[0])).merkle_root(net, bucket_rim);
            immutable merkle_root2=dart2.get(data(test_table[0])).merkle_root(net, bucket_rim);
            assert(merkle_root1);
            assert(merkle_root1 == merkle_root2);
        }

        { // Checks that the merkle root is indifferent from the order the archives is added
            // With buckets
            immutable test_table=table;
            auto dart1=add_array(test_table);
            // Same but shuffled
            auto dart2=add_array(shuffle(test_table));

            immutable merkle_root1=dart1.get(data(test_table[0])).merkle_root(net, bucket_rim);
            immutable merkle_root2=dart2.get(data(test_table[0])).merkle_root(net, bucket_rim);
            assert(merkle_root1);
            assert(merkle_root1 == merkle_root2);
        }

        // Remove test
        { // add and remove one archive
//            writeln("###### Test 14 ######");
            auto dart=add_array(table[0..1]);
            // Find the arcive
            auto key=data(table[0]);
            auto a=dart[key];
            assert(a);
            dart.remove(a);
            a=dart[key];
            assert(!a);
        }

        { // add two and remove one archive
//            writeln("###### Test 15 ######");
            auto dart1=add_array(table[0..2]);
            auto dart2=add_array(table[1..2]);
            // Find the arcive
            auto key=data(table[0]);
            auto a=dart1[key];
            assert(a);
//            dart1.get(key).dump;
            dart1.remove(a);
            a=dart1[key];
            assert(!a);
            immutable rim=2;
            immutable merkle_root1=dart1.get(data(table[1])).merkle_root(net, bucket_rim);
//            writefln("merkle_root1=%s", merkle_root1.cutHex);
            immutable merkle_root2=dart2.get(data(table[1])).merkle_root(net, bucket_rim);
//            writefln("merkle_root2=%s", merkle_root2.cutHex);
            assert(merkle_root1 == merkle_root2);
            // For as single archive the merkle root is equal to the hash of the archive
            assert(merkle_root1 == data(table[1]));
        }

        { // add three and remove one archive
//            writeln("###### Test 16 ######");
            auto dart1=add_array(table[0..3]);
            auto dart2=add_array([table[0], table[2]]);
            // Find the arcive
            auto key1=data(table[1]);
            auto a=dart1[key1];
            assert(a);
//            dart1.get(key1).dump;
            // Remove
            dart1.remove(a);
            a=dart1[key1];
            assert(!a);
            // Checks if the rest is still in the dart
            auto key0=data(table[0]);
            a=dart1[key0];
            assert(a);

            auto key2=data(table[2]);
            a=dart1[key2];
            assert(a);

            immutable rim=2;
            immutable merkle_root1=dart1.get(data(table[1])).merkle_root(net, bucket_rim);
            // writefln("merkle_root1=%s", merkle_root1.cutHex);
            immutable merkle_root2=dart2.get(data(table[1])).merkle_root(net, bucket_rim);
            // writefln("merkle_root2=%s", merkle_root2.cutHex);
            assert(merkle_root1 == merkle_root2);
        }


        { // Remove all in one bucket in rim 2
//            writeln("###### Test 17 ######");
            auto take_from_dart=add_array(table);
            immutable(ulong)[] dummy;
            auto add_to_dart=add_array(dummy);
            immutable rim=2;

            uint count;
            foreach(t; table) {
                immutable key=data(t);
                if ( key[rim] == 0x20 ) {
                    count++;
//                    writefln("\tcounting=%d %s", count, key.cutHex);
                    take_from_dart.remove(key);
                }
                else {
                    add_to_dart.add(key);
                }
            }
//            writefln("count=%d size=%d", count, size);
            assert(count == 10);

            immutable merkle_root1=take_from_dart.get(data(table[1])).merkle_root(net, bucket_rim);
            // writefln("merkle_root1=%s", merkle_root1.cutHex);
            immutable merkle_root2=add_to_dart.get(data(table[1])).merkle_root(net, bucket_rim);
            // writefln("merkle_root2=%s", merkle_root2.cutHex);
            assert(merkle_root1 == merkle_root2);
        }

        {  // Remove all in one bucket in rim 3

//            writeln("###### Test 18 ######");
            auto take_from_dart=add_array(table);
            immutable(ulong)[] dummy;
            auto add_to_dart=add_array(dummy);
            immutable rim=3;

            uint count;
            foreach(t; table) {
                immutable key=data(t);
                if ( key[rim] == 0x32 ) {
                    count++;
                    // writefln("\tcounting=%d %s", count, key.cutHex);
                    take_from_dart.remove(key);
                }
                else {
                    add_to_dart.add(key);
                }
            }
            // writefln("count=%d", count);
            assert(count == 7);

            immutable merkle_root1=take_from_dart.get(data(table[1])).merkle_root(net, bucket_rim);
            // writefln("merkle_root1=%s", merkle_root1.cutHex);
            immutable merkle_root2=add_to_dart.get(data(table[1])).merkle_root(net, bucket_rim);
            // writefln("merkle_root2=%s", merkle_root2.cutHex);
            assert(merkle_root1 == merkle_root2);
        }

        { // Remove all in random order
//            writeln("###### Test 19 ######");
            import std.algorithm;
            auto take_from_dart=add_array(table);
            auto add_table=table.dup;

            foreach(k;0..table.length-1) {
                immutable key_index=rand.value(cast(uint)add_table.length);
                immutable key=data(add_table[key_index]);
                add_table=add_table.remove(key_index);
                auto add_to_dart=add_array(add_table);
                take_from_dart.remove(key);
                // writefln("add_table=%s", add_table);
                // writefln("    table=%s", table);
                immutable merkle_root1=take_from_dart.get(data(table[1])).merkle_root(net, bucket_rim);
                // writefln("merkle_root1=%s key_index=%d", merkle_root1.cutHex, key_index);
                immutable merkle_root2=add_to_dart.get(data(table[1])).merkle_root(net, bucket_rim);
                // writefln("merkle_root2=%s", merkle_root2.cutHex);
                assert(merkle_root1 == merkle_root2);

            }
        }

        { // Fill the bucket in rim 3..7
            // and check capacity
//            writeln("###### Test 20 ######");
//            immutable rim=2;
            immutable ulong rim3_data=0x20_21_00_00_00_00_00_00;
            auto full_bucket_table=new ulong[bucket_max];
            foreach_reverse(rim;bucket_rim..8) {
                foreach(i, ref t; full_bucket_table) {
//                    immutable ulong mask=(cast(ulong)(i & ubyte.max) << ((ulong.sizeof-rim-1)*8));
                    t=rim3_data | ((i & ubyte.max) << ((ulong.sizeof-rim-1)*8));
                    //   writefln("%3d t=%016x mask=%016x", i, t, mask);
                }
                auto dart=add_and_find_check(shuffle(full_bucket_table, 1024));
                // immutable key=data(rim3_data);
                //   auto bucket=dart.get(key);
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
