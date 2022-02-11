/// \file net_test.d

import tagion.crypto.SecureNet;
import tagion.hibon.Document : Document;

import betterC_doc = tagion.BetterC.Document;

import beterC_hibon = tagion.BetterC.hibon.HiBON;
import usual_hibon = tagion.hibon.HiBON;

import secure_net = tagion.crypto.SecureNet;
import betterC_net = tagion.BetterC.wallet.Net;

unittest { // StdHashNet
    //import tagion.utils.Miscellaneous : toHex=toHexString;
    import std.string: representation;
    import std.exception: assertThrown;
    import core.exception: AssertError;

    // import std.stdio;

    const d_net = new secure_net.StdHashNet;
    Document doc; // This is the data which is filed in the DART
    {
        auto hibon_d = new usual_hibon.HiBON;
        hibon_d["text"] = "Some text";
        doc = Document(hibon_d);
    }

    immutable doc_fingerprint = d_net.rawCalcHash(doc.serialize);

    {
        assert(d_net.calcHash(null, null).length is 0);
        assert(d_net.calcHash(doc_fingerprint, null) == doc_fingerprint);
        assert(d_net.calcHash(null, doc_fingerprint) == doc_fingerprint);
    }

    immutable stub_fingerprint = d_net.calcHash(doc_fingerprint, doc_fingerprint);
    Document stub;
    {
        auto hibon_d = new usual_hibon.HiBON;
        hibon_d[STUB] = stub_fingerprint;
        stub = Document(hibon_d);
    }

    assert(d_net.hashOf(stub) == stub_fingerprint);

    enum key_name = "#name";
    enum keytext = "some_key_text";
    immutable hashkey_fingerprint = d_net.calcHash(keytext.representation);
    Document hash_doc;
    {
        auto hibon_d = new usual_hibon.HiBON;
        hibon_d[key_name] = keytext;
        hash_doc = Document(hibon_d);
    }

    assert(d_net.hashOf(hash_doc) == hashkey_fingerprint);

    // betterC
    const betterC_net.SecureNet net;
    betterC_doc.Document doc_betterC; // This is the data which is filed in the DART
    {
        beterC_hibon.HiBON hibon_bC;
        hibon_bC["text"] = "Some text";
        doc_betterC = Document(hibon_bC);
    }

    immutable doc_fingerprint = net.rawCalcHash(doc_betterC.serialize);

    {
        assert(net.calcHash(null, null).length is 0);
        assert(net.calcHash(doc_fingerprint, null) == doc_fingerprint);
        assert(net.calcHash(null, doc_fingerprint) == doc_fingerprint);
    }

    immutable stub_fingerprint = net.calcHash(doc_fingerprint, doc_fingerprint);
    betterC_doc.Document stub_bC;
    {
        beterC_hibon.HiBON hibon_bC;
        hibon_bC[STUB] = stub_fingerprint;
        stub_bC = Document(hibon_bC);
    }

    assert(net.hashOf(stub_bC) == stub_fingerprint);

    enum key_name = "#name";
    enum keytext = "some_key_text";
    immutable hashkey_fingerprint = net.calcHash(keytext.representation);
    betterC_doc.Document hash_doc_bC;
    {
        beterC_hibon.HiBON hibon_bC;
        hibon_bC[key_name] = keytext;
        hash_doc_bC = Document(hibon_bC);
    }

    assert(net.hashOf(hash_doc_bC) == hashkey_fingerprint);

}
