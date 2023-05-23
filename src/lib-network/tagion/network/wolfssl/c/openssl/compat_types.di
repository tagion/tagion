/* compat_types.h
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

/*
 * Move types that cause cyclical dependency errors here.
 */

module tagion.network.wolfssl.c.openssl.compat_types;

import tagion.network.wolfssl.c.wolfcrypt.types;

extern (C):
nothrow:
@nogc:

version (none) struct WOLFSSL_HMAC_CTX {
    Hmac hmac;
    int type;
    word32[16] save_ipad; /* same block size all*/
    word32[16] save_opad;
}

alias WOLFSSL_EVP_MD = char;
alias WOLFSSL_EVP_CIPHER = char;
alias WOLFSSL_ENGINE = int;

struct WOLFSSL_EVP_PKEY;
struct WOLFSSL_EVP_MD_CTX;
alias WOLFSSL_PKCS8_PRIV_KEY_INFO = WOLFSSL_EVP_PKEY;
struct WOLFSSL_EVP_PKEY_CTX;
struct WOLFSSL_EVP_CIPHER_CTX;
struct WOLFSSL_ASN1_PCTX;

/* OPENSSL_EXTRA || OPENSSL_EXTRA_X509_SMALL */

/* !WOLFSSL_OPENSSL_COMPAT_TYPES_H_ */
