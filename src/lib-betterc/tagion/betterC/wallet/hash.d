module tagion.betterC.wallet.hash;

import tagion.betterC.utils.Memory;

/***********************************************************************
 * Copyright (c) 2014 Pieter Wuille                                    *
 * Distributed under the MIT software license, see the accompanying    *
 * file COPYING or https://www.opensource.org/licenses/mit-license.php.*
 ***********************************************************************/

extern (C):


void secp256k1_sha256_initialize (secp256k1_sha256* hash);
void secp256k1_sha256_write (secp256k1_sha256* hash, const(ubyte)* data, size_t size);
void secp256k1_sha256_finalize (secp256k1_sha256* hash, ubyte* out32);

ubyte[] secp256k1_count_hash(const const(ubyte[]) data) {
    secp256k1_sha256 hash;
    ubyte[] res;
    res.create(32);
    ubyte* ret_arr;

    // secp256k1_sha256_initialize(&hash);
    // secp256k1_sha256_write(&hash, &data[0], data.length);
    // secp256k1_sha256_finalize(&hash, ret_arr);

    for (int i = 0; i < 32 ; i++) {
        res[i] = *(ret_arr + i);
    }

    return res;
}


struct secp256k1_sha256
{
    uint[8] s;
    uint[16] buf; /* In big endian */
    size_t bytes;
}
ubyte[32] secp256k1_count_hmac_hash(const const(ubyte[]) data) {
    secp256k1_hmac_sha256 hash;
    ubyte[32] res;
    ubyte* ret_arr;

    // secp256k1_hmac_sha256_initialize(&hash);
    // secp256k1_hmac_sha256_write(&hash, &data[0], data.length);
    // secp256k1_hmac_sha256_finalize(&hash, ret_arr);

    // for (int i = 0; i < 32 ; i++) {
    //     res[i] = *(ret_arr + i);
    // }

    return res;
}

struct secp256k1_hmac_sha256
{
    secp256k1_sha256 inner;
    secp256k1_sha256 outer;
}

void secp256k1_hmac_sha256_initialize (secp256k1_hmac_sha256* hash, const(ubyte)* key, size_t size);
void secp256k1_hmac_sha256_write (secp256k1_hmac_sha256* hash, const(ubyte)* data, size_t size);
void secp256k1_hmac_sha256_finalize (secp256k1_hmac_sha256* hash, ubyte* out32);

struct secp256k1_rfc6979_hmac_sha256
{
    ubyte[32] v;
    ubyte[32] k;
    int retry;
}

void secp256k1_rfc6979_hmac_sha256_initialize (secp256k1_rfc6979_hmac_sha256* rng, const(ubyte)* key, size_t keylen);
void secp256k1_rfc6979_hmac_sha256_generate (secp256k1_rfc6979_hmac_sha256* rng, ubyte* out_, size_t outlen);
void secp256k1_rfc6979_hmac_sha256_finalize (secp256k1_rfc6979_hmac_sha256* rng);

// struct secp256k1_context {
//     secp256k1_ecmult_gen_context ecmult_gen_ctx;
//     secp256k1_callback illegal_callback;
//     secp256k1_callback error_callback;
//     int declassify;
// };

// void randomize32(const (ubyte[]) seed, ubyte[] out32)
// in {
//     assert(seed.length == 32);
//     assert(out32.length == 32);
// }
// do {
//     secp256k1_context ctx;
//     out32[0.. $]

// }

/* SECP256K1_HASH_H */
