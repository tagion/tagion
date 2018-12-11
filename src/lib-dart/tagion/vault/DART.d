module tagion.vault.DART;

import tagion.hashgraph.GossipNet : SecureNet;
import tagion.utils.BSON : HBSON, Document;
import tagion.hashgraph.ConsensusExceptions;

import tagion.Keywords;
import std.conv : to;

import tagion.Base : cutHex;
import std.stdio;
@safe
void check(bool flag, ConsensusFailCode code, string file = __FILE__, size_t line = __LINE__) {
    if (!flag) {
        throw new EventConsensusException(code, file, line);
    }
}

@safe
uint cover(const uint n) {
    uint local_cover(immutable uint width, immutable uint step) {
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

immutable(ubyte[]) sparsed_merkeltree(T)(SecureNet net, T[] table) {
    immutable(ubyte[]) merkeltree(T[] left, T[] right) {
        scope immutable(ubyte)[] _left_fingerprint;
        scope immutable(ubyte)[] _right_fingerprint;
        // scope(exit ) {
        //     writefln("%sleft=%s right=%s", indent, _left_fingerprint.cutHex, _right_fingerprint.cutHex);
        // }
        if ( (left.length == 1) && (right.length == 1 ) ) {
            auto _left=left[0];
            auto _right=right[0];
            if ( _left ) {
                _left_fingerprint=_left.merkle_root(net);
            }
            if ( _right ) {
                _right_fingerprint=_right.merkle_root(net);
            }
        }
        else {
            immutable left_mid=left.length >> 1;
            immutable right_mid=right.length >> 1;
            _left_fingerprint=merkeltree(left[0..left_mid], left[left_mid..$]);
            _right_fingerprint=merkeltree(right[0..right_mid], right[right_mid..$]);
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
    return merkeltree(table[0..mid], table[mid..$]);
}


@safe
class DART {
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

    ushort sector_to_index(const ushort sector) {
        return (sector-_from_sector) & ushort.max;
    }

    void add(ArchiveTab archive) {
//        auto archive=new ArchiveTab(_net, data);
        immutable sector=root_sector(archive.fingerprint);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            if ( _root_buckets[index] is null ) {
                _root_buckets[index]=new Bucket(bucket_rim);
            }
            _root_buckets[index].add(archive);
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
        writeln("---- ----- ----");
        immutable sector=root_sector(key);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            if ( _root_buckets[index] ) {
                return _root_buckets[index].find(key);
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
        ubyte index(const uint rim) const pure {
            return fingerprint[rim];
        }
    }

    Bucket.Iterator iterator(ushort sector) {
        check(inRange(sector),  ConsensusFailCode.DART_ARCHIVE_SECTOR_NOT_FOUND);
        return _root_buckets[sector_to_index(sector)].iterator;
    }


    static class Bucket {
        private Bucket[] _buckets;
        private uint _bucket_size;
        private ArchiveTab _archive;
        immutable uint rim;
        immutable size_t init_size;
        immutable size_t extend;
        private immutable(ubyte)[]  _merkle_root;
        bool isBucket() const pure nothrow {
            return _buckets !is null;
        }

        uint index(const uint rim) const pure {
            if ( isBucket ) {
                return _buckets[0].index(rim);
            }
            else {
                return _archive.index(rim);
            }
        }

        private int find_bucket_pos(const int index)
            in {
                assert(index <= ubyte.max);
                assert(index >= 0);
            }
        do {
            int find_bucket_pos(immutable int search_j, immutable int division_j) {
                // writefln("search_j=%d division_j=%d", search_j, division_j);
                if ( search_j < _bucket_size ) {
                    immutable search_index=_buckets[search_j].index(rim);
                    // writefln("\tsearch_index=%x", _buckets[search_j].index(rim));
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
                }
                else if ( division_j > 0 ) {
                    if ( index > _buckets[_bucket_size-1].index(rim) ) {
//                        writefln("Outside bucket index=%d search_index=%d", index , _buckets[_bucket_size-1].index(rim));
                        return _bucket_size;
                    }
                    return find_bucket_pos(search_j-division_j, division_j/2);
                }
                //if (
                return search_j;
            }
//            writefln("\nfind pos bucket_size=%d", _bucket_size);
            immutable start_j=cover(_bucket_size) >> 1;
            return find_bucket_pos(start_j, start_j);
        }


        static size_t calc_init_size(size_t rim) {
            switch ( rim ) {
            case 0, 1, 2:
                return 32;
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

        size_t extend_size() pure const nothrow {
            immutable size=_buckets.length+extend;
            return (size <= ubyte.max)?size:ubyte.max+1;
        }

        size_t grow() {
            if ( _bucket_size+1 <= _buckets.length ) {
                return _buckets.length;
            }
            else {
                return extend_size;
            }
        }

        private void opIndexAssign(Bucket b, const uint index) {
            immutable pos=find_bucket_pos(index);
            assert( _buckets[pos].index(rim) != index );
            if ( _buckets is null ) {
                _buckets=new Bucket[init_size];
            }
            if ( _bucket_size+1 < _buckets.length ) {
                _buckets[pos+1.._bucket_size+1]=_buckets[pos.._bucket_size];
                _buckets[pos]=b;
                _bucket_size++;
            }
            else {
                auto new_buckets=new Bucket[extend_size];
                new_buckets[0..pos]=_buckets[0..pos];
                new_buckets[pos+1.._bucket_size+1]=_buckets[pos.._bucket_size];
                new_buckets[pos]=b;
                _buckets=new_buckets;
                _bucket_size++;
            }
        }

        private this(immutable uint rim) {
            this.rim=rim;
            init_size=calc_init_size(rim);
            extend=calc_extend(rim);

        }

        // this(ArchiveTab archive, immutable uint rim) {
        //     this(rim);
        //     _archive=archive;
        // }

        this(Document doc, SecureNet net, immutable uint rim) {
            this(rim);
            if ( doc.hasElement(Keywords.buckets) ) {
                auto buckets_doc=doc[Keywords.buckets].get!Document;
                _buckets=new Bucket[buckets_doc.length];
                foreach(elm; buckets_doc[]) {
                    auto arcive_doc=elm.get!Document;
                    immutable index=elm.key.to!ubyte;
                    this[index]=new Bucket(arcive_doc, net, rim+1);
                }
            }
            else if (doc.hasElement(Keywords.tab)) {
                // Fixme check that the Doc is HBSON
                auto arcive_doc=doc[Keywords.tab].get!Document;
                _archive=new ArchiveTab(net, arcive_doc.data);
            }
        }

        @trusted
        void dump() {
            writeln("Dump bucket");
            foreach(i;0.._bucket_size) {
                if ( _buckets[i].isBucket ) {
                    writefln("\t\ti=%d %s %s", i, _buckets[i]._merkle_root, _buckets[i].isBucket);
                }
                else {
                    writefln("\t\ti=%d %s %s", i, _buckets[i]._archive.fingerprint, _buckets[i].isBucket);
                }
            }
        }

        HBSON toBSON() const {
            auto bson=new HBSON;
            if ( isBucket ) {
                auto buckets=new HBSON;
                foreach(i;0.._bucket_size) {
                    auto b=_buckets[i];
                    buckets[b.index(rim).to!string]=b.toBSON;
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

        ArchiveTab find(immutable(ubyte[]) key) {
            writefln("find=%s %x rim=%d", key, key[rim], rim);
            if ( isBucket ) {
                immutable pos=find_bucket_pos(key[rim]);
                writefln("\t\tpos=%d bucket_size=%d rim=%d key=0x%x", pos, _bucket_size, rim, key[rim] );
                if ( (pos >= 0) && (pos < _bucket_size) && _buckets[pos] ) {
                    writefln("\t\trim=%d", _buckets[pos].rim);
                    return _buckets[pos].find(key);
                }
            }
            else if ( _archive && (_archive.fingerprint == key) ) {
                return _archive;
            }
            return null;
        }

        void add(ArchiveTab archive) {
            add(archive, rim);
            dump;
        }

        private void add(ArchiveTab archive, immutable uint _rim) {
            // string indent;
            // foreach(i;0.._rim) {
            //     indent~="*>";
            // }
            // writefln("%s  ADD %s rim=%d",  indent, archive.data, _rim);
            void insert(immutable int pos, ArchiveTab archive) {
                // writefln("%s  Insert pos=%d %s", indent, pos, archive.data);
                auto temp_bucket=new Bucket(_rim);
                // writefln("After insert (pos<0)=%s (pos >= _bucket_size)=%s", pos < 0, (pos >= _bucket_
//                        size));
                scope(exit) {
                    _bucket_size++;
                }
                if (pos >= cast(int)_bucket_size) {
                    if ( _bucket_size+1 >= _buckets.length ) {
                        _buckets.length=extend_size;
                    }
                    temp_bucket.add(archive);
                    _buckets[_bucket_size]=temp_bucket;
                }
                else if ( pos < 0 ) {
//                    writeln("Infront");
                    Bucket[] new_buckets;
                    if ( _bucket_size+1 <= _buckets.length ) {
                        new_buckets.length=extend_size;
                    }
                    else {
                        new_buckets.length=_buckets.length;
                    }
                    new_buckets[0]=temp_bucket;
                    new_buckets[1.._bucket_size+1]=_buckets[0.._bucket_size];
                    temp_bucket.add(archive);
                    _buckets=new_buckets;
                }
                else {
                    if ( _bucket_size+1 >= _buckets.length ) {
                        _buckets.length=extend_size;
                    }
                    foreach_reverse(i;pos.._bucket_size) {
                        _buckets[i+1]=_buckets[i];
                    }
                    temp_bucket.add(archive);
                    _buckets[pos]=temp_bucket;
                }
            }
            bool same_index(immutable int pos, immutable ubyte index) {
                if ( (pos >= 0) && (pos < _bucket_size) ) {
                    return _buckets[pos].index(rim) == index;
                }
                return false;
            }

            _merkle_root=null;
            if ( isBucket ) {
                immutable index=archive.fingerprint[rim];
                immutable pos=find_bucket_pos(index);
                if ( same_index(pos, index) ) {
                    _buckets[pos].add(archive, rim+1);
                }
                else {
                    insert(pos, archive);
                }
            }
            else if ( _archive is null ) {
                writefln("add archive %s", archive.data);
                _archive=archive;
            }
            else {
                writefln("add to bucket %s", archive.data);
                //_buckets=new Bucket[_bucket_size];
                insert(0, _archive);
                _archive=null;
                add(archive);

                // if ( _archive.index(rim) == archive.index(rim) ) {
                //     writefln("\tsame sub bucket %x", archive.index(rim));
                //     _bucket_size=1;
                //     _buckets=new Bucket[_bucket_size];
                //     auto temp_bucket=new Bucket(rim+1);
                //     temp_bucket.add(_archive);
                //     temp_bucket.add( archive);
                //     _buckets[0]=temp_bucket;
                // }
                // else {
                //     writefln("\tdo %x %x d=%d", _archive.index(rim), archive.index(rim), rim);
                //     import std.algorithm : max;
                //     immutable min_init_size=max(2,init_size);
                //     _bucket_size=2;
                //     _buckets=new Bucket[min_init_size];
                //     _buckets[0]=new Bucket(rim);
                //     _buckets[1]=new Bucket(rim);
                //     writefln("\t\t[0]=%x [1]=%x", _archive.index(rim), archive.index(rim));
                //     if ( _archive.index(rim) < archive.index(rim) ) {
                //         _buckets[0].add(net, _archive);
                //         _buckets[1].add(net, archive);
                //     }
                //     else {
                //         _buckets[1].add(net, _archive);
                //         _buckets[0].add(net, archive);
                //     }
                // }
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
                check(bucket._buckets[index] !is null, ConsensusFailCode.DART_ARCHIVE_DOES_NOT_EXIST);
                bucket._buckets[index]=Bucket.remove(bucket._buckets[index], archive, rim+1);
                if ( bucket._buckets[index] is null ) {
                    bucket._buckets=array_remove(bucket._buckets, index);
                    bucket._bucket_size--;
                    if ( bucket._bucket_size == 1 ) {
                        if ( !bucket._buckets[0].isBucket ) {
                            auto temp_bucket=new Bucket(bucket._buckets[0].rim-1);
                            temp_bucket._archive=bucket._buckets[0]._archive;
                            bucket.destroy;
                            bucket=temp_bucket;
                        }
                    }
                    else if ( bucket._bucket_size == 0 ) {
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

        immutable(ubyte[]) merkle_root(SecureNet net) {
            if ( _merkle_root ) {
                return _merkle_root;
            }
            else if ( isBucket ) {
                scope auto temp_buckets=new Bucket[bucket_max];
                // string indent;
                // foreach(j;0..rim) {
                //     indent~="\t";
                // }
                foreach(i;0.._bucket_size) {
                    auto b=_buckets[i];
                    temp_buckets[b.index(rim)]=b;
                    // writefln("%s %d key=%s rim=%d key=%s data=%s bucket=%s", indent, i, b.index(rim), rim, b._archive.fingerprint.cutHex, b._archive.data.cutHex, b.isBucket);

                }
                _merkle_root=sparsed_merkeltree(net, temp_buckets);
//                writefln("%s merkle_root=%s", indent, _merkle_root.cutHex);
                return _merkle_root;
            }
            else {
                return _archive.fingerprint;
            }
        }

        // uint length() const pure nothrow {
        //     return _count;
        // }
        Iterator iterator() {
            return Iterator(this);
        }
        struct Iterator {
            static class BucketStack {
                Bucket bucket;
                ubyte pos;
                BucketStack stack;
                this(Bucket b) {
                    bucket=b;
                }
            }

            this(Bucket b) {
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
                        if ( _stack.pos < _stack.bucket._bucket_size ) {
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

    unittest {
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


            // Rim 2 test (rim=3)
            0x20_21_22_30_40_50_80_90,
            0x20_21_22_31_40_50_80_90,
            0x20_21_22_34_40_50_80_90,
            0x20_21_22_20_40_50_80_90, // Insert before the first in rim 3
            0x20_21_22_36_40_50_80_90, // Insert after the first in rim 3

            0x20_21_22_32_40_50_80_90, // Insert between in rim 3

            // Add in first rim again
            0x20_21_21_30_40_50_80_90,

            ];

        auto net=new TestNet;
        DART add_array(immutable(ulong[]) array) {
            auto dart=new DART(net, 0x1000, 0x2022);
            foreach(a; array) {
                dart.add(data(a));
                auto key=data(a);
                writefln("key=%s %x %x %s", key, a, dart.root_sector(key), dart.inRange(dart.root_sector(key)));
            }
            return dart;
        }

        void add_and_find_check(immutable(ulong[]) array) {
            auto dart=add_array(array);
            foreach(a; array) {
                auto d=dart[data(a)];
                if ( d ) {
                    writefln("found %016x", a);
                }
                else {
                    writefln("Not found! %016x", a);
                }
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

        { // Rim 2 test 2 elements
            writeln("###### Test 5 ######");
            add_and_find_check(table[4..6]);
        }

        { // Rim 3 test 3 elements
            writeln("###### Test 6 ######");
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

//        }
        { // Rim 3 test 6 all
            writeln("###### Test 11 ######");
//            add_and_find_check(table[4..10]);
//            add_and_find_check(table[7..10]);
            add_and_find_check(table);
        }
//        version(none)

        // Merkle root test
        { // Checks that the merkle root is indifferent from the order the archives is added
            // Without buckets
            writeln("###### Test 12 ######");
            immutable test_table=table[0..3];
            auto dart1=add_array(test_table);
            // Same but shuffled
            auto dart2=add_array(shuffle(test_table));
            immutable merkle_roo11=dart1.get(data(test_table[0])).merkle_root(net);
            immutable merkle_roo12=dart2.get(data(test_table[0])).merkle_root(net);
            assert(merkle_roo11 == merkle_roo12);
            // writefln("merkle_roo11=%s", merkle_roo11.cutHex);
            // writefln("merkle_roo12=%s", merkle_roo12.cutHex);
        }

        { // Checks that the merkle root is indifferent from the order the archives is added
            // With buckets
            writeln("###### Test 13 ######");
            immutable test_table=table;
            auto dart1=add_array(test_table);
            // Same but shuffled
            auto dart2=add_array(shuffle(test_table));
            immutable merkle_roo11=dart1.get(data(test_table[0])).merkle_root(net);
            immutable merkle_roo12=dart2.get(data(test_table[0])).merkle_root(net);
            assert(merkle_roo11 == merkle_roo12);
            // writefln("merkle_roo11=%s", merkle_roo11.cutHex);
            // writefln("merkle_roo12=%s", merkle_roo12.cutHex);
        }

        // Remove test
        {

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
        auto dart1=new DART(net, from1, to1);
        assert(dart1.inRange(from1));
        assert(dart1.inRange(to1-0x100));
        assert(dart1.inRange(to1-1));
        assert(!dart1.inRange(to1));

        enum from2=0xFF80;
        enum to2=0x10;
        auto dart2=new DART(net, from2, to2);
        assert(!dart2.inRange(from2-1));
        assert(dart2.inRange(from2));
        assert(dart2.inRange(0));
        assert(dart2.inRange(to2-1));
        assert(!dart2.inRange(to2));
        assert(!dart2.inRange(42));
    }

}
