/* dsa.h
 *
 * Copyright (C) 2006-2022 wolfSSL Inc.
 *
 * This file is part of wolfSSL.
 *
 * wolfSSL is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * wolfSSL is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1335, USA
 */

/*!
    \file wolfssl/wolfcrypt/dsa.h
*/

module tagion.network.wolfssl.c.wolfcrypt.dsa;

import tagion.network.wolfssl.c.wolfcrypt.integer;
import tagion.network.wolfssl.c.wolfcrypt.random;
import tagion.network.wolfssl.c.wolfcrypt.tfm;
import tagion.network.wolfssl.c.wolfcrypt.types;

extern (C):
nothrow:
@nogc:

/* for DSA reverse compatibility */
alias InitDsaKey = wc_InitDsaKey;
alias FreeDsaKey = wc_FreeDsaKey;
alias DsaSign = wc_DsaSign;
alias DsaVerify = wc_DsaVerify;
alias DsaPublicKeyDecode = wc_DsaPublicKeyDecode;
alias DsaPrivateKeyDecode = wc_DsaPrivateKeyDecode;
alias DsaKeyToDer = wc_DsaKeyToDer;

enum
{
    DSA_PUBLIC = 0,
    DSA_PRIVATE = 1
}

enum
{
    /* 160 bit q length */
    DSA_160_HALF_SIZE = 20, /* r and s size  */
    DSA_160_SIG_SIZE = 40, /* signature size */
    DSA_HALF_SIZE = DSA_160_HALF_SIZE, /* kept for compatiblity  */
    DSA_SIG_SIZE = DSA_160_SIG_SIZE, /* kept for compatiblity */
    /* 256 bit q length */
    DSA_256_HALF_SIZE = 32, /* r and s size  */
    DSA_256_SIG_SIZE = 64, /* signature size */

    DSA_MIN_HALF_SIZE = DSA_160_HALF_SIZE,
    DSA_MIN_SIG_SIZE = DSA_160_SIG_SIZE,

    DSA_MAX_HALF_SIZE = DSA_256_HALF_SIZE,
    DSA_MAX_SIG_SIZE = DSA_256_SIG_SIZE
}

/* DSA */
struct DsaKey
{
    mp_int p;
    mp_int q;
    mp_int g;
    mp_int y;
    mp_int x;
    int type; /* public or private */
    void* heap; /* memory hint */
}

int wc_InitDsaKey (DsaKey* key);
int wc_InitDsaKey_h (DsaKey* key, void* h);
void wc_FreeDsaKey (DsaKey* key);
int wc_DsaSign (const(ubyte)* digest, ubyte* out_, DsaKey* key, WC_RNG* rng);
int wc_DsaVerify (
    const(ubyte)* digest,
    const(ubyte)* sig,
    DsaKey* key,
    int* answer);
int wc_DsaPublicKeyDecode (
    const(ubyte)* input,
    word32* inOutIdx,
    DsaKey* key,
    word32 inSz);
int wc_DsaPrivateKeyDecode (
    const(ubyte)* input,
    word32* inOutIdx,
    DsaKey* key,
    word32 inSz);
int wc_DsaKeyToDer (DsaKey* key, ubyte* output, word32 inLen);
int wc_SetDsaPublicKey (
    ubyte* output,
    DsaKey* key,
    int outLen,
    int with_header);
int wc_DsaKeyToPublicDer (DsaKey* key, ubyte* output, word32 inLen);

/* raw export functions */
int wc_DsaImportParamsRaw (
    DsaKey* dsa,
    const(char)* p,
    const(char)* q,
    const(char)* g);
int wc_DsaImportParamsRawCheck (
    DsaKey* dsa,
    const(char)* p,
    const(char)* q,
    const(char)* g,
    int trusted,
    WC_RNG* rng);
int wc_DsaExportParamsRaw (
    DsaKey* dsa,
    ubyte* p,
    word32* pSz,
    ubyte* q,
    word32* qSz,
    ubyte* g,
    word32* gSz);
int wc_DsaExportKeyRaw (
    DsaKey* dsa,
    ubyte* x,
    word32* xSz,
    ubyte* y,
    word32* ySz);

/* extern "C" */

/* NO_DSA */
/* WOLF_CRYPT_DSA_H */
