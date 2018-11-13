module tagion.vault.DART;

import tagion.hashgraph.GossipNet : SecureNet;
import tagion.utils.BSON : HBSON, Document;
import tagion.hashgraph.ConsensusExceptions;

import tagion.Keywords;
import std.conv : to;


@safe
class DART {
    private SecureNet _net;
    private ubyte _from_sector;
    private ubyte _to_sector;
    private Bucket _bucket;
    enum bucket_size=1 << (ubyte.sizeof*8);

    // class Section {
    //     private string _filename;
    //     private Bucket _bucket;
    // }

    // private Section[] _sections;

    this(SecureNet net, const ubyte from_sector, const ubyte to_sector) {
        _net=net;
        _from_sector=from_sector;
        _to_sector=to_sector;
//        _sections=new Section[calc_sector_size(_from_sector, _to_sector)];
    }

    void add(immutable(ubyte[]) data) {
        auto archive=new ArchiveTab(_net, data);
        if ( inRange(archive.fingerprint[0]) ) {
            _bucket.add(_net, archive);
        }
    }

    void remove(immutable(ubyte[]) data) {
        auto archive=new ArchiveTab(_net, data);
        if ( inRange(archive.fingerprint[0]) ) {
            Bucket.remove(_bucket, _net, archive);
        }
    }

    ArchiveTab find(immutable(ubyte[]) key) {
        return _bucket.find(key);
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

    static class Bucket {
        private Bucket[] _buckets;
        private ArchiveTab _archive;
        private uint _count;
        private immutable(ubyte)[]  _fingerprint;
        bool isBucket() const pure nothrow {
            return _buckets !is null;
        }

        private this() {
        }

        this(ArchiveTab _archive) {
            _archive=_archive;
        }

        this(Document doc, SecureNet net) {
            if ( doc.hasElement(Keywords.buckets) ) {
                _buckets=new Bucket[bucket_size];
                auto buckets_doc=doc[Keywords.buckets].get!Document;
                foreach(elm; buckets_doc[]) {
                    auto arcive_doc=elm.get!Document;
                    immutable index=elm.key.to!ubyte;
                    _buckets[index]=new Bucket(arcive_doc, net);
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
                foreach(i, b; _buckets) {
                    buckets[i.to!string]=b.toBSON;
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
            return find(key, 0);
        }

        private ArchiveTab find(immutable(ubyte[]) key, immutable uint level) {
            if ( isBucket ) {
                immutable index=key[level];
                if ( _buckets[index] ) {
                    return _buckets[index].find(key, level+1);
                }
            }
            else if ( _archive && (_archive.fingerprint == key) ) {
                return _archive;
            }
            return null;
        }

        void add(SecureNet net, ArchiveTab archive) {
            add(archive, net, 0);
        }

        private void add(ArchiveTab archive, SecureNet net, immutable uint level) {
            _fingerprint=null;
            if ( isBucket ) {
                immutable index=archive.fingerprint[level];
                if ( _buckets[index] ) {
                    if (_buckets[index].fingerprint(net) == archive.fingerprint ) {
                        throw new EventConsensusException(ConsensusFailCode.DART_ARCHIVE_ALREADY_ADDED);
                    }
                    else {
                        auto _bucket=new Bucket;
                        _bucket.add(_archive, net, level+1);
                        _bucket.add(archive, net, level+1);
                        _buckets[index]=_bucket;
                        _count++;
                        _archive=null;
                    }
                }
                else {
                    auto _bucket=new Bucket;
                    _bucket._archive=archive;
                    _buckets[index]=_bucket;
                    _count++;
                }
            }
            else if ( _archive is null ) {
                _archive=archive;
                _count=1;
            }
            else {
                _buckets=new Bucket[bucket_size];
                immutable index=archive.fingerprint[level];
                immutable _index=_archive.fingerprint[level];
                _buckets[index]=new Bucket(archive);
                _buckets[_index]=new Bucket(_archive);
                _count=2;
                _archive=null;
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
                    bucket._count--;
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
                immutable(ubyte[]) merkeltree(Bucket[] left, Bucket[] right) {
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
                immutable mid=_buckets.length >> 1;
                _fingerprint=merkeltree(_buckets[0..mid], _buckets[mid..$]);
                return _fingerprint;
            }
            else {
                return _archive.fingerprint;
            }
        }

        uint length() const pure nothrow {
            return _count;
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
        immutable(ubyte[]) data(uint x) {
            import std.bitmanip;
            return nativeToLittleEndian(x).idup;
        }


        import std.stdio;

//        dart.add(data(0x10));
//        auto key=data(0x10);
//        auto d=dart.find(key);

        writefln("%s", data(0x4858));


    }

    static uint calc_to_sector(const ubyte from_sector, const ubyte to_sector) pure nothrow {
        return to_sector+((from_sector >= to_sector)?bucket_size:0);
    }

    static uint calc_sector_size(const ubyte from_sector, const ubyte to_sector) pure nothrow {
        immutable uint from=from_sector;
        immutable uint to=calc_to_sector(from_sector, to_sector);
        return to-from;
    }


    bool inRange(const ubyte sector) const pure nothrow  {
        immutable ubyte sector_origin=(sector-_from_sector) & ubyte.max;
        immutable ubyte to_origin=(_to_sector-_from_sector) & ubyte.max;
        return ( sector_origin < to_origin );
    }

    unittest { // Check the inRange function
        import std.typecons : BlackHole;
        auto net=new BlackHole!SecureNet;

        auto dart1=new DART(net, 10, 88);
        assert(dart1.inRange(10));
        assert(dart1.inRange(42));
        assert(dart1.inRange(87));
        assert(!dart1.inRange(88));

        auto dart2=new DART(net, 231, 10);
        assert(!dart2.inRange(200));
        assert(dart2.inRange(231));
        assert(dart2.inRange(0));
        assert(dart2.inRange(9));
        assert(!dart2.inRange(10));
        assert(!dart2.inRange(42));
    }

}
