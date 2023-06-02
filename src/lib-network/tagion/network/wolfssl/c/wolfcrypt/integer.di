/* integer.h
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

module tagion.network.wolfssl.c.wolfcrypt.integer;

extern (C):
nothrow:
@nogc:

/*
 * Based on public domain LibTomMath 0.38 by Tom St Denis, tomstdenis@iahu.ca,
 * http://math.libtomcrypt.com
 */

/* may optionally use fast math instead, not yet supported on all platforms and
   may not be faster on all
*/
/* will set MP_xxBIT if not default */

/* C++ compilers don't like assigning void * to mp_digit * */

/* SuperH SH3 compiler doesn't like assigning voi* to mp_digit* */

/* C on the other hand doesn't care */

/* __cplusplus */

/* detect 64-bit mode if possible */

/* if intel compiler doesn't provide 128 bit type don't turn on 64bit */

/* allow user to define on mp_digit, mp_word, DIGIT_BIT types */

/* some default configurations.
 *
 * A "mp_digit" must be able to hold DIGIT_BIT + 1 bits
 * A "mp_word" must be able to hold 2*DIGIT_BIT + 1 bits
 *
 * At the very least a mp_digit must be able to hold 7 bits
 * [any size beyond that is ok provided it doesn't overflow the data type]
 */

/* 8-bit */

/* don't define DIGIT_BIT, so its calculated below */

/* 16-bit */

/* don't define DIGIT_BIT, so its calculated below */

/* 32-bit forced to 16-bit */

/* 64-bit */
/* for GCC only on supported platforms */
/* 64 bit type, 128 uses mode(TI) */

/* 32-bit default case */

/* long could be 64 now, changed TAO */

/* this is an extension that uses 31-bit digits */

/* default case is 28-bit digits, defines MP_28BIT as a handy test macro */

/* WOLFSSL_BIGINT_TYPES */

/* otherwise the bits per digit is calculated automatically from the size of
   a mp_digit */

/* bits per digit */

/* equalities */
/* less than */
/* equal to */
/* greater than */

/* positive integer */
/* negative */

/* ok result */
/* out of mem */
/* invalid input */
/* point not at infinity */

/* yes response */
/* no response */

/* Primality generation flags */
/* BBS style prime */
/* Safe prime (p-1)/2 == prime */
/* force 2nd MSB to 1 */

/* define this to use lower memory usage routines (exptmods mostly) */

/* default precision */

/* default digits of precision */

/* default digits of precision */

/* size of comba arrays, should be at least 2 * 2**(BITS_PER_WORD -
   BITS_PER_DIGIT*2) */

/* raw big integer */

/* the mp_int structure */

/* unsigned binary (big endian) */

/* wolf big int and common functions */

/* callback for mp_prime_random, should fill dst with random bytes and return
   how many read [up to len] */

/* ---> Basic Manipulations <--- */

/* number of primes */

/* 6 functions needed by Rsa */

/* end functions needed by Rsa */

/* functions added to support above needed, removed TOOM and KARATSUBA */

/* end support added functions */

/* added */

/* WOLFSSL_KEY_GEN NO_RSA NO_DSA NO_DH */

/* USE_FAST_MATH */

/* WOLF_CRYPT_INTEGER_H */
