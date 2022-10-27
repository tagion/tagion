/* settings.h
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

module tagion.network.wolfssl.c.wolfcrypt.settings;

import tagion.network.wolfssl.wolfssl_config;

extern (C):
nothrow:
@nogc:

/*
 *   ************************************************************************
 *
 *   ******************************** NOTICE ********************************
 *
 *   ************************************************************************
 *
 *   This method of uncommenting a line in settings.h is outdated.
 *
 *   Please use user_settings.h / WOLFSSL_USER_SETTINGS
 *
 *         or
 *
 *   ./configure CFLAGS="-DFLAG"
 *
 *   For more information see:
 *
 *   https://www.wolfssl.com/how-do-i-manage-the-build-configuration-of-wolfssl/
 *
 */

/* Place OS specific preprocessor flags, defines, includes here, will be
   included into every file because types.h includes it */

/* This flag allows wolfSSL to include options.h instead of having client
 * projects do it themselves. This should *NEVER* be defined when building
 * wolfSSL as it can cause hard to debug problems. */

/* Uncomment next line if using IPHONE */
/* #define IPHONE */

/* Uncomment next line if using ThreadX */
/* #define THREADX */

/* Uncomment next line if using Micrium uC/OS-III */
/* #define MICRIUM */

/* Uncomment next line if using Deos RTOS*/
/* #define WOLFSSL_DEOS*/

/* Uncomment next line if using Mbed */
/* #define MBED */

/* Uncomment next line if using Microchip PIC32 ethernet starter kit */
/* #define MICROCHIP_PIC32 */

/* Uncomment next line if using Microchip TCP/IP stack, version 5 */
/* #define MICROCHIP_TCPIP_V5 */

/* Uncomment next line if using Microchip TCP/IP stack, version 6 or later */
/* #define MICROCHIP_TCPIP */

/* Uncomment next line if using above Microchip TCP/IP defines with BSD API */
/* #define MICROCHIP_TCPIP_BSD_API */

/* Uncomment next line if using PIC32MZ Crypto Engine */
/* #define WOLFSSL_MICROCHIP_PIC32MZ */

/* Uncomment next line if using FreeRTOS */
/* #define FREERTOS */

/* Uncomment next line if using FreeRTOS+ TCP */
/* #define FREERTOS_TCP */

/* Uncomment next line if using FreeRTOS Windows Simulator */
/* #define FREERTOS_WINSIM */

/* Uncomment next line if using RTIP */
/* #define EBSNET */

/* Uncomment next line if using lwip */
/* #define WOLFSSL_LWIP */

/* Uncomment next line if building wolfSSL for a game console */
/* #define WOLFSSL_GAME_BUILD */

/* Uncomment next line if building wolfSSL for LSR */
/* #define WOLFSSL_LSR */

/* Uncomment next line if building for Freescale Classic MQX version 5.0 */
/* #define FREESCALE_MQX_5_0 */

/* Uncomment next line if building for Freescale Classic MQX version 4.0 */
/* #define FREESCALE_MQX_4_0 */

/* Uncomment next line if building for Freescale Classic MQX/RTCS/MFS */
/* #define FREESCALE_MQX */

/* Uncomment next line if building for Freescale KSDK MQX/RTCS/MFS */
/* #define FREESCALE_KSDK_MQX */

/* Uncomment next line if building for Freescale KSDK Bare Metal */
/* #define FREESCALE_KSDK_BM */

/* Uncomment next line if building for Freescale KSDK FreeRTOS, */
/* (old name FREESCALE_FREE_RTOS) */
/* #define FREESCALE_KSDK_FREERTOS */

/* Uncomment next line if using STM32F2 */
/* #define WOLFSSL_STM32F2 */

/* Uncomment next line if using STM32F4 */
/* #define WOLFSSL_STM32F4 */

/* Uncomment next line if using STM32FL */
/* #define WOLFSSL_STM32FL */

/* Uncomment next line if using STM32F7 */
/* #define WOLFSSL_STM32F7 */

/* Uncomment next line if using QL SEP settings */
/* #define WOLFSSL_QL */

/* Uncomment next line if building for EROAD */
/* #define WOLFSSL_EROAD */

/* Uncomment next line if building for IAR EWARM */
/* #define WOLFSSL_IAR_ARM */

/* Uncomment next line if building for Rowley CrossWorks ARM */
/* #define WOLFSSL_ROWLEY_ARM */

