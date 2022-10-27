/* sha256.h
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

module tagion.network.wolfssl.c.wolfcrypt.sha256;

import tagion.network.wolfssl.c.wolfcrypt.types;
import tagion.network.wolfssl.wolfssl_config;

extern (C):
nothrow:
@nogc:

/*!
    \file wolfssl/wolfcrypt/sha256.h
*/

/* HAVE_FIPS_VERSION >= 2 */

/* for fips @wc_fips */

/* avoid redefinition of structs */

enum SHA256 = .WC_SHA256;

alias Sha256 = wc_Sha256;
enum SHA256_BLOCK_SIZE = .WC_SHA256_BLOCK_SIZE;
enum SHA256_DIGEST_SIZE = .WC_SHA256_DIGEST_SIZE;
enum SHA256_PAD_SIZE = .WC_SHA256_PAD_SIZE;

/* in bytes */
enum
{
    WC_SHA256 = wc_HashType.WC_HASH_TYPE_SHA256,
    WC_SHA256_BLOCK_SIZE = 64,
    WC_SHA256_DIGEST_SIZE = 32,
    WC_SHA256_PAD_SIZE = 56
}

/* wc_Sha256 digest */
struct wc_Sha256
{
    /* alignment on digest and buffer speeds up ARMv8 crypto operations */
    word32[8] digest;
    word32[16] buffer;
    word32 buffLen; /* in bytes          */
    word32 loLen; /* length in bytes   */
    word32 hiLen; /* length in bytes   */
    void* heap;

    /* cache for updates */

    /* WOLFSSL_ASYNC_CRYPT */

    /* !FREESCALE_LTC_SHA && !STM32_HASH_SHA2 */

    /* generic crypto callback context */

    /* enum wc_HashFlags in hash.h */
}

/* HAVE_FIPS */

int wc_InitSha256 (wc_Sha256* sha);
int wc_InitSha256_ex (wc_Sha256* sha, void* heap, int devId);
int wc_Sha256Update (wc_Sha256* sha, const(ubyte)* data, word32 len);
int wc_Sha256FinalRaw (wc_Sha256* sha256, ubyte* hash);
int wc_Sha256Final (wc_Sha256* sha256, ubyte* hash);
void wc_Sha256Free (wc_Sha256* sha256);

int wc_Sha256GetHash (wc_Sha256* sha256, ubyte* hash);
int wc_Sha256Copy (wc_Sha256* src, wc_Sha256* dst);

/* avoid redefinition of structs */

/* in bytes */

/* HAVE_FIPS */

/* WOLFSSL_SHA224 */

/* extern "C" */

/* NO_SHA256 */
/* WOLF_CRYPT_SHA256_H */
