/* callbacks.h
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

module tagion.network.wolfssl.c.callbacks;

import core.stdc.config;

extern (C):
nothrow:
@nogc:

enum
{
    /* CALLBACK CONSTANTS */
    MAX_PACKETNAME_SZ = 24,
    MAX_CIPHERNAME_SZ = 24,
    MAX_TIMEOUT_NAME_SZ = 24,
    MAX_PACKETS_HANDSHAKE = 14, /* 12 for client auth plus 2 alerts */
    MAX_VALUE_SZ = 128 /* all handshake packets but Cert should
       fit here  */
}

struct WOLFSSL;

struct handShakeInfo_st
{
    WOLFSSL* ssl;
    char[25] cipherName; /* negotiated cipher */
    char[MAX_PACKETS_HANDSHAKE][14] packetNames;
    /* SSL packet names  */
    int numberPackets; /* actual # of packets */
    int negotiationError; /* cipher/parameter err */
}

alias HandShakeInfo = handShakeInfo_st;

/* HAVE_SYS_TIME_H */
/* Define the timeval explicitly. */
struct WOLFSSL_TIMEVAL
{
    c_long tv_sec; /* Seconds. */
    c_long tv_usec; /* Microseconds. */
}

/* HAVE_SYS_TIME_H */

alias Timeval = WOLFSSL_TIMEVAL;

struct packetInfo_st
{
    char[25] packetName; /* SSL packet name */
    WOLFSSL_TIMEVAL timestamp; /* when it occurred    */
    ubyte[MAX_VALUE_SZ] value; /* if fits, it's here */
    ubyte* bufferValue; /* otherwise here (non 0) */
    int valueSz; /* sz of value or buffer */
}

alias PacketInfo = packetInfo_st;

struct timeoutInfo_st
{
    char[25] timeoutName; /* timeout Name */
    int flags; /* for future use */
    int numberPackets; /* actual # of packets */
    PacketInfo[MAX_PACKETS_HANDSHAKE] packets; /* list of all packets  */
    WOLFSSL_TIMEVAL timeoutValue; /* timer that caused it */
}

alias TimeoutInfo = timeoutInfo_st;

/* extern "C" */

/* WOLFSSL_CALLBACKS_H */