/* Uncomment next line if using TI-RTOS settings */
/* #define WOLFSSL_TIRTOS */

/* Uncomment next line if building with PicoTCP */
/* #define WOLFSSL_PICOTCP */

/* Uncomment next line if building for PicoTCP demo bundle */
/* #define WOLFSSL_PICOTCP_DEMO */

/* Uncomment next line if building for uITRON4  */
/* #define WOLFSSL_uITRON4 */

/* Uncomment next line if building for uT-Kernel */
/* #define WOLFSSL_uTKERNEL2 */

/* Uncomment next line if using Max Strength build */
/* #define WOLFSSL_MAX_STRENGTH */

/* Uncomment next line if building for VxWorks */
/* #define WOLFSSL_VXWORKS */

/* Uncomment next line if building for Nordic nRF5x platform */
/* #define WOLFSSL_NRF5x */

/* Uncomment next line to enable deprecated less secure static DH suites */
/* #define WOLFSSL_STATIC_DH */

/* Uncomment next line to enable deprecated less secure static RSA suites */
/* #define WOLFSSL_STATIC_RSA */

/* Uncomment next line if building for ARDUINO */
/* Uncomment both lines if building for ARDUINO on INTEL_GALILEO */
/* #define WOLFSSL_ARDUINO */
/* #define INTEL_GALILEO */

/* Uncomment next line to enable asynchronous crypto WC_PENDING_E */
/* #define WOLFSSL_ASYNC_CRYPT */

/* Uncomment next line if building for uTasker */
/* #define WOLFSSL_UTASKER */

/* Uncomment next line if building for embOS */
/* #define WOLFSSL_EMBOS */

/* Uncomment next line if building for RIOT-OS */
/* #define WOLFSSL_RIOT_OS */

/* Uncomment next line if building for using XILINX hardened crypto */
/* #define WOLFSSL_XILINX_CRYPT */

/* Uncomment next line if building for using XILINX */
/* #define WOLFSSL_XILINX */

/* Uncomment next line if building for WICED Studio. */
/* #define WOLFSSL_WICED  */

/* Uncomment next line if building for Nucleus 1.2 */
/* #define WOLFSSL_NUCLEUS_1_2 */

/* Uncomment next line if building for using Apache mynewt */
/* #define WOLFSSL_APACHE_MYNEWT */

/* For Espressif chips see example user_settings.h
 *
 * https://github.com/wolfSSL/wolfssl/blob/master/IDE/Espressif/ESP-IDF/user_settings.h
 */

/* Uncomment next line if building for using ESP-IDF */
/* #define WOLFSSL_ESPIDF */

/* Uncomment next line if using Espressif ESP32-WROOM-32 */
/* #define WOLFSSL_ESPWROOM32 */

/* Uncomment next line if using Espressif ESP32-WROOM-32SE */
/* #define WOLFSSL_ESPWROOM32SE */

/* Uncomment next line if using ARM CRYPTOCELL*/
/* #define WOLFSSL_CRYPTOCELL */

/* Uncomment next line if using RENESAS TSIP */
/* #define WOLFSSL_RENESAS_TSIP */

/* Uncomment next line if using RENESAS RX64N */
/* #define WOLFSSL_RENESAS_RX65N */

/* Uncomment next line if using RENESAS SCE Protected Mode */
/* #define WOLFSSL_RENESAS_SCEPROTECT */

/* Uncomment next line if using RENESAS RA6M4 */
/* #define WOLFSSL_RENESAS_RA6M4 */

/* Uncomment next line if using Solaris OS*/
/* #define WOLFSSL_SOLARIS */

/* Uncomment next line if building for Linux Kernel Module */
/* #define WOLFSSL_LINUXKM */

/* Uncomment next line if building for devkitPro */
/* #define DEVKITPRO */

/* Uncomment next line if building for Dolphin Emulator */
/* #define DOLPHIN_EMULATOR */

/* STM Configuration File (generated by CubeMX) */

extern (D) auto WOLFSSL_MAKE_FIPS_VERSION(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    return (major * 256) + minor;
}

enum WOLFSSL_FIPS_VERSION_CODE = WOLFSSL_MAKE_FIPS_VERSION(0, 0);

extern (D) auto FIPS_VERSION_LT(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    return WOLFSSL_FIPS_VERSION_CODE < WOLFSSL_MAKE_FIPS_VERSION(major, minor);
}

