module tagion.crypto.Cypher;


struct Cypher {
    import tagion.crypto.secp256k1.NativeSecp256k1;


    unittest {
        import std.stdio;
        import tagion.utils.Miscellaneous: toHexString, decode;
        auto crypt = new NativeSecp256k1(NativeSecp256k1.Format.RAW, NativeSecp256k1.Format.RAW);
        const PrivKey = decode("039c28258a97c779c88212a0e37a74ec90898c63b60df60a7d05d0424f6f6780");
        const PublicKey = crypt.computePubkey(PrivKey, false);

        // Random
        const ciphertextPrivKey = decode("f2785178d20217ed89e982ddca6491ed21d598d8545db503f1dee5e09c747164");
        const ciphertextPublicKey = crypt.computePubkey(ciphertextPrivKey, false);

        const sharedECCKey = crypt.createECDHSecret(ciphertextPrivKey, PublicKey);
        const sharedECCKey_2 = crypt.createECDHSecret(PrivKey, ciphertextPublicKey);

        writefln("sharedECCKey   %s", sharedECCKey.toHexString);
        writefln("sharedECCKey_2 %s", sharedECCKey_2.toHexString);

//        const secretKey = crypt.createECDHSecret(ciphertextPrivKey, bobPublicKey);


    }
}
