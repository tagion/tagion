/* types.h
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

module tagion.network.wolfssl.c.wolfcrypt.types;

import core.stdc.config;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;

extern (C):
nothrow:
@nogc:

/*!
    \file wolfssl/wolfcrypt/types.h
*/
/*
DESCRIPTION
This library defines the primitive data types and abstraction macros to
decouple library dependencies with standard string, memory and so on.

*/

/*
 * This struct is used multiple time by other structs and
 * needs to be defined somewhere that all structs can import
 * (with minimal dependencies).
 */

alias sword8 = byte;
alias word8 = ubyte;

alias sword16 = short;
alias word16 = ushort;
alias sword32 = int;
alias word32 = uint;

alias word24 = ubyte[3];

/* constant pointer to a constant char */

alias wcchar = const char*;

/* if a version is available, pivot on the version, otherwise guess it's
 * allowed, subject to override.
 */

enum HAVE_ANONYMOUS_INLINE_AGGREGATES = 1;

/* helpers for stringifying the expanded value of a macro argument rather
 * than its literal text:
 */
extern (D) string _WC_STRINGIFY_L2(T)(auto ref T str) {
    import std.conv : to;

    return to!string(str);
}

alias WC_STRINGIFY = _WC_STRINGIFY_L2;

/* try to set SIZEOF_LONG or SIZEOF_LONG_LONG if user didn't */

/* make sure both SIZEOF_LONG_LONG and SIZEOF_LONG are set,
 * otherwise causes issues with CTC_SETTINGS */

/* long should be 64bit */
enum SIZEOF_LONG = 8;

/* long long should be 64bit */

extern (D) string W64LIT(T)(auto ref T x) {
    import std.conv : to;

    return to!string(x) ~ "LL";
}

alias sword64 = c_long;
alias word64 = c_ulong;

/* These platforms have 64-bit CPU registers.  */

/* LP64 with GNU GCC compiler is reserved for when long int is 64 bits
 * and int uses 32 bits. When using Solaris Studio sparc and __sparc are
 * available for 32 bit detection but __sparc64__ could be missed. This
 * uses LP64 for checking 64 bit CPU arch. */

alias wolfssl_word = c_ulong;

/* for mp_int, mp_word needs to be twice as big as \
 * mp_digit, no 64 bit type so make mp_digit 16 bit */

/* for mp_int, mp_word needs to be twice as big as \
 * mp_digit, no 64 bit type so make mp_digit 16 bit */

struct w64wrapper {
    word64 n;

    /* WORD64_AVAILABLE && WOLFSSL_W64_WRAPPER_TEST */
}

/* Allow user supplied type */

/* fallback to architecture size_t for pointer size */
/* included for getting size_t type */
alias wc_ptr_t = c_ulong;

enum {
    WOLFSSL_WORD_SIZE = wolfssl_word.sizeof,
    WOLFSSL_BIT_SIZE = 8,
    WOLFSSL_WORD_BITS = WOLFSSL_WORD_SIZE * WOLFSSL_BIT_SIZE
}

/* use inlining if compiler allows */

/* set up rotate style */

/* GCC does peephole optimizations which should result in using rotate
   instructions  */

/* set up thread local storage if available */

/* Thread local storage only in FreeRTOS v8.2.1 and higher */

/* GCC 7 has new switch() fall-through detection */

/* FALL_THROUGH */

/* use stub for fall through by default or for Microchip compiler */

/* WARN_UNUSED_RESULT */

/* WC_MAYBE_UNUSED */

/* Micrium will use Visual Studio for compilation but not the Win32 API */

/* -1 to not count the null char */

/* idea to add global alloc override by Moises Guimaraes  */
/* default to libc stuff */
/* XREALLOC is used once in normal math lib, not in fast math lib */
/* XFREE on some embedded systems doesn't like free(0) so test  */

/* WOLFSSL_DEBUG_MEMORY */

/* WOLFSSL_DEBUG_MEMORY */

/* prototypes for user heap override functions */
/* for size_t */

/* prototypes for user heap override functions */
/* for size_t */

/* override the XMALLOC, XFREE and XREALLOC macros */

/* Telit M2MB SDK requires use m2mb_os API's, not std malloc/free */
/* Use of malloc/free will cause CPU reboot */

/* this platform does not support heap use */

/* just use plain C stdlib stuff if desired */