extern (D) auto FIPS_VERSION_LE(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    return WOLFSSL_FIPS_VERSION_CODE <= WOLFSSL_MAKE_FIPS_VERSION(major, minor);
}

extern (D) auto FIPS_VERSION_EQ(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    return WOLFSSL_FIPS_VERSION_CODE == WOLFSSL_MAKE_FIPS_VERSION(major, minor);
}

extern (D) auto FIPS_VERSION_GE(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    return WOLFSSL_FIPS_VERSION_CODE >= WOLFSSL_MAKE_FIPS_VERSION(major, minor);
}

extern (D) auto FIPS_VERSION_GT(T0, T1)(auto ref T0 major, auto ref T1 minor)
{
    return WOLFSSL_FIPS_VERSION_CODE > WOLFSSL_MAKE_FIPS_VERSION(major, minor);
}

/* make sure old RNG name is used with CTaoCrypt FIPS */

/* blinding adds API not available yet in FIPS mode */

/* The _M_X64 macro is what's used in the headers for MSC to tell if it
 * has the 64-bit versions of the 128-bit integers available. If one is
 * building on 32-bit Windows with AES-NI, turn off the AES-GCMloop
 * unrolling. */

/* WOLFSSL_ESPIDF */

/* WOLFCRYPT_ONLY */

/* 20 words */
/* in byte  */

/* WOLFSSL_RENESAS_TSIP */

/* 20 words */

/* in bytes */
/* in bytes */
/* in bytes */
/* in bytes */

/* #define DEBUG_PK_CB */

/* settings in user_settings.h */

/* using LwIP native TCP socket */

/* #define WOLFSSL_MICROCHIP_PIC32MZ */

/* include timer functions */

/* include timer, NTP functions */

/* backwards compatibility */

/* Allows use of DH with fixed points if uncommented and NO_DH is removed */
/* WOLFSSL_DH_CONST */

/* Allows use of DH with fixed points if uncommented and NO_DH is removed */
/* WOLFSSL_DH_CONST */

/* VxWorks simulator incorrectly detects building for i386 */

/* For VxWorks pthreads wrappers for mutexes uncomment the next line. */
/* #define WOLFSSL_PTHREADS */

/* Galileo has time.h compatibility */

/* uTasker configuration - used for fnRandom() */

/* used in wolfCrypt test */

/* uTasker port uses RAW sockets, use I/O callbacks
 * See wolfSSL uTasker example for sample callbacks */

/* uTasker filesystem not ported  */

/* uTasker RNG is abstracted, calls HW RNG when available */

/* user needs to define XTIME to function that provides
 * seconds since Unix epoch */

/* #define XTIME fnSecondsSinceEpoch */

/* use uTasker std library replacements where available */

/* Not ported at this time */
/* use when NO_FILESYSTEM */

/* ChibiOS definitions. This file is distributed with chibiOS. */

/* PB is using older 1.2 version of Nucleus */

/* Micrium will use Visual Studio for compilation but not the Win32 API */

/* initializing malloc pool */

/* static char* gets(char *buff); */

/* !NO_STDIO_FGETS_REMAP */

/* FreeRTOS pvPortRealloc() implementation can be found here:
    https://github.com/wolfSSL/wolfssl-freertos/pull/3/files */

/*In IDF, realloc(p, n) is equivalent to
heap_caps_realloc(p, s, MALLOC_CAP_8BIT) */

/* Use SP_MATH by default, unless
 * specified in user_settings.
 */

/* Uncomment this setting if your toolchain does not offer time.h header */
/* #define USER_TIME */

/* use with HAVE_ALPN */

/* Suppress the sslpro warning */

/* #define DEBUG_WOLFSSL */
/* tbd */

/* EBSNET */

/* Allows use of DH with fixed points if uncommented and NO_DH is removed */
/* WOLFSSL_DH_CONST */

/* for tcp errno */

/* enum uses enum */

/* FreeRTOS pvPortRealloc() implementation can be found here:
    https://github.com/wolfSSL/wolfssl-freertos/pull/3/files */

/* To support storing some of the large constant tables in flash memory rather than SRAM.
   Useful for processors that have limited SRAM, such as the AVR family of microtrollers. */

/* This is supported on the avr-gcc compiler, for more information see:
     https://gcc.gnu.org/onlinedocs/gcc/Named-Address-Spaces.html */

/* Copy data out of flash memory and into SRAM */

/* use normal Freescale MQX port, but with minor changes for 5.0 */

