/* wc_port.h
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

module tagion.network.wolfssl.c.wolfcrypt.wc_port;

import core.stdc.stdio;
import core.sys.posix.dirent;
import core.sys.posix.pthread;
import core.sys.posix.sched;
import core.sys.posix.sys.stat;
import core.sys.posix.unistd;

extern (C):
nothrow:
@nogc:

/*!
    \file wolfssl/wolfcrypt/wc_port.h
*/

/* Detect if compiler supports C99. "NO_WOLF_C99" can be defined in
 * user_settings.h to disable checking for C99 support. */

/* GENERIC INCLUDE SECTION */

/* WOLFSSL_LINUXKM */

/* THREADING/MUTEX SECTION */

/* On WinCE winsock2.h must be included before windows.h */

/* required for InetPton */

/* WOLFSSL_SGX */

/* do nothing, just don't pick Unix */

/* do nothing */

/* do nothing */

/* do nothing */

/* do nothing */

/* NU_DEBUG needed struct access in nucleus_realloc */

/* do nothing */

/* Telit SDK uses C++ compile option (--cpp), which causes link issue
    to API's if wrapped in extern "C" */

/* extern "C" */

/* eliminate conflict in asn.h */

/* do nothing */

/* definitions are in linuxkm/linuxkm_wc_port.h */

/* for close of BIO */

/* For FIPS keep the function names the same */

/* HAVE_FIPS */

/* MULTI_THREADED */
/* FREERTOS comes first to enable use of FreeRTOS Windows simulator only */

alias wolfSSL_Mutex = pthread_mutex_t;

/* typedef User_Mutex wolfSSL_Mutex; */

/* definitions are in linuxkm/linuxkm_wc_port.h */

/* USE_WINDOWS_API */
/* SINGLE_THREADED */

/* Reference counting. */
struct wolfSSL_Ref {
    /* TODO: use atomic operations instead of mutex. */

    wolfSSL_Mutex mutex;

    int count;
}

void wolfSSL_RefInit(wolfSSL_Ref* ref_, int* err);
void wolfSSL_RefFree(wolfSSL_Ref* ref_);
void wolfSSL_RefInc(wolfSSL_Ref* ref_, int* err);
void wolfSSL_RefDec(wolfSSL_Ref* ref_, int* isZero, int* err);

/* Enable crypt HW mutex for Freescale MMCAU, PIC32MZ or STM32 */

/* FREESCALE_MMCAU */

enum WOLFSSL_CRYPT_HW_MUTEX = 0;

/* wolfSSL_CryptHwMutexInit is called on first wolfSSL_CryptHwMutexLock,
   however it's recommended to call this directly on Hw init to avoid possible
   race condition where two calls to wolfSSL_CryptHwMutexLock are made at
   the same time. */

/* Define stubs, since HW mutex is disabled */
extern (D) int wolfSSL_CryptHwMutexInit() {
    return 0;
} /* Success */
extern (D) int wolfSSL_CryptHwMutexLock() {
    return 0;
} /* Success */
extern (D) auto wolfSSL_CryptHwMutexUnLock() {
    return cast(void) 0;
} /* Success */
/* WOLFSSL_CRYPT_HW_MUTEX */

/* Mutex functions */
int wc_InitMutex(wolfSSL_Mutex* m);
wolfSSL_Mutex* wc_InitAndAllocMutex();
int wc_FreeMutex(wolfSSL_Mutex* m);
int wc_LockMutex(wolfSSL_Mutex* m);
int wc_UnLockMutex(wolfSSL_Mutex* m);

/* dynamically set which mutex to use. unlock / lock is controlled by flag */

/* main crypto initialization function */
int wolfCrypt_Init();
int wolfCrypt_Cleanup();

/* FILESYSTEM SECTION */
/* filesystem abstraction layer, used by ssl.c */

/* Not prototyped in vfile.h per
 * EBSnet feedback */

/* Not ported yet */

/* Not ported yet */

/* Not ported yet */

/* Not ported yet */

/* Not ported yet */

/* Not ported yet */

/* workaround to declare variable and provide type */

/* stdio, WINCE case */

/* FUSION SPECIFIC ERROR CODE */

/* To be defined in user_settings.h */

/* stdio, default case */

alias XFILE = FILE*;

alias XFOPEN = fopen;

// DSTEP: alias XFDOPEN = fdopen;
alias XFSEEK = fseek;
alias XFTELL = ftell;
alias XREWIND = rewind;
alias XFREAD = fread;
alias XFWRITE = fwrite;
alias XFCLOSE = fclose;
enum XSEEK_END = SEEK_END;
enum XBADFILE = null;
alias XFGETS = fgets;
alias XFPRINTF = fprintf;
alias XFFLUSH = fflush;