/* definitions are in linuxkm/linuxkm_wc_port.h */

/* default C runtime, can install different routines at runtime via cbs */

/* WOLFSSL_DEBUG_MEMORY */

/* WOLFSSL_DEBUG_MEMORY */
/* WOLFSSL_STATIC_MEMORY */

/* declare/free variable handling for async and smallstack */

/* nothing to free, its stack */
/* nothing to free, its stack */

/* These are here for the FIPS code that can't be changed. New definitions don't need to be added here. */

/* HAVE_FIPS */

/* strstr, strncmp, strcmp, and strncat only used by wolfSSL proper,
 * not required for wolfCrypt only */

/* XC32 supports str[n]casecmp in version >= 1.0. */

/* XC32 version < 1.0 does not support strcasecmp, so use
 * case sensitive one.
 */

/* !XSTRCASECMP */

/* XC32 supports str[n]casecmp in version >= 1.0. */

/* XC32 version < 1.0 does not support strncasecmp, so use case
 * sensitive one.
 */

/* !XSTRNCASECMP */

/* snprintf is used in asn.c for GetTimeString, PKCS7 test, and when
   debugging is turned on */

/* case where stdio is not included else where but is needed
   for snprintf */

/* later gcc than 7.1 introduces -Wformat-truncation    */
/* In cases when truncation is expected the caller needs*/
/* to check the return value from the function so that  */
/* compiler doesn't complain.                           */
/* xtensa-esp32-elf v8.2.0 warns truncation at          */
/* GetAsnTimeString()                                   */

/* Beginning with the UCRT in Visual Studio 2015 and
   Windows 10, snprintf is no longer identical to
   _snprintf. The snprintf function behavior is now
   C99 standard compliant. */

/* 4996 warning to use MS extensions e.g., _sprintf_s
   instead of _snprintf */

/* (_MSC_VER >= 1900) */

/* _MSC_VER */
/* USE_WINDOWS_API */

/* use only Thread Safe version of strtok */

/* if custom XATOI is not already defined */

char* wc_strtok(char* str, const(char)* delim, char** nextp);

char* wc_strsep(char** stringp, const(char)* delim);

size_t wc_strlcpy(char* dst, const(char)* src, size_t dstSize);

size_t wc_strlcat(char* dst, const(char)* src, size_t dstSize);

/* !NO_FILESYSTEM && !NO_STDIO_FILESYSTEM */

/* needed by wolfSSL_check_domain_name() */

