module tagion.crypto.aes.AESCrypto;

private import tagion.crypto.aes.aes;
private import std.format;

alias AES128=AESCrypto!128;
//alias AES196=AESCrypto!196; // AES196 results in a segment fault for unknown reason
alias AES256=AESCrypto!256;

struct AESCrypto(int KEY_LENGTH) {
    enum KEY_SIZE=KEY_LENGTH/8;
    static assert((KEY_LENGTH is 128) || (KEY_LENGTH is 196) || (KEY_LENGTH is 256), format("The KEYLENGTH of the %s must be 128, 196 or 256 not %d", AESCrypto.stringof, KEY_LENGTH));

    @disable this();
    static size_t enclength(const size_t inputlength) {
        return ((inputlength/AES_BLOCK_SIZE)+((inputlength % AES_BLOCK_SIZE==0)?0:1)) * AES_BLOCK_SIZE;
    }

    version(none)
    static private void cipher_stream(const(ubyte[]) indata, ubyte[] outdata)
        in {
            assert(indata);
            assert(indata.length == outdata.length);
            assert(indata.length % _aes.blockSize == 0);
        }
    do {
        for(size_t i=0; i<indata.length; i+=_aes.blockSize) {
            immutable last=i+_aes.blockSize;
            _aes.update(indata[i..last], outdata[i..last]);
        }
    }


    @trusted
    static void crypt(bool ENCRYPT=true)(const(ubyte[]) key, const(ubyte[]) indata, ref ubyte[] outdata)
        in {
            assert(indata);
            if (outdata !is null) {
                assert(enclength(indata.length) == outdata.length, format("Output data must be an equal number of %d bytes", AES_BLOCK_SIZE));
            }
            assert(key.length is KEY_SIZE, format("The key size must be %d bytes not %d", KEY_SIZE, key.length));
        }
    do {
        auto aes_key=key.ptr;
//        const inputlength=indata.length;
//        scope ubyte[KEY_SIZE] mem_key;
        scope ubyte[AES_BLOCK_SIZE] mem_iv;
        auto iv=mem_iv.ptr;
        AES_KEY crypt_key;
        if ( outdata is null ) {
            outdata=new ubyte[enclength(indata.length)];
        }

        static if (ENCRYPT) {
            auto aes_input=indata.ptr;
            auto enc_output=outdata.ptr;
            AES_set_encrypt_key(aes_key, KEY_LENGTH, &crypt_key);
            //writefln("crypt_key=%s", crypt_key.hex);
            AES_cbc_encrypt(aes_input, enc_output, indata.length, &crypt_key, iv, AES_ENCRYPT);
        }
        else {
            auto enc_input=indata.ptr;
            auto dec_output=outdata.ptr;
            AES_set_decrypt_key(aes_key, KEY_LENGTH, &crypt_key);
            AES_cbc_encrypt(enc_input, dec_output, enclength(indata.length), &crypt_key, iv, AES_DECRYPT);

        }
    }

    alias encrypt=crypt!true;
    alias decrypt=crypt!false;

    unittest {
        import tagion.utils.Random;

        Random!uint random;
        random.seed(1234);
        immutable(ubyte[]) gen_key() {
            ubyte[KEY_SIZE] result;
            foreach(ref a; result) {
                result=cast(ubyte)random.value(ubyte.sizeof+1);
            }
            return result.idup;
        }
        immutable aes_key=gen_key;
        string text="Some very secret message!!!!!";
        auto input=cast(immutable(ubyte[]))text;
        ubyte[] enc_output;
        AESCrypto.encrypt(aes_key, input, enc_output);

        assert(input != enc_output[0..input.length]);
        ubyte[] dec_output;
        AESCrypto.decrypt(aes_key, enc_output, dec_output);
        assert(input == dec_output[0..input.length]);

    }
}
