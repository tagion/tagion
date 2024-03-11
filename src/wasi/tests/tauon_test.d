module tests.tauon_test;

import tvm.wasi_main;
import stdc=core.stdc.stdio;
import std.stdio;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONtoText;
import tagion.hibon.Document;
import tagion.basic.Types : base64=encodeBase64, Buffer;
import tagion.crypto.SecureNet;

static this() {
    writefln(" should call this\n");
    stdout.flush;
}
static ~this() {
    writefln(" should call ~this\n");
}
pragma(msg, "Main ", main.mangleof);
void main() {
    printf("--- Main\n");
    interface I {
        int times2() const pure nothrow ;
    }
    class C {
        int x;
        this(int x) {
            this.x=x;    
        }
        int times2() const pure nothrow {
            return x*2;
        }
    }

    class C2 : C {
        this(int x) {
            super(x);
        }
        override int times2() const pure nothrow {
            return x*3;
        }
    }
    int[] a;
    a~=10;
    printf("a=%d\n", a[0]);

    writefln("a=%s", a);
    auto h=new HiBON;
    h["hugo"]=42;
    writefln("h=%s", h["hugo"].get!int);
    writefln("h=%s", h.serialize);
    writefln("h=%s", h.toPretty);
    writefln("h=%(%02x%)", h.serialize);
    writefln("h=%s", h.serialize.base64);
    const doc=Document(h);
    writefln("doc=%s", doc.toPretty);
    writefln("doc=%s", doc.encodeBase64);
    writefln("doc.serialize=%s", doc.serialize);

    const c=new C(10);

    writefln("c=%s", c);
    const(HashNet) hash_net=new StdHashNet;
    writefln("hash_net !is null", hash_net !is null);
    Buffer buf=doc.serialize;
    writefln("buffer=%(%02x %)", buf);

    const c2=new C2(42);
    writefln("c2.times2=%s", c2.times2);
  
    //writefln("hast_net.hashSize=%d", hash_net.hashSize);
   // writefln("hash=%s", hash_net.calcHash(doc.serialize));
    import std.digest;
    import std.digest.sha : SHA256;
    auto dig=digest!SHA256(buf);
    writefln("dig=%(%02x %)", dig);
    writefln("dig.idup=%(%02x %)", dig.idup);

    const _func=&(hash_net.rawCalcHash);
    writefln("############## _func=%s", typeof(_func).stringof);
    writefln("############## _func.funcptr=%x", cast(size_t)(_func.funcptr));
    auto hash_net_typeid=typeid(hash_net);
    writefln("c=%s", c);
    writefln("hash_net.name=%s", hash_net_typeid);
    writefln("hash_net.name=%s", hash_net_typeid.name);

   buf = hash_net.rawCalcHash(buf);
   
    writefln("%(%02x %)", buf);
    writefln("%s", buf.base64);
    //writefln("############## _func.ptr=%x", cast(size_t)(_func.ptr));
    //auto x=_func(buf);
}

