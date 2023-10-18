/***********************************************************************
 * Copyright (c) 2014 Pieter Wuille                                    *
 * Distributed under the MIT software license, see the accompanying    *
 * file COPYING or https://www.opensource.org/licenses/mit-license.php.*
 ***********************************************************************/

module tagion.crypto.secp256k1.c.secp256k1_hash;

extern (C):
nothrow:
@nogc:

struct secp256k1_sha256
{
    uint[8] s;
    uint[16] buf; /* In big endian */
    size_t bytes;
}

void secp256k1_sha256_initialize (secp256k1_sha256* hash);
void secp256k1_sha256_write (secp256k1_sha256* hash, const(ubyte)* data, size_t size);
void secp256k1_sha256_finalize (secp256k1_sha256* hash, ubyte* out32);

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

/* SECP256K1_HASH_H */