/* memory allocation types for user hints */
enum {
    DYNAMIC_TYPE_CA = 1,
    DYNAMIC_TYPE_CERT = 2,
    DYNAMIC_TYPE_KEY = 3,
    DYNAMIC_TYPE_FILE = 4,
    DYNAMIC_TYPE_SUBJECT_CN = 5,
    DYNAMIC_TYPE_PUBLIC_KEY = 6,
    DYNAMIC_TYPE_SIGNER = 7,
    DYNAMIC_TYPE_NONE = 8,
    DYNAMIC_TYPE_BIGINT = 9,
    DYNAMIC_TYPE_RSA = 10,
    DYNAMIC_TYPE_METHOD = 11,
    DYNAMIC_TYPE_OUT_BUFFER = 12,
    DYNAMIC_TYPE_IN_BUFFER = 13,
    DYNAMIC_TYPE_INFO = 14,
    DYNAMIC_TYPE_DH = 15,
    DYNAMIC_TYPE_DOMAIN = 16,
    DYNAMIC_TYPE_SSL = 17,
    DYNAMIC_TYPE_CTX = 18,
    DYNAMIC_TYPE_WRITEV = 19,
    DYNAMIC_TYPE_OPENSSL = 20,
    DYNAMIC_TYPE_DSA = 21,
    DYNAMIC_TYPE_CRL = 22,
    DYNAMIC_TYPE_REVOKED = 23,
    DYNAMIC_TYPE_CRL_ENTRY = 24,
    DYNAMIC_TYPE_CERT_MANAGER = 25,
    DYNAMIC_TYPE_CRL_MONITOR = 26,
    DYNAMIC_TYPE_OCSP_STATUS = 27,
    DYNAMIC_TYPE_OCSP_ENTRY = 28,
    DYNAMIC_TYPE_ALTNAME = 29,
    DYNAMIC_TYPE_SUITES = 30,
    DYNAMIC_TYPE_CIPHER = 31,
    DYNAMIC_TYPE_RNG = 32,
    DYNAMIC_TYPE_ARRAYS = 33,
    DYNAMIC_TYPE_DTLS_POOL = 34,
    DYNAMIC_TYPE_SOCKADDR = 35,
    DYNAMIC_TYPE_LIBZ = 36,
    DYNAMIC_TYPE_ECC = 37,
    DYNAMIC_TYPE_TMP_BUFFER = 38,
    DYNAMIC_TYPE_DTLS_MSG = 39,
    DYNAMIC_TYPE_X509 = 40,
    DYNAMIC_TYPE_TLSX = 41,
    DYNAMIC_TYPE_OCSP = 42,
    DYNAMIC_TYPE_SIGNATURE = 43,
    DYNAMIC_TYPE_HASHES = 44,
    DYNAMIC_TYPE_SRP = 45,
    DYNAMIC_TYPE_COOKIE_PWD = 46,
    DYNAMIC_TYPE_USER_CRYPTO = 47,
    DYNAMIC_TYPE_OCSP_REQUEST = 48,
    DYNAMIC_TYPE_X509_EXT = 49,
    DYNAMIC_TYPE_X509_STORE = 50,
    DYNAMIC_TYPE_X509_CTX = 51,
    DYNAMIC_TYPE_URL = 52,
    DYNAMIC_TYPE_DTLS_FRAG = 53,
    DYNAMIC_TYPE_DTLS_BUFFER = 54,
    DYNAMIC_TYPE_SESSION_TICK = 55,
    DYNAMIC_TYPE_PKCS = 56,
    DYNAMIC_TYPE_MUTEX = 57,
    DYNAMIC_TYPE_PKCS7 = 58,
    DYNAMIC_TYPE_AES_BUFFER = 59,
    DYNAMIC_TYPE_WOLF_BIGINT = 60,
    DYNAMIC_TYPE_ASN1 = 61,
    DYNAMIC_TYPE_LOG = 62,
    DYNAMIC_TYPE_WRITEDUP = 63,
    DYNAMIC_TYPE_PRIVATE_KEY = 64,
    DYNAMIC_TYPE_HMAC = 65,
    DYNAMIC_TYPE_ASYNC = 66,
    DYNAMIC_TYPE_ASYNC_NUMA = 67,
    DYNAMIC_TYPE_ASYNC_NUMA64 = 68,
    DYNAMIC_TYPE_CURVE25519 = 69,
    DYNAMIC_TYPE_ED25519 = 70,
    DYNAMIC_TYPE_SECRET = 71,
    DYNAMIC_TYPE_DIGEST = 72,
    DYNAMIC_TYPE_RSA_BUFFER = 73,
    DYNAMIC_TYPE_DCERT = 74,
    DYNAMIC_TYPE_STRING = 75,
    DYNAMIC_TYPE_PEM = 76,
    DYNAMIC_TYPE_DER = 77,
    DYNAMIC_TYPE_CERT_EXT = 78,
    DYNAMIC_TYPE_ALPN = 79,
    DYNAMIC_TYPE_ENCRYPTEDINFO = 80,
    DYNAMIC_TYPE_DIRCTX = 81,
    DYNAMIC_TYPE_HASHCTX = 82,
    DYNAMIC_TYPE_SEED = 83,
    DYNAMIC_TYPE_SYMMETRIC_KEY = 84,
    DYNAMIC_TYPE_ECC_BUFFER = 85,
    DYNAMIC_TYPE_SALT = 87,
    DYNAMIC_TYPE_HASH_TMP = 88,
    DYNAMIC_TYPE_BLOB = 89,
    DYNAMIC_TYPE_NAME_ENTRY = 90,
    DYNAMIC_TYPE_CURVE448 = 91,
    DYNAMIC_TYPE_ED448 = 92,
    DYNAMIC_TYPE_AES = 93,
    DYNAMIC_TYPE_CMAC = 94,
    DYNAMIC_TYPE_FALCON = 95,
    DYNAMIC_TYPE_SESSION = 96,
    DYNAMIC_TYPE_DILITHIUM = 97,
    DYNAMIC_TYPE_SNIFFER_SERVER = 1000,
    DYNAMIC_TYPE_SNIFFER_SESSION = 1001,
    DYNAMIC_TYPE_SNIFFER_PB = 1002,
    DYNAMIC_TYPE_SNIFFER_PB_BUFFER = 1003,
    DYNAMIC_TYPE_SNIFFER_TICKET_ID = 1004,
    DYNAMIC_TYPE_SNIFFER_NAMED_KEY = 1005,
    DYNAMIC_TYPE_SNIFFER_KEY = 1006
}

