/* tfm.h
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

module tagion.network.wolfssl.c.wolfcrypt.tfm;

import core.stdc.config;
import core.stdc.limits;
import tagion.network.wolfssl.c.wolfcrypt.random;
import tagion.network.wolfssl.c.wolfcrypt.types;

extern (C):
nothrow:
@nogc:

/*
 * Based on public domain TomsFastMath 0.10 by Tom St Denis, tomstdenis@iahu.ca,
 * http://math.libtomcrypt.com
 */

/**
 *  Edited by Moises Guimaraes (moises.guimaraes@phoebus.com.br)
 *  to fit CyaSSL's needs.
 */

/*!
    \file wolfssl/wolfcrypt/tfm.h
*/

/* autodetect x86-64 and make sure we are using 64-bit digits with x86-64 asm */

/* use 64-bit digit even if not using asm on x86_64 */

/* if intel compiler doesn't provide 128 bit type don't turn on 64bit */

/* NO_TFM_64BIT */

/* try to detect x86-32 */

/* make sure we're 32-bit for x86-32/sse/arm/ppc32 */

/* multi asms? */

/* we want no asm? */

/* ECC helpers */

/* allow user to define on fp_digit, fp_word types */

/* some default configurations.
 */

/* for GCC only on supported platforms */
alias fp_digit = ulong; /* 64bit, 128 uses mode(TI) below */
enum SIZEOF_FP_DIGIT = 8;
// DSTEP : alias fp_word = <unimplemented>;
// DSTEP : alias fp_sword = <unimplemented>;

/* some procs like coldfire prefer not to place multiply into 64bit type
   even though it exists */

/* WOLFSSL_BIGINT_TYPES */

/* # of digits this is */
enum DIGIT_BIT = CHAR_BIT * SIZEOF_FP_DIGIT;

/* Max size of any number in bits.  Basically the largest size you will be
 * multiplying should be half [or smaller] of FP_MAX_SIZE-four_digit
 *
 * It defaults to 4096-bits [allowing multiplications up to 2048x2048 bits ]
 */

enum FP_MAX_BITS = 4096;

/* OpenSSH uses some BIG primes so we need to accommodate for that */

enum FP_MAX_SIZE = FP_MAX_BITS + (8 * DIGIT_BIT);

/* will this lib work? */

enum FP_MASK = cast(fp_digit)-1;
enum FP_DIGIT_MAX = FP_MASK;
enum FP_SIZE = FP_MAX_SIZE / DIGIT_BIT;

enum FP_MAX_PRIME_SIZE = FP_MAX_BITS / (2 * CHAR_BIT);
/* In terms of FP_MAX_BITS, it is double the size possible for a number
 * to allow for multiplication, divide that 2 out. Also divide by CHAR_BIT
 * to convert from bits to bytes. (Note, FP_PRIME_SIZE is the number of
 * values in the canned prime number list.) */

/* signs */
enum FP_ZPOS = 0;
enum FP_NEG = 1;

/* return codes */
enum FP_OKAY = 0;
enum FP_VAL = -1;
enum FP_MEM = -2;
enum FP_NOT_INF = -3;
enum FP_WOULDBLOCK = -4;

/* equalities */
enum FP_LT = -1; /* less than */
enum FP_EQ = 0; /* equal to */
enum FP_GT = 1; /* greater than */

/* replies */
enum FP_YES = 1; /* yes response */
enum FP_NO = 0; /* no response */

/* raw big integer */

/* a FP type */
struct fp_int {
    int used;
    int sign;

    fp_digit[72] dp;

    /* unsigned binary (big endian) */
}

/* Types */
alias mp_digit = ulong;
// DSTEP : alias mp_word = <unimplemented>;
alias mp_int = fp_int;

/* wolf big int and common functions */

/* externally define this symbol to ignore the default settings, useful for changing the build from the make process */

/* do we want the large set of small multiplications ?
   Enable these if you are going to be doing a lot of small (<= 16 digit) multiplications say in ECC
   Or if you're on a 64-bit machine doing RSA as a 1024-bit integer == 16 digits ;-)
 */
/* need to refactor the function */
/*#define TFM_SMALL_SET */

/* do we want huge code
   Enable these if you are doing 20, 24, 28, 32, 48, 64 digit multiplications (useful for RSA)
   Less important on 64-bit machines as 32 digits == 2048 bits
 */

/* Optional math checks (enable WOLFSSL_DEBUG_MATH to print info) */
/* #define TFM_CHECK */

/* Is the target a P4 Prescott
 */
/* #define TFM_PRESCOTT */

