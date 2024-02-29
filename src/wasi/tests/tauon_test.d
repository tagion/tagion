module tests.tauon_test;

import tvm.wasi_main;
import core.stdc.stdio;
import std.stdio;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONtoText;
import tagion.hibon.Document;
import tagion.basic.Types : base64=encodeBase64;

void main() {
    printf("--- Main\n");
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
}

