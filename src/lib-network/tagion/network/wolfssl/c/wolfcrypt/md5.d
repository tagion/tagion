/* md5.h
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
    \file wolfssl/wolfcrypt/md5.h
*/

module tagion.network.wolfssl.c.wolfcrypt.md5;

import tagion.network.wolfssl.c.wolfcrypt.types;
import tagion.network.wolfssl.wolfssl_config;

extern (C):
nothrow:
@nogc:

enum MD5 = .WC_MD5;

alias Md5 = wc_Md5;
enum MD5_BLOCK_SIZE = .WC_MD5_BLOCK_SIZE;
enum MD5_DIGEST_SIZE = .WC_MD5_DIGEST_SIZE;
// DSTEP : enum WC_MD5_PAD_SIZE = .WC_MD5_PAD_SIZE;

/* in bytes */
enum
{
    WC_MD5 = wc_HashType.WC_HASH_TYPE_MD5,
    WC_MD5_BLOCK_SIZE = 64,
    WC_MD5_DIGEST_SIZE = 16,
    WC_MD5_PAD_SIZE = 56
}

/* MD5 digest */
struct wc_Md5
{
    word32 buffLen; /* in bytes          */
    word32 loLen; /* length in bytes   */
    word32 hiLen; /* length in bytes   */
    word32[16] buffer;

    word32[4] digest;

    void* heap;

    /* cache for updates */

    /* STM32_HASH */

    /* WOLFSSL_ASYNC_CRYPT */

    /* enum wc_HashFlags in hash.h */
}

/* WOLFSSL_TI_HASH */

int wc_InitMd5 (wc_Md5* md5);
int wc_InitMd5_ex (wc_Md5* md5, void* heap, int devId);
int wc_Md5Update (wc_Md5* md5, const(ubyte)* data, word32 len);
int wc_Md5Final (wc_Md5* md5, ubyte* hash);
void wc_Md5Free (wc_Md5* md5);

int wc_Md5GetHash (wc_Md5* md5, ubyte* hash);
int wc_Md5Copy (wc_Md5* src, wc_Md5* dst);

/* extern "C" */

/* NO_MD5 */
/* WOLF_CRYPT_MD5_H */