/* max error buffer string size */

/* stack protection */
enum {
    MIN_STACK_BUFFER = 8
}

/* Algorithm Types */
enum wc_AlgoType {
    WC_ALGO_TYPE_NONE = 0,
    WC_ALGO_TYPE_HASH = 1,
    WC_ALGO_TYPE_CIPHER = 2,
    WC_ALGO_TYPE_PK = 3,
    WC_ALGO_TYPE_RNG = 4,
    WC_ALGO_TYPE_SEED = 5,
    WC_ALGO_TYPE_HMAC = 6,
    WC_ALGO_TYPE_CMAC = 7,

    WC_ALGO_TYPE_MAX = WC_ALGO_TYPE_CMAC
}

/* hash types */
enum wc_HashType {
    /* In selftest build, WC_* types are not mapped to WC_HASH_TYPE types.
     * Values here are based on old selftest hmac.h enum, with additions.
     * These values are fixed for backwards FIPS compatibility */

    /* SHA-1 (not old SHA-0) */

    WC_HASH_TYPE_NONE = 0,
    WC_HASH_TYPE_MD2 = 1,
    WC_HASH_TYPE_MD4 = 2,
    WC_HASH_TYPE_MD5 = 3,
    WC_HASH_TYPE_SHA = 4, /* SHA-1 (not old SHA-0) */
    WC_HASH_TYPE_SHA224 = 5,
    WC_HASH_TYPE_SHA256 = 6,
    WC_HASH_TYPE_SHA384 = 7,
    WC_HASH_TYPE_SHA512 = 8,
    WC_HASH_TYPE_MD5_SHA = 9,
    WC_HASH_TYPE_SHA3_224 = 10,
    WC_HASH_TYPE_SHA3_256 = 11,
    WC_HASH_TYPE_SHA3_384 = 12,
    WC_HASH_TYPE_SHA3_512 = 13,
    WC_HASH_TYPE_BLAKE2B = 14,
    WC_HASH_TYPE_BLAKE2S = 15,

    WC_HASH_TYPE_SHA512_224 = 16,

    WC_HASH_TYPE_SHA512_256 = 17,

    WC_HASH_TYPE_SHAKE128 = 18,
    WC_HASH_TYPE_SHAKE256 = 19,

    WC_HASH_TYPE_MAX = _WC_HASH_TYPE_MAX /* HAVE_SELFTEST */
}

/* cipher types */
enum wc_CipherType {
    WC_CIPHER_NONE = 0,
    WC_CIPHER_AES = 1,
    WC_CIPHER_AES_CBC = 2,
    WC_CIPHER_AES_GCM = 3,
    WC_CIPHER_AES_CTR = 4,
    WC_CIPHER_AES_XTS = 5,
    WC_CIPHER_AES_CFB = 6,
    WC_CIPHER_AES_CCM = 12,
    WC_CIPHER_AES_ECB = 13,
    WC_CIPHER_DES3 = 7,
    WC_CIPHER_DES = 8,
    WC_CIPHER_CHACHA = 9,

    WC_CIPHER_MAX = WC_CIPHER_AES_CCM
}

/* PK=public key (asymmetric) based algorithms */
enum wc_PkType {
    WC_PK_TYPE_NONE = 0,
    WC_PK_TYPE_RSA = 1,
    WC_PK_TYPE_DH = 2,
    WC_PK_TYPE_ECDH = 3,
    WC_PK_TYPE_ECDSA_SIGN = 4,
    WC_PK_TYPE_ECDSA_VERIFY = 5,
    WC_PK_TYPE_ED25519_SIGN = 6,
    WC_PK_TYPE_CURVE25519 = 7,
    WC_PK_TYPE_RSA_KEYGEN = 8,
    WC_PK_TYPE_EC_KEYGEN = 9,
    WC_PK_TYPE_RSA_CHECK_PRIV_KEY = 10,
    WC_PK_TYPE_EC_CHECK_PRIV_KEY = 11,
    WC_PK_TYPE_ED448 = 12,
    WC_PK_TYPE_CURVE448 = 13,
    WC_PK_TYPE_ED25519_VERIFY = 14,
    WC_PK_TYPE_ED25519_KEYGEN = 15,
    WC_PK_TYPE_CURVE25519_KEYGEN = 16,
    WC_PK_TYPE_MAX = WC_PK_TYPE_CURVE25519_KEYGEN
}

