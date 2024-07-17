module tests.tauon_test;

import tvm.wasi_main;
import stdc=core.stdc.stdio;
import std.stdio;
import std.string;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONtoText;
import tagion.hibon.Document;
import tagion.basic.Types : base58=encodeBase58, Buffer;
import tagion.crypto.SecureNet;
import tagion.crypto.random.random;
import tagion.crypto.secp256k1.c.secp256k1;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.utils.Miscellaneous : decode;
import tagion.api.document;
import tagion.api.hibon;
import tagion.api.errors;
import core.stdc.stdlib;
import tagion.api.wallet;
import tagion.api.basic;

static this() {
    writefln(" should call this\n");
    stdout.flush;
}
static ~this() {
    writefln(" should call ~this\n");
}

void test_document() {
    auto h=new HiBON;
    string key_i32="i32";
    string key_i64="i64";
    h["i32"]=42;
    h["i64"]=-42L;
    const doc= Document(h);

    Document.Element elm_i32, elm_i64;
    {
        const rt=tagion_document(&doc.data[0], doc.data.length, &key_i32[0], key_i32.length, &elm_i32);
        writefln("rt=%s", rt);
        writefln("elm.type %s", elm_i32.type);
        writefln("elm.data %(%02x %)", elm_i32.data[0..8]);
    }
    {
        const rt=tagion_document(&doc.data[0], doc.data.length, &key_i64[0], key_i64.length, &elm_i64);
        writefln("rt=%s", rt);
        writefln("elm.type %s", elm_i64.type);
        writefln("elm.data %(%02x %)", elm_i64.data);

    }
    {
        int value;
        const rt=tagion_document_get_int32(&elm_i32, &value);
        writefln("rt=%s", rt);
        writefln("value=%s", value);
        
    }
}

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
    writefln("h=%s", h.serialize.base58);
    const doc=Document(h);
    writefln("doc=%s", doc.toPretty);
    writefln("doc=%s", doc.encodeBase58);
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
    writefln("%s", buf.base58);
        auto _ctx = secp256k1_context_create(SECP256K1_CONTEXT_NONE);
    //const secp256k1=new NativeSecp256k1;
    //writefln("############## _func.ptr=%x", cast(size_t)(_func.ptr));
    //auto x=_func(buf);
    writefln("---- random -------");
    ubyte[] data;
    data.length=32;
    getRandom(data);
    writefln("Random data=%(%02x %)", data);
    getRandom(data);
    writefln("Random data=%(%02x %)", data);
    writefln("---- SecureNet ----");

  
    writefln("## - ###");
    {
    const aux_random = "b0d8d9a460ddcea7ae5dc37a1b5511eb2ab829abe9f2999e490beba20ff3509a".decode;
    const msg_hash = "1bd69c075dd7b78c4f20a698b22a3fb9d7461525c39827d6aaf7a1628be0a283".decode;
    const secret_key = "e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71".decode;
    const expected_pubkey = "02ecd21d66cf97843d467c9d02c5781ec1ec2b369620605fd847bd23472afc7e74".decode;
    const expected_signature = "021e9a32a12ead3144bb230a81794913a856296ed369159d01b8f57d6d7e7d3630e34f84d49ec054d5251ff6539f24b21097a9c39329eaab2e9429147d6d82f8"
        .decode;
    const expected_keypair = decode("e46b4b2b99674889342c851f890862264a872d4ac53a039fbdab91fd68ed4e71747efc2a4723bd47d85f602096362becc11e78c5029d7c463d8497cf661dd2eca89c1820ccc2dd9b0e0e5ab13b1454eb3c37c31308ae20dd8d2aca2199ff4e6b");
    auto crypt = new NativeSecp256k1;
    //secp256k1_keypair keypair;
    ubyte[] keypair;
    crypt.createKeyPair(secret_key, keypair);
        writefln("createKeyPair");
        assert(keypair == expected_keypair);
    const signature = crypt.sign(msg_hash, keypair, aux_random);
        writefln("signature=%(%02x %)", signature);
        assert(signature == expected_signature);
        const pubkey = crypt.getPubkey(keypair);
        assert(pubkey == expected_pubkey);
       // writefln("pubkey   =%(%02 %)", pubkey);
        const signature_ok = crypt.verify(msg_hash, signature, pubkey);
        writefln("signature_ok=%s", signature_ok);
        //assert(signature_ok, "Schnorr signing failed");

    }
    auto net=new StdSecureNet;
    net.generateKeyPair("Very secret");
    const pubkey=net.pubkey;
    writefln("pubkey   =%s len=%d", pubkey.base58, pubkey.length);
    const message=hash_net.calcHash(doc);

    char* test;
    size_t test_len;
    tagion_basic_encode_base58url(&message[0], message.length, &test, &test_len); 
    writefln("message  =%s", message.base58);
    const signature=net.sign(message);
    writefln("signature=%s len=%d", signature.base58, signature.length);
    writefln("Before verify"); 
    const ok=net.verify(message, signature, pubkey);

    writefln("verify = %s", ok);
    test_document();
}

