module tagion.vault.DART;

import tagion.hashgraph.GossipNet : SecureNet;
import tagion.utils.BSON : HBSON, Document;
import tagion.hashgraph.ConsensusExceptions;

import tagion.Keywords;
import std.conv : to;


immutable(ubyte[]) sparsed_merkeltree(T)(SecureNet net, T[] table) {
    immutable(ubyte[]) merkeltree(T[] left, T[] right) {
        scope immutable(ubyte)[] _left_fingerprint;
        scope immutable(ubyte)[] _right_fingerprint;
        if ( (left.length == 1) && (right.length == 1 ) ) {
            auto _left=left[0];
            auto _right=right[0];
            if ( _left ) {
                _left_fingerprint=_left.fingerprint(net);
            }
            if ( _right ) {
                _right_fingerprint=_right.fingerprint(net);
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
    enum uint root_depth=cast(uint)ushort.sizeof;
    enum sector_max = ushort.max;
    // class Section {
    //     private string _filename;
    //     private Bucket _bucket;
    // }

    // private Section[] _sections;

    this(SecureNet net, const ushort from_sector, const ushort to_sector) {
        _net=net;
        _from_sector=from_sector;
        _to_sector=to_sector;
        _root_buckets=new Bucket[calc_sector_size(_from_sector, _to_sector)];
    }

    ushort root_sector(immutable(ubyte[]) data) pure const nothrow {
        return data[1] | (data[0] << 1);
    }

    ushort sector_to_index(const ushort sector) {
        return (sector-_from_sector) & ushort.max;
    }

    void add(immutable(ubyte[]) data) {
        auto archive=new ArchiveTab(_net, data);
        immutable sector=root_sector(archive.fingerprint);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            if ( _root_buckets[index] is null ) {
                _root_buckets[index]=new Bucket(root_depth);
            }
            _root_buckets[index].add(_net, archive);
        }
    }

    void remove(immutable(ubyte[]) data) {
        auto archive=new ArchiveTab(_net, data);
        immutable sector=root_sector(archive.fingerprint);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            if ( _root_buckets[index] ) {
                Bucket.remove(_root_buckets[index], _net, archive);
            }
        }
    }

    ArchiveTab find(immutable(ubyte[]) key) {
        immutable sector=root_sector(key);
        if ( inRange(sector) ) {
            immutable index=sector_to_index(sector);
            if ( _root_buckets[index] ) {
                return _root_buckets[index].find(key);
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
        ubyte index(const uint depth) const pure {
            return fingerprint[depth];
        }
    }

    static class Bucket {
        private Bucket[] _buckets;
        private size_t _bucket_size;
        private ArchiveTab _archive;
        immutable uint depth;
        immutable size_t init_size;
        immutable size_t extend;
        private immutable(ubyte)[]  _fingerprint;
        bool isBucket() const pure nothrow {
            return _buckets !is null;
        }

        version(none)
        Bucket opIndex(ubyte i) {
            Bucket find_bucket(immutable uint search_j, immutable uint division_j) {
                if ( search_j < _bucket_size ) {
                    immutable search_index=_buckets[search_j].index;
                    if ( index == search_index ) {
                        return _buckets[search_j];
                    }
                    else if ( division_j > 0 ) {
                        if ( index < search_index ) {
                            return find_bucket(search_j-division_j, division_j/2);
                        }
                        else if ( index > search_index ) {
                            return find_bucket(search_j+division_j, division_j/2);
                        }
                    }
                }
                return null;
            }
            immutable start_j=((_bucket_size+((_bucket_size % 2 == 1)?1:0))/2) & ubyte.max;
            return find_bucket(start_j, start_j/2);
        }

        uint index(const uint depth) const pure {
            if ( isBucket ) {
                return _buckets[0].index(depth);
            }
            else {
                return _archive.index(depth);
            }
        }


        private uint find_bucket_pos(uint i)
            in {
                assert(i <= ubyte.max);
            }
        do {
            uint find_bucket_pos(immutable uint search_j, immutable uint division_j) {
                if ( search_j < _bucket_size ) {
                    immutable search_index=_buckets[search_j].index(depth);
                    if ( index(depth) == search_index ) {
                        return search_j;
                    }
                    else if ( division_j > 0 ) {
                        if ( index(depth) < search_index ) {
                            return find_bucket_pos(search_j-division_j, division_j/2);
                        }
                        else if ( index(depth) > search_index ) {
                            return find_bucket_pos(search_j+division_j, division_j/2);
                        }
                    }
                }
                return search_j;
            }
            immutable start_j=((_bucket_size+((_bucket_size % 2 == 1)?1:0))/2) & ubyte.max;
            return find_bucket_pos(start_j, start_j/2);
        }


        static size_t calc_init_size(size_t depth) {
            switch ( depth ) {
            case 0:
                return 32;
                break;
            case 1:
                return 4;
                break;
            default:
                return 1;
            }
        }

        static size_t calc_extend(size_t depth) {
            switch ( depth ) {
            case 0:
                return 16;
                break;
            case 1:
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

        private void opIndexAssign(Bucket b, const uint index) {
            immutable pos=find_bucket_pos(index);
            assert( _buckets[pos].index(depth) != index );
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

        private this(immutable uint depth) {
            this.depth=depth;
            init_size=calc_init_size(depth);
            extend=calc_extend(depth);

        }

        this(ArchiveTab _archive, immutable uint depth) {
            this(depth);
            _archive=_archive;
        }

        this(Document doc, SecureNet net, immutable uint depth) {
            this(depth);
            if ( doc.hasElement(Keywords.buckets) ) {
                auto buckets_doc=doc[Keywords.buckets].get!Document;
                _buckets=new Bucket[buckets_doc.length];
                foreach(elm; buckets_doc[]) {
                    auto arcive_doc=elm.get!Document;
                    immutable index=elm.key.to!ubyte;
                    this[index]=new Bucket(arcive_doc, net, depth+1);
                }
            }
            else if (doc.hasElement(Keywords.tab)) {
                // Fixme check that the Doc is HBSON
                auto arcive_doc=doc[Keywords.tab].get!Document;
                _archive=new ArchiveTab(net, arcive_doc.data);
            }
        }

        HBSON toBSON() const {
            auto bson=new HBSON;
            if ( isBucket ) {
                auto buckets=new HBSON;
                foreach(i;0.._bucket_size) {
                    auto b=_buckets[i];
                    buckets[b.index(depth).to!string]=b.toBSON;
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
            if ( isBucket ) {
                immutable index=key[depth];
                if ( _buckets[index] ) {
                    return _buckets[index].find(key);
                }
            }
            else if ( _archive && (_archive.fingerprint == key) ) {
                return _archive;
            }
            return null;
        }

        void add(SecureNet net, ArchiveTab archive) {
            _fingerprint=null;
            if ( isBucket ) {
                immutable pos=find_bucket_pos(archive.fingerprint[depth]);
                if (_buckets[pos].fingerprint(net) == archive.fingerprint ) {
                    throw new EventConsensusException(ConsensusFailCode.DART_ARCHIVE_ALREADY_ADDED);
                }
                auto temp_bucket=new Bucket(depth+1);
                temp_bucket.add(net, archive);
                if ( _bucket_size+1 <= _buckets.length ) {
                    foreach_reverse(i;pos.._bucket_size) {
                        _buckets[i+1]=_buckets[i];
                    }
                    _buckets[pos]=temp_bucket;
                    _bucket_size++;
                }
                else {
                    auto new_buckets=new Bucket[extend_size];
                    new_buckets[0..pos]=_buckets[0..pos];
                    new_buckets[pos+1.._bucket_size+1]=_buckets[pos.._bucket_size];
                    new_buckets[pos]=temp_bucket;
                    _buckets=new_buckets;
                    _bucket_size++;
                }
            }
            else if ( _archive is null ) {
                _archive=archive;
            }
            else {
                if ( _archive.index(depth) == archive.index(depth) ) {
                    _bucket_size=1;
                    _buckets=new Bucket[_bucket_size];
                    _buckets[0].add(net, _archive);
                    _buckets[0].add(net, archive);
                }
                else {
                    import std.algorithm : min;
                    immutable min_init_size=min(2,init_size);
                    _bucket_size=2;
                    _buckets=new Bucket[min_init_size];
                    auto _bucket1=new Bucket(_archive, depth+1);
                    auto _bucket2=new Bucket(archive, depth+1);
                    if ( _bucket1._archive.index(depth) < _bucket1._archive.index(depth) ) {
                        _buckets[0]=_bucket1;
                        _buckets[1]=_bucket2;
                    }
                    else {
                        _buckets[1]=_bucket1;
                        _buckets[0]=_bucket2;
                        _bucket_size=2;
                    }
                    _archive=null;
                }
            }
        }

        static void remove(ref Bucket bucket, SecureNet net, const ArchiveTab archive) {
            Bucket.remove(bucket, archive, 0);
        }

        @trusted
        private static void remove(ref Bucket bucket, const ArchiveTab archive, immutable uint level) {
            scope(success) {
                if ( bucket ) {
                    bucket._fingerprint=null;
                }
            }
            if ( bucket.isBucket ) {
                immutable index=archive.fingerprint[level];
                if ( bucket._buckets[index] ) {
                    Bucket.remove(bucket._buckets[index], archive, level+1);
                }
                else {
                    throw new EventConsensusException(ConsensusFailCode.DART_ARCHIVE_DOES_NOT_EXIST);
                }
            }
            else {
                bucket.destroy;
                bucket=null;
            }
        }

        immutable(ubyte[]) fingerprint(SecureNet net) {
            if ( _fingerprint ) {
                return _fingerprint;
            }
            else if ( isBucket ) {
                scope auto temp_buckets=new Bucket[bucket_max];
                foreach(i;0.._bucket_size) {
                    auto b=_buckets[i];
                    temp_buckets[b.index(depth)]=b;
                }
                _fingerprint=sparsed_merkeltree(net, temp_buckets);
                return _fingerprint;
            }
            else {
                return _archive.fingerprint;
            }
        }

        // uint length() const pure nothrow {
        //     return _count;
        // }

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
                return data;
            }
        }

        auto net=new TestNet;
        auto dart=new DART(net, 0x10, 0x42);
        immutable(ubyte[]) data(ulong x) {
            import std.bitmanip;
            return nativeToBigEndian(x).idup;
        }


        import std.stdio;

        immutable array=[
            0x10_10_10_10_10_10_10_10,
            0x10_10_10_10_10_10_10_10

            ];


        enum key_val=0x17_16_15_14_13_12_11_10;
        dart.add(data(key_val));

        auto key=data(key_val);
        writefln("key=%s %x", key, key_val);
        // auto d=dart.find(key);

        // writefln("%s", d.data);


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
