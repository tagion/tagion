/* memory.h
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

/* submitted by eof */

/*!
    \file wolfssl/wolfcrypt/memory.h
*/

module tagion.network.wolfssl.c.wolfcrypt.memory;

import tagion.network.wolfssl.c.wolfcrypt.types;
import tagion.network.wolfssl.wolfssl_config;

extern (C):

/* OPENSSL_EXTRA */

/* WOLFSSL_DEBUG_MEMORY */

/* Public in case user app wants to use XMALLOC/XFREE */

alias wolfSSL_Malloc_cb = void* function (size_t size);
alias wolfSSL_Free_cb = void function (void* ptr);
alias wolfSSL_Realloc_cb = void* function (void* ptr, size_t size);
/* Public in case user app wants to use XMALLOC/XFREE */
void* wolfSSL_Malloc (size_t size);
void wolfSSL_Free (void* ptr);
void* wolfSSL_Realloc (void* ptr, size_t size);
/* WOLFSSL_DEBUG_MEMORY */
/* WOLFSSL_STATIC_MEMORY */

/* Public get/set functions */
int wolfSSL_SetAllocators (
    wolfSSL_Malloc_cb mf,
    wolfSSL_Free_cb ff,
    wolfSSL_Realloc_cb rf);
int wolfSSL_GetAllocators (
    wolfSSL_Malloc_cb* mf,
    wolfSSL_Free_cb* ff,
    wolfSSL_Realloc_cb* rf);

/* number of default memory blocks */

/* 16 byte aligned */

/* default size of chunks of memory to separate into */

/* extra storage in structs for multiple attributes and order */

/* certificate extensions requires 24k for the SSL struct */

/* increase 23k for object member of WOLFSSL_X509_NAME_ENTRY */

/* Low resource and not RSA */

/* flags for loading static memory (one hot bit) */

/* peak memory usage    */
/* current memory usage */
/* peak memory allocations */
/* current memory allocations */
/* total memory allocations for lifetime */
/* total frees for lifetime */

/* current memory allocations */
/* total memory allocations for lifetime */
/* total frees for lifetime */
/* total amount of memory used in blocks */
/* available IO specific pools */
/* max number of concurrent handshakes allowed */
/* max number of concurrent IO connections allowed */
/* block sizes in stacks */
/* ava block sizes */

/* flag used */

/* internal structure for mem bucket */

/* list of buffers to use for IO */
/* max concurrent handshakes */

/* max concurrent IO connections */

/* memory sizes in ava list */
/* general distribution */
/* amount of memory currently in use */

/* total number of allocs */
/* total number of frees  */

/* structure passed into XMALLOC as heap hint
 * having this abstraction allows tracking statistics of individual ssl's
 */

/* hold individual connection stats */
/* set if using fixed io buffers */

/* flag used for checking handshake count */

/* WOLFSSL_STATIC_MEMORY */

/* WOLFSSL_STACK_LOG */

/* extern "C" */

/* WOLFSSL_MEMORY_H */