/* Do we want timing resistant fp_exptmod() ?
 * This makes it slower but also timing invariant with respect to the exponent
 */
/* #define TFM_TIMING_RESISTANT */

/* TFM_ALREADY_SET */

/* functions */

/* returns a TFM ident string useful for debugging... */
/*const char *fp_ident(void);*/

/* initialize [or zero] an fp int */
void fp_init(fp_int* a);
void fp_zero(fp_int* a);
void fp_clear(fp_int* a);
/* uses ForceZero to clear sensitive memory */
void fp_forcezero(fp_int* a);
void fp_free(fp_int* a);

/* zero/one/even/odd/neg/word ? */
extern (D) auto fp_iszero(T)(auto ref T a) {
    return (a.used == 0) ? FP_YES : FP_NO;
}

extern (D) auto fp_isone(T)(auto ref T a) {
    return ((a.used == 1) && (a.dp[0] == 1) && (a.sign == FP_ZPOS)) ? FP_YES : FP_NO;
}

extern (D) auto fp_iseven(T)(auto ref T a) {
    return (a.used > 0 && ((a.dp[0] & 1) == 0)) ? FP_YES : FP_NO;
}

extern (D) auto fp_isodd(T)(auto ref T a) {
    return (a.used > 0 && ((a.dp[0] & 1) == 1)) ? FP_YES : FP_NO;
}

extern (D) auto fp_isneg(T)(auto ref T a) {
    return (a.sign != FP_ZPOS) ? FP_YES : FP_NO;
}

extern (D) auto fp_isword(T0, T1)(auto ref T0 a, auto ref T1 w) {
    return (((a.used == 1) && (a.dp[0] == w)) || ((w == 0) && (a.used == 0))) ? FP_YES : FP_NO;
}

/* set to a small digit */
void fp_set(fp_int* a, fp_digit b);
int fp_set_int(fp_int* a, c_ulong b);

/* check if a bit is set */
int fp_is_bit_set(fp_int* a, fp_digit b);
/* set the b bit to 1 */
int fp_set_bit(fp_int* a, fp_digit b);

/* copy from a to b */
void fp_copy(const(fp_int)* a, fp_int* b);
void fp_init_copy(fp_int* a, fp_int* b);

/* clamp digits */
// DSTEP : alias mp_clamp = fp_clamp;

extern (D) auto mp_grow(T0, T1)(auto ref T0 a, auto ref T1 s) {
    return MP_OKAY;
}

/* negate and absolute */

/* right shift x digits */
void fp_rshd(fp_int* a, int x);

/* right shift x bits */
void fp_rshb(fp_int* c, int x);

/* left shift x digits */
int fp_lshd(fp_int* a, int x);

/* signed comparison */
int fp_cmp(fp_int* a, fp_int* b);

/* unsigned comparison */
int fp_cmp_mag(fp_int* a, fp_int* b);

/* power of 2 operations */
void fp_div_2d(fp_int* a, int b, fp_int* c, fp_int* d);
void fp_mod_2d(fp_int* a, int b, fp_int* c);
int fp_mul_2d(fp_int* a, int b, fp_int* c);
void fp_2expt(fp_int* a, int b);
int fp_mul_2(fp_int* a, fp_int* b);
void fp_div_2(fp_int* a, fp_int* b);
/* c = a / 2 (mod b) - constant time (a < b and positive) */
int fp_div_2_mod_ct(fp_int* a, fp_int* b, fp_int* c);

/* Counts the number of lsbs which are zero before the first zero bit */
int fp_cnt_lsb(fp_int* a);

/* c = a + b */
int fp_add(fp_int* a, fp_int* b, fp_int* c);

/* c = a - b */
int fp_sub(fp_int* a, fp_int* b, fp_int* c);

/* c = a * b */
int fp_mul(fp_int* a, fp_int* b, fp_int* c);

/* b = a*a  */
int fp_sqr(fp_int* a, fp_int* b);

/* a/b => cb + d == a */
int fp_div(fp_int* a, fp_int* b, fp_int* c, fp_int* d);

/* c = a mod b, 0 <= c < b  */
int fp_mod(fp_int* a, fp_int* b, fp_int* c);

/* compare against a single digit */
int fp_cmp_d(fp_int* a, fp_digit b);

/* c = a + b */
int fp_add_d(fp_int* a, fp_digit b, fp_int* c);

/* c = a - b */
int fp_sub_d(fp_int* a, fp_digit b, fp_int* c);

/* c = a * b */
int fp_mul_d(fp_int* a, fp_digit b, fp_int* c);

