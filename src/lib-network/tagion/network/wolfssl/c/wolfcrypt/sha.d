/* sha.h
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

module tagion.network.wolfssl.c.wolfcrypt.sha;

import tagion.network.wolfssl.c.wolfcrypt.types;
import tagion.network.wolfssl.wolfssl_config;

extern (C):
nothrow:
@nogc:

/*!
    \file wolfssl/wolfcrypt/sha.h
*/

/* HAVE_FIPS_VERSION >= 2 */

/* for fips @wc_fips */

/* avoid redefinition of structs */

enum SHA = .WC_SHA;

alias Sha = wc_Sha;
enum SHA_BLOCK_SIZE = .WC_SHA_BLOCK_SIZE;
enum SHA_DIGEST_SIZE = .WC_SHA_DIGEST_SIZE;
enum SHA_PAD_SIZE = .WC_SHA_PAD_SIZE;

/* in bytes */
enum
{
    WC_SHA = wc_HashType.WC_HASH_TYPE_SHA,
    WC_SHA_BLOCK_SIZE = 64,
    WC_SHA_DIGEST_SIZE = 20,
    WC_SHA_PAD_SIZE = 56
}

/* Sha digest */
struct wc_Sha
{
    word32 buffLen; /* in bytes          */
    word32 loLen; /* length in bytes   */
    word32 hiLen; /* length in bytes   */
    word32[16] buffer;

    word32[5] digest;

    void* heap;

    /* cache for updates */

    /* WOLFSSL_ASYNC_CRYPT */

    /* generic crypto callback context */

    /* enum wc_HashFlags in hash.h */
}

/* WOLFSSL_TI_HASH */

/* HAVE_FIPS */

int wc_InitSha (wc_Sha* sha);
int wc_InitSha_ex (wc_Sha* sha, void* heap, int devId);
int wc_ShaUpdate (wc_Sha* sha, const(ubyte)* data, word32 len);
int wc_ShaFinalRaw (wc_Sha* sha, ubyte* hash);
int wc_ShaFinal (wc_Sha* sha, ubyte* hash);
void wc_ShaFree (wc_Sha* sha);

int wc_ShaGetHash (wc_Sha* sha, ubyte* hash);
int wc_ShaCopy (wc_Sha* src, wc_Sha* dst);

/* extern "C" */

/* NO_SHA */
/* WOLF_CRYPT_SHA_H */