alias XWRITE = write;
alias XREAD = read;
alias XCLOSE = close;
alias XSTAT = stat;
alias XS_ISREG = S_ISREG;
enum SEPARATOR_CHAR = ':';

enum MAX_FILENAME_SZ = 256; /* max file name length */

enum MAX_PATH = 256;

int wc_FileLoad(const(char)* fname, ubyte** buf, size_t* bufLen, void* heap);

struct ReadDirCtx {
    dirent* entry;
    DIR* dir;
    stat_t s;

    char[MAX_FILENAME_SZ] name;
}

enum WC_READDIR_NOFILE = -1;

int wc_ReadDirFirst(ReadDirCtx* ctx, const(char)* path, char** name);
int wc_ReadDirNext(ReadDirCtx* ctx, const(char)* path, char** name);
void wc_ReadDirClose(ReadDirCtx* ctx);
/* !NO_WOLFSSL_DIR */
enum WC_ISFILEEXIST_NOFILE = -1;

int wc_FileExists(const(char)* fname);

/* !NO_FILESYSTEM */

/* Defaults, user may over-ride with user_settings.h or in a porting section
 * above
 */

alias XVFPRINTF = vfprintf;

alias XVSNPRINTF = vsnprintf;

alias XFPUTS = fputs;

alias XSPRINTF = sprintf;

/* MIN/MAX MACRO SECTION */
/* Windows API defines its own min() macro. */

/* min */

/* max */
/* USE_WINDOWS_API */

/* TIME SECTION */
/* Time functions */

/* Use our gmtime and time_t/struct tm types.
   Only needs seconds since EPOCH using XTIME function.
   time_t XTIME(time_t * timer) {}
*/

/* Override XTIME() and XGMTIME() functionality.
   Requires user to provide these functions:
    time_t XTIME(time_t * timer) {}
    struct tm* XGMTIME(const time_t* timer, struct tm* tmp) {}
*/

/* dc_rtc_api needs    */
/* to get current time */

/* uses parital <time.h> structures */

/*extern time_t ksdk_time(time_t* timer);*/

/*Gets the timestamp from cloak software owned by VT iDirect
in place of time() from <time.h> */

/* For file system */

/* if struct tm is not defined in WINCE SDK */

/* seconds */
/* minutes */
/* hours */
/* day of month (month specific) */
/* month */
/* year */
/* day of week (out of 1-7)*/
/* day of year (out of 365) */
/* is it daylight savings */

/* definitions are in linuxkm/linuxkm_wc_port.h */

/* default */
/* uses complete <time.h> facility */

/* PowerPC time_t is int */

alias XMKTIME = mktime;
alias XDIFFTIME = difftime;

/* check if size of time_t from autoconf is less than 8 bytes (64bits) */

/* one old reference to TIME_T_NOT_LONG in GCC-ARM example README
 * this keeps support for the old macro name */

/* Map default time functions */

/* Jan 1, 2000 */

alias XTIME = time;

/* Always use gmtime_r if available. */

/* reentrant version */

extern (D) auto XGMTIME(T0, T1)(auto ref T0 c, auto ref T1 t) {
    return gmtime(c);
}

// DSTEP: alias XVALIDATE_DATE = wc_ValidateDate;

/* wolf struct tm and time_t */

/* seconds after the minute [0-60] */
/* minutes after the hour [0-59] */
/* hours since midnight [0-23] */
/* day of the month [1-31] */
/* months since January [0-11] */
/* years since 1900 */
/* days since Sunday [0-6] */
/* days since January 1 [0-365] */
/* Daylight Savings Time flag */
/* offset from CUT in seconds */
/* timezone abbreviation */

/* USE_WOLF_TM */

/* forward declarations */

/* for stack trap tracking, don't call os gmtime on OS X/linux,
   uses a lot of stack spce */

/* STACK_TRAP */

/* NO_ASN_TIME */

char* mystrnstr(const(char)* s1, const(char)* s2, uint n);

/* default static file buffer size for input, will use dynamic buffer if
 * not big enough */

enum FILE_BUFFER_SIZE = 1 * 1024;

/* By default, the OCTEON's global variables are all thread local. This
 * tag allows them to be shared between threads. */

/* callbacks for setting handle */

/* extern "C" */

/* WOLF_CRYPT_PORT_H */
