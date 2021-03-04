module tagion.crypto.aes.AESCrypto;

private import std.format;

alias AES128=AESCrypto!128;
//alias AES196=AESCrypto!196; // AES196 results in a segment fault for unknown reason
alias AES256=AESCrypto!256;
import std.stdio;

struct AESCrypto(int KEY_LENGTH) {
    enum KEY_SIZE=KEY_LENGTH/8;
    static assert((KEY_LENGTH is 128) || (KEY_LENGTH is 196) || (KEY_LENGTH is 256),
        format("The KEYLENGTH of the %s must be 128, 196 or 256 not %d", AESCrypto.stringof, KEY_LENGTH));

    @disable this();
    static size_t enclength(const size_t inputlength) {
        return ((inputlength/AES_BLOCK_SIZE)+((inputlength % AES_BLOCK_SIZE==0)?0:1)) * AES_BLOCK_SIZE;
    }

    version(tiny_aes) {
        import tagion.crypto.aes.c.aes;
        enum AES_BLOCK_SIZE=16;
        @trusted
            static void crypt(bool ENCRYPT=true)(const(ubyte[]) key, ref ubyte[] data)
            in {
                assert(data);
                //     assert(data.length % AES_BLOCK_SIZE == 0, format("Data must be an equal number of %d bytes but is %d", AES_BLOCK_SIZE, data.length));
                assert(key.length is KEY_SIZE, format("The key size must be %d bytes not %d", KEY_SIZE, key.length));
            }
        do {
            AES_ctx ctx;
            auto aes_key=key.ptr;
            scope ubyte[16] mem_iv;
            auto iv=mem_iv.ptr;
//            AES_KEY crypt_key;
            AES_init_ctx_iv(&ctx, aes_key, iv);
            auto data_ptr=data.ptr;
            static if (ENCRYPT) {
                AES_CBC_encrypt_buffer(&ctx, data_ptr, data.length);
            }
            else {
                AES_CBC_decrypt_buffer(&ctx, data_ptr , data.length);
            }
        }

        static void crypt_parse(bool ENCRYPT=true)(const(ubyte[]) key, const(ubyte[]) indata, ref ubyte[] outdata)
            in {
                if (outdata !is null) {
                    writefln("outdata.length=%d indata.length=%d", outdata.length, indata.length);

                    assert(enclength(indata.length) == outdata.length, format("Output data must be an equal number of %d bytes", AES_BLOCK_SIZE));
                }
            }
        do {
            if (outdata is null) {
                outdata = indata.dup;
            }
            else {
                writefln("outdata.length=%d indata.length=%d", outdata.length, indata.length);
                outdata[0..$] = indata[0..$];
            }
            crypt!ENCRYPT(key, outdata);
        }

        alias encrypt=crypt_parse!true;
        alias decrypt=crypt_parse!false;
    }
    else {
        import tagion.crypto.aes.aes;

        @trusted
            static void crypt(bool ENCRYPT=true)(const(ubyte[]) key, const(ubyte[]) indata, ref ubyte[] outdata)
            in {
                assert(indata);
                if (outdata !is null) {
                    assert(enclength(indata.length) == outdata.length,
                        format("Output data must be an equal number of %d bytes", AES_BLOCK_SIZE));
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

    }

    unittest {
        import tagion.utils.Random;

        {
            immutable(ubyte[]) indata  = [
                0x6b, 0xc1, 0xbe, 0xe2, 0x2e, 0x40, 0x9f, 0x96, 0xe9, 0x3d, 0x7e, 0x11, 0x73, 0x93, 0x17, 0x2a,
                0xae, 0x2d, 0x8a, 0x57, 0x1e, 0x03, 0xac, 0x9c, 0x9e, 0xb7, 0x6f, 0xac, 0x45, 0xaf, 0x8e, 0x51,
                0x30, 0xc8, 0x1c, 0x46, 0xa3, 0x5c, 0xe4, 0x11, 0xe5, 0xfb, 0xc1, 0x19, 0x1a, 0x0a, 0x52, 0xef,
                0xf6, 0x9f, 0x24, 0x45, 0xdf, 0x4f, 0x9b, 0x17, 0xad, 0x2b, 0x41, 0x7b, 0xe6, 0x6c, 0x37, 0x10 ];
            immutable(ubyte[]) outdata = [
                0xf5, 0x8c, 0x4c, 0x04, 0xd6, 0xe5, 0xf1, 0xba, 0x77, 0x9e, 0xab, 0xfb, 0x5f, 0x7b, 0xfb, 0xd6,
                0x9c, 0xfc, 0x4e, 0x96, 0x7e, 0xdb, 0x80, 0x8d, 0x67, 0x9f, 0x77, 0x7b, 0xc6, 0x70, 0x2c, 0x7d,
                0x39, 0xf2, 0x33, 0x69, 0xa9, 0xd9, 0xba, 0xcf, 0xa5, 0x30, 0xe2, 0x63, 0x04, 0x23, 0x14, 0x61,
                0xb2, 0xeb, 0x05, 0xe2, 0xc3, 0x9b, 0xe9, 0xfc, 0xda, 0x6c, 0x19, 0x07, 0x8c, 0x6a, 0x9d, 0x1b ];
            static if (KEY_LENGTH is 256) {
                immutable(ubyte[]) key = [
                    0x60, 0x3d, 0xeb, 0x10, 0x15, 0xca, 0x71, 0xbe, 0x2b, 0x73, 0xae, 0xf0, 0x85, 0x7d, 0x77, 0x81,
                    0x1f, 0x35, 0x2c, 0x07, 0x3b, 0x61, 0x08, 0xd7, 0x2d, 0x98, 0x10, 0xa3, 0x09, 0x14, 0xdf, 0xf4 ];
            }
            else static if (KEY_LENGTH is 192) {
                immutable(ubyte[]) key = [
                    0x8e, 0x73, 0xb0, 0xf7, 0xda, 0x0e, 0x64, 0x52, 0xc8, 0x10, 0xf3, 0x2b, 0x80, 0x90, 0x79, 0xe5,
                    0x62, 0xf8, 0xea, 0xd2, 0x52, 0x2c, 0x6b, 0x7b ];
            }
            else static if (KEY_LENGTH is 128) {
                immutable(ubyte[]) key = [
                    0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c ];

            }
            ubyte[] enc_output;
            AESCrypto.decrypt(key, indata, enc_output);
            writefln("enc_output=%s", enc_output);
            writefln("   outdate=%s", outdata);

            writeln("\n\n");
        }

        {
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
        writefln("input     (%3d)=%s", input.length, input);
        writefln("enc_output(%3d)=%s", enc_output.length, enc_output);
//        writefln("input          =%s", input.length, input[0..16]);
        writefln("enc_output     =%s", enc_output[0..16]);


        assert(input != enc_output[0..input.length]);
        ubyte[] dec_output;
        AESCrypto.decrypt(aes_key, enc_output, dec_output);
        writefln("dec_output(%3d)=%s", dec_output.length, dec_output);
        writefln("dec_output     =%s", dec_output[0..16]);
        assert(input == dec_output[0..input.length]);
        }
    }
}
