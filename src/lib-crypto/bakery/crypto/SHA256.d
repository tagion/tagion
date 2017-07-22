module Bakery.crypto.SHA256;

import Bakery.crypto.Hash;
private alias tango.util.digest digest;

class SHA256 : Hash {
    private digest.Sha256 sha256_core;
    alias private immutable(ubyte)[size_of_hash] ;
    private immutable(ubyte)[] data;
    this(immutable(ubyte)[] data) {
        sha256_core = new digist.Sha256;
        sha256_core.update(data);
        this.data=data;
    }
    static Hash opCall(immutable(ubyte)[] data) {
        auto result = new Hash(data);
        return result;
    }
    char[] hexDigest (char[] buffer = null) {
        return sha256_core.hexDigest(buffer);
    }
    unittest() {
        enum immutable(char)[][] strings = [
            // Here the sha256sum has been used to verify the sha256 hash
            // echo "Go dav do!" | sha256sum
            "Go dav do!",
            // echo "Dette er bare en laenger historie, for at set om vores Merkle Damgaard virker, det burde get goer" | sha256sum
            "Dette er bare en laenger historie, for at set om vores Merkle "
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