/* use normal Freescale MQX port, but with minor changes for 4.0 */

/* Note: MQX has no realloc, using fastmath above */

/* Undef first to avoid re-definition if user_settings.h defines */

/* since MQX 4.1.2 */

/* FREESCALE_KSDK_MQX */

/* #define USER_TICKS */
/* Allows use of DH with fixed points if uncommented and NO_DH is removed */
/* WOLFSSL_DH_CONST */

/* FREESCALE_FREE_RTOS || FREESCALE_KSDK_FREERTOS */

/* FREESCALE_KSDK_BM */

/* disable features */

/* enable features */

/* Classic MQX does not have fsl_common.h */

/* random seed */

/* nothing to define */

/* defaulting to K70 RNGA, user should change if different */
/* #define FREESCALE_K53_RNGB */

/* HW crypto */
/* automatic enable based on Kinetis feature */
/* if case manual selection is required, for example for benchmarking purposes,
 * just define FREESCALE_USE_MMCAU or FREESCALE_USE_LTC or none of these two macros (for software only)
 * both can be enabled simultaneously as LTC has priority over MMCAU in source code.
 */
/* #define FSL_HW_CRYPTO_MANUAL_SELECTION */

/* #define FREESCALE_USE_MMCAU */
/* #define FREESCALE_USE_LTC */

/* FREESCALE_COMMON */

/* Classic pre-KSDK mmCAU library */

/* KSDK mmCAU library */

/* AES and DES */

/* MD5, SHA-1 and SHA-256 */

/* FREESCALE_USE_MMCAU */

/* the LTC PKHA hardware limit is 2048 bits (256 bytes) for integer arithmetic.
   the LTC_MAX_INT_BYTES defines the size of local variables that hold big integers. */
/* size is multiplication of 2 big ints */

/* This FREESCALE_LTC_TFM_RSA_4096_ENABLE macro can be defined.
 * In such a case both software and hardware algorithm
 * for TFM is linked in. The decision for which algorithm is used is determined at runtime
 * from size of inputs. If inputs and result can fit into LTC (see LTC_MAX_INT_BYTES)
 * then we call hardware algorithm, otherwise we call software algorithm.
 *
 * Chinese reminder theorem is used to break RSA 4096 exponentiations (both public and private key)
 * into several computations with 2048-bit modulus and exponents.
 */
/* #define FREESCALE_LTC_TFM_RSA_4096_ENABLE */

/* ECC-384, ECC-256, ECC-224 and ECC-192 have been enabled with LTC PKHA acceleration */

/* the LTC PKHA hardware limit is 512 bits (64 bytes) for ECC.
   the LTC_MAX_ECC_BITS defines the size of local variables that hold ECC parameters
   and point coordinates */

/* Enable curves up to 384 bits */

/* FREESCALE_USE_LTC */

/* FREESCALE_LTC_TFM_RSA_4096_ENABLE */

/* if LTC has AES engine but doesn't have GCM, use software with LTC AES ECB mode */

/* hardware does not support 192-bit */

/* WOLFSSL_STM32_CUBEMX */
/* WOLFSSL_STM32F2 || WOLFSSL_STM32F4 || WOLFSSL_STM32L4 ||
   WOLFSSL_STM32L5 || WOLFSSL_STM32F7 || WOLFSSL_STMWB ||
   WOLFSSL_STM32H7 || WOLFSSL_STM32G0 || WOLFSSL_STM32U5 */

/* for rand_r: pseudo-random number generator */
/* for snprintf */

/* use external memory XMALLOC, XFREE and XREALLOC functions */

/* disable fall-back case, malloc, realloc and free are unavailable */

/* file system has not been ported since it is a separate product. */

/* WOLFSSL_DEOS*/

/* Work around for Micrium OS version 5.8 change in behavior
 * that returns DEF_NO for 0 size compare
 */

/* MICRIUM */

/* Solaris */

/* SunOS */

/* Avoid naming clash with fp_zero from math.h > ieefp.h */

/* WOLFSSL_QL */

/* only SHA3-384 is supported */

/*(WOLFSSL_XILINX_CRYPT)*/

/*(WOLFSSL_APACHE_MYNEWT)*/

/* if defined turn on all CAAM support */

/* large performance gain with HAVE_AES_ECB defined */

/* @TODO used for now until plugging in caam aes use with qnx */

