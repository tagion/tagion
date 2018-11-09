module tagion.vault.DART;

class DART {
    private SecureNet _net;
    private ubyte _from_sector;
    private ubyte _to_sector;
    enum bucket_size=256;

    class Buffer {
        immutable(ubyte[])  data;
        immutable(ubyte[])  fingerprint;
        this(SecureNet net, immutable(ubyte[])  data) {
            fingerprint=net.calcHash(data);
            this.data=data;
        }
    }

    class Bucket {
        private Bucket[] _buckets;
        private Buffer _buffer;
        private immutable(ubyte)[]  _fingerprint;
        bool isBucket() const pure nothrow {
            return _buckets !is null;
        }

        void add(SecureNet net, immutable(ubyte)[] data) {
            auto buffer=new Buffer(net, data);
            add(buffer, 0);
        }

        private void add(Buffer buffer, immutable uint level) {
            _fingerprint=null;
            if ( isBucket ) {
                immutable index=buffer.fingerprint[level];
                if ( _bucket[index] ) {
                    if (_bucket[index].fingerprint == buffer.fingerprint ) {
                        throw !!!; // Already added
                    }
                    else {
                        auto _bucket=new Bucket;
                        _bucket.add(_buffer, level+1);
                        _bucket.add(buffer, level+1);
                        _buffer=null;
                    }
                }
                else {
                    _bucket[index]=buffer;
                }
            }
            else if ( _buffer is null ) {
                _buffer=buffer;
            }
            else {
                _bucket=new Bucket[bucket_size];
                immutable index=buffer.fingerprint[level];
                immutable _index=_buffer.fingerprint[level];
                _bucket[index]=buffer;
                _bucket[_index]=_buffer;
                _buffer=null;
            }
        }

        static void remove(ref Bucket bucket, SecureNet net, immutable(ubyte)[] data) {
            scope buffer=new Buffer(net, data);
            remove(bucket, buffer, 0);
        }

        private static void remove(ref Bucket bucket, const Buffer buffer, immutable uint level) {
            scope(success) {
                if ( bucket ) {
                    bucket._fingerprint=null;
                }
            }
            if ( bucket.isBucket ) {
                immutable index=buffer.fingerprint[level];
                if ( bucket._bucket[index] ) {
                    bucket._bucket[index].remove(net, level+1);
                    if ( bucket._bucket[index] is null ) {
                    }
                    if ( _bucket[index].isBucket ) {

                    }
                }
                else {
                    throw !!!; /// Does not exist
                }
            }
            else {

            }
        }

        immutable(ubyte[]) fingerprint(SecureNet net) {
            if ( _fingerprint ) {
                return _fingerprint;
            }
            else if ( isBucket ) {
                immutable(ubyte[]) merkeltree(const Bucket[] left, const Bucket[] right) {
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
                        immutable left_mid=_left.length >> 1;
                        immutable right_mid=_right.length >> 1;
                        _left_fingerprint=merkeltree(_left[0..left_mid_], _left[left_mid..$]);
                        _right_fingerprint=merkeltree(_right[0..right_mid_], _right[right_mid..$]);
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
                immutable mid=_bucket.length >> 1;
                _fingerprint=merkeltree(_buffer[0..mid], _buffer[mid..$]);
                return _fingerprint;
            }
            else {
                return _buffer.fingerprint;
            }
        }
    }

    class Section {
        private string _filename;
        private Bucket _bucket;
    }



    private Section[] _sections;
    this(SecureNet net, const ubyte from_sector, const ubyte to_sector) {
        _net=net;
        _from_sector=from_sector;
        _to_sector=to_sector;
        _sections=new Section[calc_sector_size(_from_sector, _to_sector)];
    }

    static uint calc_to_sector(const ubyte from_sector, const ubyte to_sector) {
        return to_sector+(from_sector >= to_sector)?bucket_size:0;
    }

    static uint calc_sector_size(const ubyte from_sector, const ubyte to_sector) {
        immutable uint from=_from_sector;
        immutable uint to=calc_to_section(_from_sector, _to_sector);
        return to-from;
    }

    bool inRange(const ubyte sector) const pure nothrow {
        immutable uint from=_from_sector;
        immutable uint to=calc_to_sector(_from_sector, _to_sector);
        return ( ( sector >= from) && ( sector < to ) );
    }

    uint sectionIndex(const ubyte sector) const pure nothrow {
        return
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
        assert(dart2.inRang(0));
        assert(dart2.inRange(9));
        assert(!dart2.inRange(10));
        assert(!dart2.inRange(42));
    }



}
