module tagion.dart.StdDARTNet;

import tagion.hashgraph.Net : StdSecureNet;
import tagion.hashgraph.GossipNet : DARTNet;
import tagion.crypto.Hash : toHexString;

import std.path;
import std.file;
import std.array : join;
import std.stdio : writefln;

@safe
class StdDARTNet : StdSecureNet, DARTNet {
    private immutable(char[]) root;
    enum extend="dart";
    enum max_size=0x1000;
    import tagion.crypto.secp256k1.NativeSecp256k1 : NativeSecp256k1;

    this(NativeSecp256k1 crypt, string root) {
        super(crypt);
        this.root = root;
        assert(isValidPath(this.root));
        if ( !root.exists ) {
            root.mkdirRecurse;
        }
    }

    string fullpath(const(string[]) path) {
        return buildPath(join([[root], path]));
    }

    string fullfilename(const(string[]) path, const(ubyte[]) key) {
        auto filename=setExtension(key.toHexString!true, extend);
        return buildPath(join([[root], path, [filename]]));
    }

    @trusted
    immutable(ubyte[]) load(const(string[]) path, const(ubyte[]) key)
    out(result) {
        assert(calcHash(result) == key);
    }
    do {
        auto _fullfilename=fullfilename(path, key);
        immutable result=(cast(ubyte[])(read(_fullfilename, max_size+1))).idup;
        assert(result.length < max_size);
        return result;
    }

    void save(const(string[]) path, const(ubyte[]) key, immutable(ubyte[]) data)
        in {
            assert(calcHash(data) == key);
        }
    do {
        auto _fullpath=fullpath(path);
        if ( !_fullpath.exists ) {
            _fullpath.mkdirRecurse;
        }
        auto _fullfilename=fullfilename(path, key);
//        writefln("write file %s", _fullfilename);
        write(_fullfilename, data);
    }

    void erase(const(string[]) path, const(ubyte[]) key) {
        auto _fullfilename=fullfilename(path, key);
        if ( _fullfilename.exists ) {
            _fullfilename.remove;
        }
    }
}
