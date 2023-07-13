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

void secp256k1_sha256_initialize_w (secp256k1_sha256* hash);
void secp256k1_sha256_write_w (secp256k1_sha256* hash, const(ubyte)* data, size_t size);
void secp256k1_sha256_finalize_w (secp256k1_sha256* hash, ubyte* out32);

/* SECP256K1_HASH_H */
