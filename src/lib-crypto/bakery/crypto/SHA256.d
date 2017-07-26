module bakery.crypto.SHA256;

import bakery.crypto.Hash;
import tango.util.digest.Sha256 : Sha256;
import std.exception : assumeUnique;

@safe
class SHA256 : Hash {
    private Sha256 sha256_core;
//    alias immutable(ubyte)[size_of_hash] ;
//    private immutable(ubyte)[] data;
    private immutable(ubyte)[8] hashed;
    this(scope const(ubyte)[] data) {
        sha256_core = new Sha256;
        sha256_core.update(data);
        hashed=sha256_core.binaryDigiets().idup;
//        this.data=data;
    }
    static immutable(uint) buffer_size() pure nothrow {
        return 32;
    }
    static immutable(SHA256) opCall(scope const(ubyte)[] data) pure {
        auto result = new Hash(data);
        return assumeUnique(result);
    }
    static immutable(SHA256) opCall(const(Hash) left, const(Hash) right) pure {
        scope immutable(ubyte)[] data;
        data~=left.hashed;
        data~=right.hashed;
        return this.opCall(data);
    }
    immutable(char)[] hexDigest () {
        char[] buffer;
        return assumeUnique(sha256_core.hexDigest(buffer));
    }
    immutable(ubyte)[] signed() const pure nothrow {
        return buffer;
    }
    bool isEqual(const(Hash) h) pure const {
        static assert(is(Hash : SHA256));
        return h.buffer == buffer;
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
            "Go dav do!",
            // echo "Dette er bare en laenger historie, for at set om vores Merkle Damgaard virker, det burde get goer" | sha256sum
            "Dette er bare en laenger historie, for at set om vores Merkle " ~
            "Damgaard virker, det burde get goer",
            // echo "In this example. The Linux command sha256 has been used to generate the hash values" | sha256sum
            "In this example. The Linux command sha256 has been used to generate the hash values"
            ];

        enum immutable(char)[][] results = [
            "8274aeb4c6c22340d682a2037a601378faaed52cedd3ccfc796f7dbab73d81f4",
            "c2fb4e5c40809031a0bbd29cd8af0fabb2cebefa096e89d8bcda462c03699da5",
            "c227722cd9cad6ff4961310fb9c3d36eff5f124739c24c4c4ba45dc9071f586b"
            ];
        foreach(i, s; strings) {
            auto h=SHA256(s);
            auto hex = h.hexDigist;
            assert(hex == results[i], "Cipher:("~s~")("~d~")!=("~results[i]~")");
        }
    }
}
