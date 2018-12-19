module tagion.dart.StdDARTNet;

import tagion.hashgraph.Net : StdSecureNet;
import tagion.hashgraph.GossipNet : DARTNet;
import tagion.crypto.Hash : toHexString;

import std.path;
import std.file;

@safe
class StdDARTNet : StdSecureNet, DARTNet {
    private string path;
    enum extend="dart";
    enum max_size=0x1000;
    import tagion.crypto.secp256k1.NativeSecp256k1 : NativeSecp256k1;

    this(NativeSecp256k1 crypt, string path) {
        super(crypt);
        this.path = path;
        assert(isValidPath(this.path));
    }

    string fullpath(const(ubyte[]) key) {
        return buildPath(path, key[0..4].toHexString);
    }

    string fullfilename(const(ubyte[]) key) {
        auto filename=setExtension(key.toHexString, extend);
        return buildPath(path, key[0..4].toHexString, filename);
    }

    @trusted
    immutable(ubyte[]) load(const(ubyte[]) key)
    out(result) {
        assert(calcHash(result) == key);
    }
    do {
        immutable result=(cast(ubyte[])(read(fullfilename(key), max_size+1))).idup;
        assert(result.length < max_size);
        return result;
    }

    void save(const(ubyte[]) key, immutable(ubyte[]) data)
        in {
            assert(calcHash(data) == key);
        }
    do {
        auto _fullpath=fullpath(key);
        if ( !_fullpath.exists ) {
            _fullpath.mkdirRecurse;
        }
        write(fullfilename(key), data);
    }

    void erase(const(ubyte[]) key) {
        auto _fullfilename=fullfilename(key);
        if ( _fullfilename.exists ) {
            _fullfilename.remove;
        }
    }
}