/* a/b => cb + d == a */
/*int fp_div_d(fp_int *a, fp_digit b, fp_int *c, fp_digit *d);*/

/* c = a mod b, 0 <= c < b  */
/*int fp_mod_d(fp_int *a, fp_digit b, fp_digit *c);*/

/* ---> number theory <--- */
/* d = a + b (mod c) */
/*int fp_addmod(fp_int *a, fp_int *b, fp_int *c, fp_int *d);*/

/* d = a - b (mod c) */
/*int fp_submod(fp_int *a, fp_int *b, fp_int *c, fp_int *d);*/

/* d = a * b (mod c) */
int fp_mulmod(fp_int* a, fp_int* b, fp_int* c, fp_int* d);

/* d = a - b (mod c) */
int fp_submod(fp_int* a, fp_int* b, fp_int* c, fp_int* d);

/* d = a + b (mod c) */
int fp_addmod(fp_int* a, fp_int* b, fp_int* c, fp_int* d);

/* d = a - b (mod c) - constant time (a < c and b < c) */
int fp_submod_ct(fp_int* a, fp_int* b, fp_int* c, fp_int* d);

/* d = a + b (mod c) - constant time (a < c and b < c) */
int fp_addmod_ct(fp_int* a, fp_int* b, fp_int* c, fp_int* d);

/* c = a * a (mod b) */
int fp_sqrmod(fp_int* a, fp_int* b, fp_int* c);

/* c = 1/a (mod b) */
int fp_invmod(fp_int* a, fp_int* b, fp_int* c);
int fp_invmod_mont_ct(fp_int* a, fp_int* b, fp_int* c, fp_digit mp);

/* c = (a, b) */
/*int fp_gcd(fp_int *a, fp_int *b, fp_int *c);*/

/* c = [a, b] */
/*int fp_lcm(fp_int *a, fp_int *b, fp_int *c);*/

/* setups the montgomery reduction */
int fp_montgomery_setup(fp_int* a, fp_digit* rho);

/* computes a = B**n mod b without division or multiplication useful for
 * normalizing numbers in a Montgomery system.
 */
int fp_montgomery_calc_normalization(fp_int* a, fp_int* b);

/* computes x/R == x (mod N) via Montgomery Reduction */
int fp_montgomery_reduce(fp_int* a, fp_int* m, fp_digit mp);
int fp_montgomery_reduce_ex(fp_int* a, fp_int* m, fp_digit mp, int ct);

/* d = a**b (mod c) */
int fp_exptmod(fp_int* G, fp_int* X, fp_int* P, fp_int* Y);
int fp_exptmod_ex(fp_int* G, fp_int* X, int minDigits, fp_int* P, fp_int* Y);
int fp_exptmod_nct(fp_int* G, fp_int* X, fp_int* P, fp_int* Y);

/* last item for total state count only */

/* tfmExptModNbState */

/* maximum instructions to block */
/* tracks total instructions */

/* stop and return FP_WOULDBLOCK */
/* keep blocking */

/* non-blocking version of timing resistant fp_exptmod function */
/* supports cache resistance */

/* WC_RSA_NONBLOCK */

/* primality stuff */

/* perform a Miller-Rabin test of a to the base b and store result in "result" */
/*void fp_prime_miller_rabin (fp_int * a, fp_int * b, int *result);*/

enum FP_PRIME_SIZE = 256;
/* 256 trial divisions + 8 Miller-Rabins, returns FP_YES if probable prime  */
/*int fp_isprime(fp_int *a);*/
/* extended version of fp_isprime, do 't' Miller-Rabins instead of only 8 */
/*int fp_isprime_ex(fp_int *a, int t, int* result);*/

/* Primality generation flags */
/*#define TFM_PRIME_BBS      0x0001 */ /* BBS style prime */
/*#define TFM_PRIME_SAFE     0x0002 */ /* Safe prime (p-1)/2 == prime */
/*#define TFM_PRIME_2MSB_OFF 0x0004 */ /* force 2nd MSB to 0 */
/*#define TFM_PRIME_2MSB_ON  0x0008 */ /* force 2nd MSB to 1 */

/* callback for fp_prime_random, should fill dst with random bytes and return how many read [up to len] */
/*typedef int tfm_prime_callback(unsigned char *dst, int len, void *dat);*/

/*#define fp_prime_random(a, t, size, bbs, cb, dat) fp_prime_random_ex(a, t, ((size) * 8) + 1, (bbs==1)?TFM_PRIME_BBS:0, cb, dat)*/