/* If DCP is used without SINGLE_THREADED, enforce WOLFSSL_CRYPT_HW_MUTEX */

/* stream ciphers except arc4 need 32bit alignment, intel ok without */

/* write dup cannot be used with secure renegotiation because write dup
 * make write side write only and read side read only */

/* _MSC_VER */

/* can not use headers such as windows.h */

/* WOLFSSL_SGX */

/* FreeScale MMCAU hardware crypto has 4 byte alignment.
   However, KSDK fsl_mmcau.h gives API with no alignment
   requirements (4 byte alignment is managed internally by fsl_mmcau.c) */

/* if using hardware crypto and have alignment requirements, specify the
   requirement here.  The record header of SSL/TLS will prevent easy alignment.
   This hint tries to help as much as possible.  */

enum WOLFSSL_GENERAL_ALIGNMENT = 0;

/* explicit casts to smaller sizes, disable */

/* ---------------------------------------------------------------------------
 * Math Library Selection (in order of preference)
 * ---------------------------------------------------------------------------
 */

/*  1) SP Math: wolfSSL proprietary math implementation (sp_int.c).
 *      Constant time: Always
 *      Enable:        WOLFSSL_SP_MATH_ALL
 */

/*  2) SP Math with restricted key sizes: wolfSSL proprietary math
 *         implementation (sp_*.c).
 *      Constant time: Always
 *      Enable:        WOLFSSL_SP_MATH
 */
/*  3) Tom's Fast Math: Stack based (tfm.c)
 *      Constant time: Only with TFM_TIMING_RESISTANT
 *      Enable:        USE_FAST_MATH
 */

/*  4) Integer Heap Math:  Heap based (integer.c)
 *      Constant time: Not supported
 *      Enable:        USE_INTEGER_HEAP_MATH
 */

/* default is SP Math. */

/* FIPS 140-2 or older */
/* Default to fast math (tfm.c), but allow heap math (integer.c) */

/*----------------------------------------------------------------------------*/

/* user can specify what curves they want with ECC_USER_CURVES otherwise
 * all curves are on by default for now */

/* The minimum allowed ECC key size */
/* Note: 224-bits is equivalent to 2048-bit RSA */

/* FIPSv2 and ready (for now) includes 192-bit support */

enum ECC_MIN_KEY_SZ = 224;

/* ECC Configs */

/* By default enable Sign, Verify, DHE, Key Import and Key Export unless explicitly disabled */

/* HAVE_ECC */

/* Curve25519 Configs */

/* By default enable shared secret, key export and import */

/* HAVE_CURVE25519 */

/* Ed25519 Configs */

/* By default enable sign, verify, key export and import */

/* HAVE_ED25519 */

/* Curve448 Configs */

/* By default enable shared secret, key export and import */

/* HAVE_CURVE448 */

/* Ed448 Configs */

/* By default enable sign, verify, key export and import */

/* HAVE_ED448 */

/* AES Config */

/* By default enable all AES key sizes, decryption and CBC */

enum AES_MAX_KEY_SIZE = 256;

/* AES-XTS makes calls to AES direct functions */

/* AES-CFB makes calls to AES direct functions */

/* This should only be enabled for FIPS v2 or older. It enables use of the
 * older wc_Dh_ffdhe####_Get() API's */

enum MIN_FFDHE_BITS = 0;

enum MIN_FFDHE_FP_MAX_BITS = MIN_FFDHE_BITS * 2;

/* if desktop type system and fastmath increase default max bits */

/* If using the max strength build, ensure OLD TLS is disabled. */

/* Default AES minimum auth tag sz, allow user to override */

enum WOLFSSL_MIN_AUTH_TAG_SZ = 12;

/* sniffer requires:
 * static RSA cipher suites
 * session stats and peak stats
 */

/* Allow option to be disabled. */

/* Decode Public Key extras on by default, user can turn off with
 * WOLFSSL_NO_DECODE_EXTRA */

/* C Sharp wrapper defines */

/* Asynchronous Crypto */

/* Make sure wolf events are enabled */

/* Enable ECC_CACHE_CURVE for ASYNC */

/* WOLFSSL_ASYNC_CRYPT */

enum WC_ASYNC_DEV_SIZE = 0;

/* leantls checks */

/* WOLFSSL_LEANTLS*/

/* restriction with static memory */

/* WOLFSSL_STATIC_MEMORY */

/* for backwards compatibility */

/* Place any other flags or defines here */

