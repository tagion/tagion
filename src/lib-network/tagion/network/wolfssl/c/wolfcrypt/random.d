/* random.h
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

module tagion.network.wolfssl.c.wolfcrypt.random;

import tagion.network.wolfssl.c.wolfcrypt.types;
import tagion.network.wolfssl.wolfssl_config;

extern (C):
nothrow:
@nogc:

/*!
    \file wolfssl/wolfcrypt/random.h
*/

/* HAVE_FIPS_VERSION >= 2 */

/* included for fips @wc_fips */

/* Maximum generate block length */

enum RNG_MAX_BLOCK_LEN = 0x10000L;

/* Size of the BRBG seed */

enum DRBG_SEED_LEN = 440 / 8;

/* To maintain compatibility the default is byte */
alias CUSTOM_RAND_TYPE = ubyte;

/* make sure Hash DRBG is enabled, unless WC_NO_HASHDRBG is defined
    or CUSTOM_RAND_GENERATE_BLOCK is defined */

enum WC_RESEED_INTERVAL = 1000000;

/* avoid redefinition of structs */

/* RNG supports the following sources (in order):
 * 1. CUSTOM_RAND_GENERATE_BLOCK: Defines name of function as RNG source and
 *     bypasses the options below.
 * 2. HAVE_INTEL_RDRAND: Uses the Intel RDRAND if supported by CPU.
 * 3. HAVE_HASHDRBG (requires SHA256 enabled): Uses SHA256 based P-RNG
 *     seeded via wc_GenerateSeed. This is the default source.
 */

/* Seed source can be overridden by defining one of these:
     CUSTOM_RAND_GENERATE_SEED
     CUSTOM_RAND_GENERATE_SEED_OS
     CUSTOM_RAND_GENERATE */

/* To use define the following:
 * #define CUSTOM_RAND_GENERATE_BLOCK myRngFunc
 * extern int myRngFunc(byte* output, word32 sz);
 */

/* NO_SHA256 */

/* allow whitewood as direct RNG source using wc_GenerateSeed directly */

/* Intel RDRAND or RDSEED */

/* type HCRYPTPROV, avoid #include <windows.h> */

/* guard on redeclaration */

/* OS specific seeder */
struct OS_Seed
{
    int fd;
}

struct DRBG_internal
{
    word32 reseedCtr;
    word32 lastBlock;
    ubyte[55] V;
    ubyte[55] C;

    ubyte matchCount;
}

/* RNG context */
struct WC_RNG
{
    OS_Seed seed;
    void* heap;

    /* Hash-based Deterministic Random Bit Generator */
    struct DRBG;
    DRBG* drbg;

    ubyte status;
}

/* NO FIPS or have FIPS v2*/

/* NO_OLD_RNGNAME removes RNG struct name to prevent possible type conflicts,
 * can't be used with CTaoCrypt FIPS */

alias RNG = WC_RNG;

int wc_GenerateSeed (OS_Seed* os, ubyte* seed, word32 sz);

/* Whitewood netRandom client library */

/* HAVE_WNR */

WC_RNG* wc_rng_new (ubyte* nonce, word32 nonceSz, void* heap);
void wc_rng_free (WC_RNG* rng);

int wc_InitRng (WC_RNG* rng);
int wc_InitRng_ex (WC_RNG* rng, void* heap, int devId);
int wc_InitRngNonce (WC_RNG* rng, ubyte* nonce, word32 nonceSz);
int wc_InitRngNonce_ex (
    WC_RNG* rng,
    ubyte* nonce,
    word32 nonceSz,
    void* heap,
    int devId);
int wc_RNG_GenerateBlock (WC_RNG* rng, ubyte* b, word32 sz);
int wc_RNG_GenerateByte (WC_RNG* rng, ubyte* b);
int wc_FreeRng (WC_RNG* rng);

/* some older compilers do not like macro function in expression */

int wc_RNG_DRBG_Reseed (WC_RNG* rng, const(ubyte)* entropy, word32 entropySz);
int wc_RNG_TestSeed (const(ubyte)* seed, word32 seedSz);
int wc_RNG_HealthTest (
    int reseed,
    const(ubyte)* entropyA,
    word32 entropyASz,
    const(ubyte)* entropyB,
    word32 entropyBSz,
    ubyte* output,
    word32 outputSz);
int wc_RNG_HealthTest_ex (
    int reseed,
    const(ubyte)* nonce,
    word32 nonceSz,
    const(ubyte)* entropyA,
    word32 entropyASz,
    const(ubyte)* entropyB,
    word32 entropyBSz,
    ubyte* output,
    word32 outputSz,
    void* heap,
    int devId);
/* HAVE_HASHDRBG */

/* extern "C" */

/* WOLF_CRYPT_RANDOM_H */