/*int fp_prime_random_ex(fp_int *a, int t, int size, int flags, tfm_prime_callback cb, void *dat);*/

/* radix conversions */
int fp_count_bits(const(fp_int)* a);
int fp_leading_bit(fp_int* a);

int fp_unsigned_bin_size(const(fp_int)* a);
int fp_read_unsigned_bin(fp_int* a, const(ubyte)* b, int c);
int fp_to_unsigned_bin(fp_int* a, ubyte* b);
int fp_to_unsigned_bin_len(fp_int* a, ubyte* b, int c);
int fp_to_unsigned_bin_at_pos(int x, fp_int* t, ubyte* b);

/*int fp_read_radix(fp_int *a, char *str, int radix);*/
/*int fp_toradix(fp_int *a, char *str, int radix);*/
/*int fp_toradix_n(fp_int * a, char *str, int radix, int maxlen);*/

/* VARIOUS LOW LEVEL STUFFS */
int s_fp_add(fp_int* a, fp_int* b, fp_int* c);
void s_fp_sub(fp_int* a, fp_int* b, fp_int* c);
void fp_reverse(ubyte* s, int len);

int fp_mul_comba(fp_int* a, fp_int* b, fp_int* c);

int fp_mul_comba_small(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba3(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba4(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba6(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba7(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba8(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba9(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba12(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba17(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba20(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba24(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba28(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba32(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba48(fp_int* a, fp_int* b, fp_int* c);
int fp_mul_comba64(fp_int* a, fp_int* b, fp_int* c);
int fp_sqr_comba(fp_int* a, fp_int* b);
int fp_sqr_comba_small(fp_int* a, fp_int* b);
int fp_sqr_comba3(fp_int* a, fp_int* b);
int fp_sqr_comba4(fp_int* a, fp_int* b);
int fp_sqr_comba6(fp_int* a, fp_int* b);
int fp_sqr_comba7(fp_int* a, fp_int* b);
int fp_sqr_comba8(fp_int* a, fp_int* b);
int fp_sqr_comba9(fp_int* a, fp_int* b);
int fp_sqr_comba12(fp_int* a, fp_int* b);
int fp_sqr_comba17(fp_int* a, fp_int* b);
int fp_sqr_comba20(fp_int* a, fp_int* b);
int fp_sqr_comba24(fp_int* a, fp_int* b);
int fp_sqr_comba28(fp_int* a, fp_int* b);
int fp_sqr_comba32(fp_int* a, fp_int* b);
int fp_sqr_comba48(fp_int* a, fp_int* b);
int fp_sqr_comba64(fp_int* a, fp_int* b);

/**
 * Used by wolfSSL
 */

/* Constants */
enum MP_LT = FP_LT; /* less than    */
enum MP_EQ = FP_EQ; /* equal to     */
enum MP_GT = FP_GT; /* greater than */
enum MP_VAL = FP_VAL; /* invalid */
enum MP_MEM = FP_MEM; /* memory error */
enum MP_NOT_INF = FP_NOT_INF; /* point not at infinity */
enum MP_OKAY = FP_OKAY; /* ok result    */
enum MP_NO = FP_NO; /* yes/no result */
enum MP_YES = FP_YES; /* yes/no result */
enum MP_ZPOS = FP_ZPOS;
enum MP_NEG = FP_NEG;
enum MP_MASK = FP_MASK;

/* Prototypes */
alias mp_zero = fp_zero;
alias mp_isone = fp_isone;
alias mp_iseven = fp_iseven;
alias mp_isneg = fp_isneg;
alias mp_isword = fp_isword;

enum MP_RADIX_BIN = 2;
enum MP_RADIX_OCT = 8;
enum MP_RADIX_DEC = 10;
enum MP_RADIX_HEX = 16;
enum MP_RADIX_MAX = 64;

extern (D) auto mp_tobinary(T0, T1)(auto ref T0 M, auto ref T1 S) {
    return mp_toradix(M, S, MP_RADIX_BIN);
}

extern (D) auto mp_tooctal(T0, T1)(auto ref T0 M, auto ref T1 S) {
    return mp_toradix(M, S, MP_RADIX_OCT);
}

extern (D) auto mp_todecimal(T0, T1)(auto ref T0 M, auto ref T1 S) {
    return mp_toradix(M, S, MP_RADIX_DEC);
}

extern (D) auto mp_tohex(T0, T1)(auto ref T0 M, auto ref T1 S) {
    return mp_toradix(M, S, MP_RADIX_HEX);
}

int mp_init(mp_int* a);
int mp_init_copy(fp_int* a, fp_int* b);
void mp_clear(mp_int* a);
void mp_free(mp_int* a);
void mp_forcezero(mp_int* a);
int mp_init_multi(
        mp_int* a,
        mp_int* b,
        mp_int* c,
        mp_int* d,
        mp_int* e,
        mp_int* f);

int mp_add(mp_int* a, mp_int* b, mp_int* c);
int mp_sub(mp_int* a, mp_int* b, mp_int* c);
int mp_add_d(mp_int* a, mp_digit b, mp_int* c);

int mp_mul(mp_int* a, mp_int* b, mp_int* c);
int mp_mul_d(mp_int* a, mp_digit b, mp_int* c);
int mp_mulmod(mp_int* a, mp_int* b, mp_int* c, mp_int* d);
int mp_submod(mp_int* a, mp_int* b, mp_int* c, mp_int* d);
int mp_addmod(mp_int* a, mp_int* b, mp_int* c, mp_int* d);
int mp_submod_ct(mp_int* a, mp_int* b, mp_int* c, mp_int* d);
int mp_addmod_ct(mp_int* a, mp_int* b, mp_int* c, mp_int* d);
int mp_mod(mp_int* a, mp_int* b, mp_int* c);
int mp_invmod(mp_int* a, mp_int* b, mp_int* c);
int mp_invmod_mont_ct(mp_int* a, mp_int* b, mp_int* c, fp_digit mp);
int mp_exptmod(mp_int* g, mp_int* x, mp_int* p, mp_int* y);
int mp_exptmod_ex(mp_int* g, mp_int* x, int minDigits, mp_int* p, mp_int* y);
int mp_exptmod_nct(mp_int* g, mp_int* x, mp_int* p, mp_int* y);
int mp_mul_2d(mp_int* a, int b, mp_int* c);
int mp_2expt(mp_int* a, int b);

int mp_div(mp_int* a, mp_int* b, mp_int* c, mp_int* d);

int mp_cmp(mp_int* a, mp_int* b);
int mp_cmp_d(mp_int* a, mp_digit b);

int mp_unsigned_bin_size(const(mp_int)* a);
int mp_read_unsigned_bin(mp_int* a, const(ubyte)* b, int c);
int mp_to_unsigned_bin_at_pos(int x, mp_int* t, ubyte* b);
int mp_to_unsigned_bin(mp_int* a, ubyte* b);
int mp_to_unsigned_bin_len(mp_int* a, ubyte* b, int c);

int mp_sub_d(fp_int* a, fp_digit b, fp_int* c);
int mp_copy(const(fp_int)* a, fp_int* b);
int mp_isodd(mp_int* a);
int mp_iszero(mp_int* a);
int mp_count_bits(const(mp_int)* a);
int mp_leading_bit(mp_int* a);
int mp_set_int(mp_int* a, c_ulong b);
int mp_is_bit_set(mp_int* a, mp_digit b);
int mp_set_bit(mp_int* a, mp_digit b);
void mp_rshb(mp_int* a, int x);
void mp_rshd(mp_int* a, int x);
int mp_toradix(mp_int* a, char* str, int radix);
int mp_radix_size(mp_int* a, int radix, int* size);

int mp_read_radix(mp_int* a, const(char)* str, int radix);

int mp_set(fp_int* a, fp_digit b);

int mp_sqrmod(mp_int* a, mp_int* b, mp_int* c);
int mp_montgomery_calc_normalization(mp_int* a, mp_int* b);

int mp_prime_is_prime(mp_int* a, int t, int* result);
int mp_prime_is_prime_ex(mp_int* a, int t, int* result, WC_RNG* rng);
/* !NO_DH || !NO_DSA || !NO_RSA || WOLFSSL_KEY_GEN */

/* WOLFSSL_KEY_GEN */
int mp_cond_swap_ct(mp_int* a, mp_int* b, int c, int m);

int mp_cnt_lsb(fp_int* a);
int mp_div_2d(fp_int* a, int b, fp_int* c, fp_int* d);
int mp_mod_d(fp_int* a, fp_digit b, fp_digit* c);
int mp_lshd(mp_int* a, int b);
int mp_abs(mp_int* a, mp_int* b);

word32 CheckRunTimeFastMath();

/* If user uses RSA, DH, DSA, or ECC math lib directly then fast math FP_SIZE
   must match, return 1 if a match otherwise 0 */
extern (D) auto CheckFastMathSettings() {
    return FP_SIZE == CheckRunTimeFastMath();
}

/* WOLF_CRYPT_TFM_H */
