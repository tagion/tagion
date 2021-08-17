module tagion.crypto.aes.openssl_aes.aes;
/* This is a D translation the openssl/aes.h header file
/*
 * Copyright 2002-2016 The OpenSSL Project Authors. All Rights Reserved.
 *
 * Licensed under the OpenSSL license (the "License").  You may not use
 * this file except in compliance with the License.  You can obtain a copy
 * in the file LICENSE in the source distribution or at
 * https://www.openssl.org/source/license.html
 */

extern (C) {

    enum {
        AES_ENCRYPT = 1,
        AES_DECRYPT = 0,

        /*
 * Because array size can't be a const in C, the following two are macros.
 * Both sizes are in bytes.
 */
        AES_MAXNR = 14,
        AES_BLOCK_SIZE = 16
    }
}

extern (C) {
    /* This should be a hidden type, but EVP requires that the size be known */
    struct aes_key_st {
        version (AES_LONG) {
            ulong[4 * (AES_MAXNR + 1)] rd_key;
        }
        else {
            uint[4 * (AES_MAXNR + 1)] rd_key;
            int rounds;
        }
    }
}

extern (C) {
    alias AES_KEY = aes_key_st;

    const(char)* AES_options();

    int AES_set_encrypt_key(const ubyte* userKey, const int bits,
            AES_KEY* key);
    int AES_set_decrypt_key(const ubyte* userKey, const int bits,
            AES_KEY* key);

    void AES_encrypt(const ubyte* input, ubyte* output,
            const AES_KEY* key);
    void AES_decrypt(const ubyte* input, ubyte* output,
            const AES_KEY* key);

    void AES_ecb_encrypt(const ubyte* input, ubyte* output,
            const AES_KEY* key, const int enc);
    void AES_cbc_encrypt(const ubyte* input, ubyte* output,
            size_t length, const AES_KEY* key,
            ubyte* ivec, const int enc);
    void AES_cfb128_encrypt(const ubyte* input, ubyte* output,
            size_t length, const AES_KEY* key,
            ubyte* ivec, int* num, const int enc);
    void AES_cfb1_encrypt(const ubyte* input, ubyte* output,
            size_t length, const AES_KEY* key,
            ubyte* ivec, int* num, const int enc);
    void AES_cfb8_encrypt(const ubyte* input, ubyte* output,
            size_t length, const AES_KEY* key,
            ubyte* ivec, int* num, const int enc);
    void AES_ofb128_encrypt(const ubyte* input, ubyte* output,
            size_t length, const AES_KEY* key,
            ubyte* ivec, int* num);
    /* NB: the IV is _two_ blocks long */
    void AES_ige_encrypt(const ubyte* input, ubyte* output,
            size_t length, const AES_KEY* key,
            ubyte* ivec, const int enc);
    /* NB: the IV is _four_ blocks long */
    void AES_bi_ige_encrypt(const ubyte* input, ubyte* output,
            size_t length, const AES_KEY* key,
            const AES_KEY* key2, const ubyte* ivec,
            const int enc);

    int AES_wrap_key(AES_KEY* key, const ubyte* iv,
            ubyte* output,
            const ubyte* input, uint inlen);
    int AES_unwrap_key(AES_KEY* key, const ubyte* iv,
            ubyte* output,
            const ubyte* input, uint inlen);
}
