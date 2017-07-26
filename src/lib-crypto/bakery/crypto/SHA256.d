module bakery.crypto.SHA256;

import bakery.crypto.Hash;
import tango.util.digest.Sha256 : Sha256;
import std.exception : assumeUnique;

@safe
class SHA256 : Hash {
//    private Sha256 sha256_core;
//    alias immutable(ubyte)[size_of_hash] ;
//    private immutable(ubyte)[] data;
    enum hash_size=32;
    alias immutable(ubyte)[] hash_array_t;
    private hash_array_t _hashed;
    this(scope const(ubyte)[] data) {
        immutable(ubyte)[] createSha256() @trusted
            out(result) {
                    assert(result.length == hash_size);
                }
        body {
            auto sha256_core = new Sha256;
            sha256_core.update(data);
            return sha256_core.binaryDigest.idup;
        }
        _hashed=cast(hash_array_t)createSha256()[0..hash_size];
    }
    static immutable(uint) buffer_size() pure nothrow {
        return 32;
    }
    @trusted
    static immutable(SHA256) opCall(scope const(ubyte)[] data) {
        auto result = new SHA256(data);
        return cast(immutable)result;
    }
    @trusted
    static SHA256 opCall(const(char)[] str) {
        const(ubyte)[] data = (cast(const(ubyte)*)str.ptr)[0..str.length];
        auto result = new SHA256(data);
        return result;
    }
    static immutable(SHA256) opCall(const(SHA256) left, const(SHA256) right) {
        scope immutable(ubyte)[] data;
        data~=left.signed;
        data~=right.signed;
        return SHA256(data);
    }
    version(node)
    immutable(char)[] hexDigest () {
        char[] buffer;
        return assumeUnique(sha256_core.hexDigest(buffer));
    }

    override immutable(ubyte)[] signed() const pure nothrow {
        return _hashed;
    }
    override immutable(char)[] hex() const pure nothrow {
        return .hex(_hashed);
    }
    bool isEqual(const(SHA256) h) pure const nothrow {
        return h.signed == signed;
    }
    /*
    override bool opEquals(Object h) {
        if ( is(typeof(h) : SHA256) ) {
            return false;
        }
        return isEqual(h);
    }
    */
    unittest {
        enum immutable(char)[][] strings = [
            // Here the sha256sum has been used to verify the sha256 hash
            // echo "Go dav do!" | sha256sum
//            "Go dav do!",
//            "0Go dav",
            "Go dav do!",
            // echo "Dette er bare en laenger historie, for at set om vores Merkle Damgaard virker, det burde get goer" | sha256sum
            "Dette er bare en laenger historie, for at set om vores Merkle " ~
            "Damgaard virker, det burde get goer",
            // echo "In this example. The Linux command sha256 has been used to generate the hash values" | sha256sum
            "In this example. The Linux command sha256 has been used to generate the hash values"
            ];

        enum immutable(char)[][] results = [
            "d85e36494ed350f5ec5135d1431145831f53a6416fb58bb03be9040e00a4f0a6",
//            "8274aeb4c6c22340d682a2037a601378faaed52cedd3ccfc796f7dbab73d81f4",
            "c2fb4e5c40809031a0bbd29cd8af0fabb2cebefa096e89d8bcda462c03699da5",
            "c227722cd9cad6ff4961310fb9c3d36eff5f124739c24c4c4ba45dc9071f586b"
            ];
        foreach(i, s; strings) {
            auto h=SHA256(s);
            auto d = h.hex;
            assert(d == results[i], "Cipher:("~s~")("~d~")!=("~results[i]~")");
        }
    }
}