/* don't trust macro with windows */
/* WOLFSSL_MYSQL_COMPATIBLE */

/* Session Tickets will be enabled when --enable-opensslall is used.
 * Time is required for ticket expiration checking */

/* OCSP will be enabled in configure.ac when --enable-opensslall is used,
 * but do not force all users to have it enabled. */

/*#define HAVE_OCSP*/

/* both CURVE and ED small math should be enabled */

/* both CURVE and ED small math should be enabled */

enum WOLFSSL_ALERT_COUNT_MAX = 5;

/* warning for not using harden build options (default with ./configure) */

/* make sure old names are disabled */

/* added to have compatibility with SHA256() */

/* switch for compatibility layer functionality. Has subparts i.e. BIO/X509
 * When opensslextra is enabled all subparts should be turned on. */

/* OPENSSL_EXTRA */

/* support for converting DER to PEM */

/* keep backwards compatibility enabling encrypted private key */

/* support for disabling PEM to DER */

/* Parts of the openssl compatibility layer require peer certs */

/*
 * Keeps the "Finished" messages after a TLS handshake for use as the so-called
 * "tls-unique" channel binding. See comment in internal.h around clientFinished
 * and serverFinished for more information.
 */

/* RAW hash function APIs are not implemented */

/* XChacha not implemented with ARM assembly ChaCha */

/* Detect old cryptodev name */

/* allow for five items of ex_data */

/* The client session cache requires time for timeout */

/* Use static ECC structs for Position Independant Code (PIC) */

/* FIPS v1 does not support TLS v1.3 (requires RSA PSS and HKDF) */

/* For FIPSv2 make sure the ECDSA encoding allows extra bytes
 * but make sure users consider enabling it */
/* ECDSA length checks off by default for CAVP testing
 * consider enabling strict checks in production */

/* Do not allow using small stack with no malloc */

/* Enable DH Extra for QT, openssl all, openssh and static ephemeral */
/* Allows export/import of DH key and params as DER */

/* DH Extra is not supported on FIPS v1 or v2 (is missing DhKey .pub/.priv) */

/* wc_Sha512.devId isn't available before FIPS 5.1 */

/* Enable HAVE_ONE_TIME_AUTH by default for use with TLS cipher suites
 * when poly1305 is enabled
 */

/* Check for insecure build combination:
 * secure renegotiation   [enabled]
 * extended master secret [disabled]
 * session resumption     [enabled]
 */

/* secure renegotiation requires extended master secret with resumption */

/* Note: "--enable-renegotiation-indication" ("HAVE_RENEGOTIATION_INDICATION")
 * only sends the secure renegotiation extension, but is not actually supported.
 * This was added because some TLS peers required it even if not used, so we call
 * this "(FAKE Secure Renegotiation)"
 */

/* if secure renegotiation is enabled, make sure server info is enabled */

/* Crypto callbacks should enable hash flag support */

/* FIPS v1 and v2 do not support hash flags, so do not allow it with
 * crypto callbacks */

/* Enable Post-Quantum Cryptography if we have liboqs from the OpenQuantumSafe
 * group */

/* SRTP requires DTLS */

/* Are we using an external private key store like:
 *     PKCS11 / HSM / crypto callback / PK callback */

/* Enables support for using wolfSSL_CTX_use_PrivateKey_Id and
 *   wolfSSL_CTX_use_PrivateKey_Label */

/* With titan cache size there is too many sessions to fit with the default
 * multiplier of 8 */

/* DTLS v1.3 requires 64-bit number wrappers */

/* DTLS v1.3 requires AES ECB if using AES */

/* RSA Key Checking is disabled by default unless WOLFSSL_RSA_KEY_CHECK is
 *   defined or FIPS v2 3389, FIPS v5 or later.
 * Not allowed for:
 *   RSA public only, CAVP selftest, fast RSA, user RSA, QAT or CryptoCell */

/* ---------------------------------------------------------------------------
 * Depricated Algorithm Handling
 *   Unless allowed via a build macro, disable support
 * ---------------------------------------------------------------------------*/

/* RC4: Per RFC7465 Feb 2015, the cipher suite has been deprecated due to a
 * number of exploits capable of decrypting portions of encrypted messages. */

/* Enable asynchronous support in TLS functions to support one or more of
 * the following:
 * - re-entry after a network blocking return
 * - re-entry after OCSP blocking return
 * - asynchronous cryptography */

/* extern "C" */