/* settings detection for compile vs runtime math incompatibilities */
enum {
    CTC_SETTINGS = 0x10
}

word32 CheckRunTimeSettings();
enum WOLFSSL_MAX_16BIT = 0xffffU;

extern (D) auto XSTR_SIZEOF(T)(auto ref T x) {
    return x.sizeof - 1;
}

extern (D) auto XREALLOC(T0, T1, T2, T3)(auto ref T0 p, auto ref T1 n, auto ref T2 h, auto ref T3 t) {
    return wolfSSL_Realloc(p, n);
}

alias XMEMCPY = memcpy;
alias XMEMSET = memset;
alias XMEMCMP = memcmp;
alias XMEMMOVE = memmove;
alias XSTRLEN = strlen;
alias XSTRNCPY = strncpy;
alias XSTRSTR = strstr;
// DSTEP: alias XSTRNSTR = mystrnstr;
alias XSTRNCMP = strncmp;
alias XSTRCMP = strcmp;
alias XSTRNCAT = strncat;
alias XSTRSEP = wc_strsep;
// DSTEP: alias XSTRCASECMP = strcasecmp;
// DSTEP: alias XSTRNCASECMP = strncasecmp;
alias XSNPRINTF = snprintf;
alias XATOI = atoi;
alias XSTRLCPY = wc_strlcpy;
alias XSTRLCAT = wc_strlcat;
alias XGETENV = getenv;
// DSTEP: alias XTOUPPER = toupper;
// DSTEP: alias XTOLOWER = tolower;
enum WOLFSSL_MAX_ERROR_SZ = 80;
enum _WC_HASH_TYPE_MAX = wc_HashType.WC_HASH_TYPE_SHAKE256;
// DSTEP: enum _WC_HASH_TYPE_MAX = wc_HashType.WC_HASH_TYPE_SHAKE256;
// DSTEP: enum _WC_HASH_TYPE_MAX = wc_HashType.WC_HASH_TYPE_SHAKE256;
// DSTEP: enum _WC_HASH_TYPE_MAX = wc_HashType.WC_HASH_TYPE_SHAKE256;

/* If user uses RSA, DH, DSA, or ECC math lib directly then fast math and long
   types need to match at compile time and run time, CheckCtcSettings will
   return 1 if a match otherwise 0 */
extern (D) auto CheckCtcSettings() {
    return .CTC_SETTINGS == CheckRunTimeSettings();
}

/* invalid device id */
enum INVALID_DEVID = -2;

/* AESNI requires alignment and ARMASM gains some performance from it
 * Xilinx RSA operations require alignment */

/* WOLFSSL_AESNI || WOLFSSL_ARMASM || USE_INTEL_SPEEDUP || WOLFSSL_AFALG_XILINX */

/* disable align warning, we want alignment ! */

/* !ALIGN16 */

/* disable align warning, we want alignment ! */

/* !ALIGN32 */

/* disable align warning, we want alignment ! */

/* !ALIGN64 */

/* disable align warning, we want alignment ! */

/* disable align warning, we want alignment ! */

/* WOLFSSL_USE_ALIGN */

/* !PEDANTIC_EXTENSION */

enum TRUE = 1;

enum FALSE = 0;

/* not GNUC */

void PRAGMA_CLANG_DIAG_PUSH() {
    pragma(msg, "clang diagnostic push");
}
// DSTEP: alias PRAGMA_CLANG = _Pragma;
void PRAGMA_CLANG_DIAG_POP() {
    pragma(msg, "clang diagnostic pop");
}

/* disable buggy MSC warning around while(0),
 *"warning C4127: conditional expression is constant"
 */

/* disable buggy MSC warning (incompatible with clang-tidy
 * readability-avoid-const-params-in-decls)
 * "warning C4028: formal parameter x different from declaration"
 */

/* extern "C" */

/* WOLF_CRYPT_TYPES_H */
