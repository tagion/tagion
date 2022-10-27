/* hmac.h
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

module tagion.network.wolfssl.c.wolfcrypt.hmac;

import tagion.network.wolfssl.c.wolfcrypt.md5;
import tagion.network.wolfssl.c.wolfcrypt.sha256;
import tagion.network.wolfssl.c.wolfcrypt.sha;
import tagion.network.wolfssl.c.wolfcrypt.types;
import tagion.network.wolfssl.wolfssl_config;

extern (C):
nothrow:
@nogc:

/*!
    \file wolfssl/wolfcrypt/hmac.h
*/

/* for fips @wc_fips */

/* avoid redefinition of structs */

enum HMAC_BLOCK_SIZE = WC_HMAC_BLOCK_SIZE;

enum WC_HMAC_INNER_HASH_KEYED_SW = 1;
enum WC_HMAC_INNER_HASH_KEYED_DEV = 2;

enum
{
    HMAC_FIPS_MIN_KEY = 14, /* 112 bit key length minimum */

    IPAD = 0x36,
    OPAD = 0x5C,

    /* If any hash is not enabled, add the ID here. */

    WC_SHA512 = wc_HashType.WC_HASH_TYPE_SHA512,

    WC_SHA512_224 = wc_HashType.WC_HASH_TYPE_SHA512_224,

    WC_SHA512_256 = wc_HashType.WC_HASH_TYPE_SHA512_256,

    WC_SHA384 = wc_HashType.WC_HASH_TYPE_SHA384,

    WC_SHA224 = wc_HashType.WC_HASH_TYPE_SHA224,

    WC_SHA3_224 = wc_HashType.WC_HASH_TYPE_SHA3_224,
    WC_SHA3_256 = wc_HashType.WC_HASH_TYPE_SHA3_256,
    WC_SHA3_384 = wc_HashType.WC_HASH_TYPE_SHA3_384,
    WC_SHA3_512 = wc_HashType.WC_HASH_TYPE_SHA3_512
}

/* Select the largest available hash for the buffer size. */
enum WC_HMAC_BLOCK_SIZE = WC_MAX_BLOCK_SIZE;

/* hmac hash union */
union wc_HmacHash
{
    wc_Md5 md5;

    wc_Sha sha;

    wc_Sha256 sha256;
}

/* Hmac digest */
struct Hmac
{
    wc_HmacHash hash;
    word32[16] ipad; /* same block size all*/
    word32[16] opad;
    word32[8] innerHash;
    void* heap; /* heap hint */
    ubyte macType; /* md5 sha or sha256 */
    ubyte innerHashKeyed; /* keyed flag */

    /* WOLFSSL_ASYNC_CRYPT */

    /* hmac key length (key in ipad) */
}

/* HAVE_FIPS */

/* does init */
int wc_HmacSetKey (Hmac* hmac, int type, const(ubyte)* key, word32 keySz);
int wc_HmacUpdate (Hmac* hmac, const(ubyte)* in_, word32 sz);
int wc_HmacFinal (Hmac* hmac, ubyte* out_);

int wc_HmacSizeByType (int type);

int wc_HmacInit (Hmac* hmac, void* heap, int devId);

void wc_HmacFree (Hmac* hmac);

int wolfSSL_GetHmacMaxSize ();

int _InitHmac (Hmac* hmac, int type, void* heap);

/* HAVE_HKDF */

/* extern "C" */

/* NO_HMAC */
/* WOLF_CRYPT_HMAC_H */
