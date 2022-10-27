/* asn_public.h
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

module tagion.network.wolfssl.c.wolfcrypt.asn_public;

import core.stdc.config;
import core.sys.posix.pthread;
import core.sys.posix.sched;
import tagion.network.wolfssl.c.wolfcrypt.dsa;
import tagion.network.wolfssl.c.wolfcrypt.random;
import tagion.network.wolfssl.c.wolfcrypt.types;
import tagion.network.wolfssl.wolfssl_config;

extern (C):
nothrow:
@nogc:

/*!
    \file wolfssl/wolfcrypt/asn_public.h
*/

/*
DESCRIPTION
This library defines the interface APIs for X509 certificates.

*/

/* guard on redeclaration */

struct ecc_key;

struct ed25519_key;

struct curve25519_key;

struct ed448_key;

struct curve448_key;

struct RsaKey;

struct DhKey;

struct falcon_key;

struct dilithium_key;

enum Ecc_Sum
{
    ECC_SECP112R1_OID = 182,
    ECC_SECP112R2_OID = 183,
    ECC_SECP128R1_OID = 204,
    ECC_SECP128R2_OID = 205,
    ECC_SECP160R1_OID = 184,
    ECC_SECP160R2_OID = 206,
    ECC_SECP160K1_OID = 185,
    ECC_BRAINPOOLP160R1_OID = 98,
    ECC_SECP192R1_OID = 520,
    ECC_PRIME192V2_OID = 521,
    ECC_PRIME192V3_OID = 522,
    ECC_SECP192K1_OID = 207,
    ECC_BRAINPOOLP192R1_OID = 100,
    ECC_SECP224R1_OID = 209,
    ECC_SECP224K1_OID = 208,
    ECC_BRAINPOOLP224R1_OID = 102,
    ECC_PRIME239V1_OID = 523,
    ECC_PRIME239V2_OID = 524,
    ECC_PRIME239V3_OID = 525,
    ECC_SECP256R1_OID = 526,
    ECC_SECP256K1_OID = 186,
    ECC_BRAINPOOLP256R1_OID = 104,
    ECC_X25519_OID = 365,
    ECC_ED25519_OID = 256,
    ECC_BRAINPOOLP320R1_OID = 106,
    ECC_X448_OID = 362,
    ECC_ED448_OID = 257,
    ECC_SECP384R1_OID = 210,
    ECC_BRAINPOOLP384R1_OID = 108,
    ECC_BRAINPOOLP512R1_OID = 110,
    ECC_SECP521R1_OID = 211
}

/* Certificate file Type */
enum CertType
{
    CERT_TYPE = 0,
    PRIVATEKEY_TYPE = 1,
    DH_PARAM_TYPE = 2,
    DSA_PARAM_TYPE = 3,
    CRL_TYPE = 4,
    CA_TYPE = 5,
    ECC_PRIVATEKEY_TYPE = 6,
    DSA_PRIVATEKEY_TYPE = 7,
    CERTREQ_TYPE = 8,
    DSA_TYPE = 9,
    ECC_TYPE = 10,
    RSA_TYPE = 11,
    PUBLICKEY_TYPE = 12,
    RSA_PUBLICKEY_TYPE = 13,
    ECC_PUBLICKEY_TYPE = 14,
    TRUSTED_PEER_TYPE = 15,
    EDDSA_PRIVATEKEY_TYPE = 16,
    ED25519_TYPE = 17,
    ED448_TYPE = 18,
    PKCS12_TYPE = 19,
    PKCS8_PRIVATEKEY_TYPE = 20,
    PKCS8_ENC_PRIVATEKEY_TYPE = 21,
    DETECT_CERT_TYPE = 22,
    DH_PRIVATEKEY_TYPE = 23,
    X942_PARAM_TYPE = 24,
    FALCON_LEVEL1_TYPE = 25,
    FALCON_LEVEL5_TYPE = 26,
    DILITHIUM_LEVEL2_TYPE = 27,
    DILITHIUM_LEVEL3_TYPE = 28,
    DILITHIUM_LEVEL5_TYPE = 29,
    DILITHIUM_AES_LEVEL2_TYPE = 30,
    DILITHIUM_AES_LEVEL3_TYPE = 31,
    DILITHIUM_AES_LEVEL5_TYPE = 32
}

/* Signature type, by OID sum */
enum Ctc_SigType
{
    CTC_SHAwDSA = 517,
    CTC_SHA256wDSA = 416,
    CTC_MD2wRSA = 646,
    CTC_MD5wRSA = 648,
    CTC_SHAwRSA = 649,
    CTC_SHAwECDSA = 520,
    CTC_SHA224wRSA = 658,
    CTC_SHA224wECDSA = 523,
    CTC_SHA256wRSA = 655,
    CTC_SHA256wECDSA = 524,
    CTC_SHA384wRSA = 656,
    CTC_SHA384wECDSA = 525,
    CTC_SHA512wRSA = 657,
    CTC_SHA512wECDSA = 526,

    /* https://csrc.nist.gov/projects/computer-security-objects-register/algorithm-registration */
    CTC_SHA3_224wECDSA = 423,
    CTC_SHA3_256wECDSA = 424,
    CTC_SHA3_384wECDSA = 425,
    CTC_SHA3_512wECDSA = 426,
    CTC_SHA3_224wRSA = 427,
    CTC_SHA3_256wRSA = 428,
    CTC_SHA3_384wRSA = 429,
    CTC_SHA3_512wRSA = 430,

    CTC_RSASSAPSS = 654,

    CTC_ED25519 = 256,
    CTC_ED448 = 257,

    CTC_FALCON_LEVEL1 = 268,
    CTC_FALCON_LEVEL5 = 271,

    CTC_DILITHIUM_LEVEL2 = 213,
    CTC_DILITHIUM_LEVEL3 = 216,
    CTC_DILITHIUM_LEVEL5 = 220,
    CTC_DILITHIUM_AES_LEVEL2 = 217,
    CTC_DILITHIUM_AES_LEVEL3 = 221,
    CTC_DILITHIUM_AES_LEVEL5 = 224
}

enum Ctc_Encoding
{
    CTC_UTF8 = 0x0c, /* utf8      */
    CTC_PRINTABLE = 0x13 /* printable */
}

enum WC_CTC_MAX_ALT_SIZE = 16384;

enum Ctc_Misc
{
    CTC_COUNTRY_SIZE = 2,
    CTC_NAME_SIZE = WC_CTC_NAME_SIZE,
    CTC_DATE_SIZE = 32,
    CTC_MAX_ALT_SIZE = WC_CTC_MAX_ALT_SIZE, /* may be huge, default: 16384 */
    CTC_SERIAL_SIZE = 20,
    CTC_GEN_SERIAL_SZ = 16,
    CTC_FILETYPE_ASN1 = 2,
    CTC_FILETYPE_PEM = 1,
    CTC_FILETYPE_DEFAULT = 2

    /* AKID could contains: hash + (Option) AuthCertIssuer,AuthCertSerialNum
     * We support only hash */
    /* SHA256_DIGEST_SIZE */
    /* SHA256_DIGEST_SIZE */

    /* Max number of Certificate Policy */
    /* Arbitrary size that should be enough for at
     * least two distribution points. */
    /* WOLFSSL_CERT_EXT */
}

/* DER buffer */
struct DerBuffer
{
    ubyte* buffer;
    void* heap;
    word32 length;
    int type; /* enum CertType */
    int dynType; /* DYNAMIC_TYPE_* */
}

struct WOLFSSL_ASN1_TIME
{
    ubyte[Ctc_Misc.CTC_DATE_SIZE] data; /* date bytes */
    int length;
    int type;
}

enum
{
    IV_SZ = 32, /* max iv sz */

    /* larger max one line, allows for longer
       encryption password support */

    NAME_SZ = 80, /* max one line */

    PEM_PASS_READ = 0,
    PEM_PASS_WRITE = 1
}

alias wc_pem_password_cb = int function (char* passwd, int sz, int rw, void* userdata);

/* In the past, wc_pem_password_cb was called pem_password_cb, which is the same
 * name as an identical typedef in OpenSSL. We don't want to break existing code
 * that uses the name pem_password_cb, so we define it here as a macro alias for
 * wc_pem_password_cb. In cases where a user needs to use both OpenSSL and
 * wolfSSL headers in the same code, they should define OPENSSL_COEXIST to
 * avoid errors stemming from the typedef being declared twice. */
alias pem_password_cb = int function ();

struct EncryptedInfo
{
    import std.bitmanip : bitfields;

    int function () passwd_cb;
    void* passwd_userdata;

    c_long consumed; /* tracks PEM bytes consumed */

    int cipherType;
    word32 keySz;
    word32 ivSz; /* salt or encrypted IV size */

    char[NAME_SZ] name; /* cipher name, such as "DES-CBC" */
    ubyte[IV_SZ] iv;

    mixin(bitfields!(
        word16, "set", 1,
        uint, "", 7)); /* salt or encrypted IV */

    /* if encryption set */
}

enum WOLFSSL_ASN1_INTEGER_MAX = 20;

struct WOLFSSL_ASN1_INTEGER
{
    import std.bitmanip : bitfields;

    /* size can be increased set at 20 for tag, length then to hold at least 16
     * byte type */
    ubyte[WOLFSSL_ASN1_INTEGER_MAX] intData;
    /* ASN_INTEGER | LENGTH | hex of number */
    ubyte negative; /* negative number flag */

    ubyte* data;
    uint dataMax;

    mixin(bitfields!(
        uint, "isDynamic", 1,
        uint, "", 7)); /* max size of data buffer */
    /* flag for if data pointer dynamic (1 is yes 0 is no) */

    int length;
    int type;
}

/* WOLFSSL_CERT_GEN || WOLFSSL_CERT_EXT */

/* ASN Encoded Name field */

/* actual string value length */
/* id of name */
/* enc of name */
/* name */

/* WOLFSSL_MULTI_ATTRIB */
/* WOLFSSL_CERT_GEN || OPENSSL_EXTRA || OPENSSL_EXTRA_X509_SMALL */

/* WOLFSSL_CERT_GEN */

/* WOLFSSL_CERT_NAME_ALL */

/* !!!! email has to be last !!!! */

/* WOLFSSL_CERT_GEN || OPENSSL_EXTRA || OPENSSL_EXTRA_X509_SMALL*/

/* for user to fill for certificate generation */

/* x509 version  */
/* serial number */
/* serial size */
/* signature algo type */
/* issuer info */
/* validity days */
/* self signed flag */
/* subject info */
/* is this going to be a CA */
/* max depth of valid certification
 * paths that include this cert */
/* internal use only */
/* pre sign total size */
/* public key type of subject */

/* altNames copy */
/* altNames size in bytes */

/* before date copy */
/* size of copy */
/* after date copy */
/* size of copy */

/* Subject Key Identifier */
/* SKID size in bytes */

/* Authority Key
                                        * Identifier */
/* AKID size in bytes */

/* Set to true if akid is a
 * AuthorityKeyIdentifier object.
 * Set to false if akid is just a
 * KeyIdentifier object. */

/* Key Usage */
/* Extended Key Usage */

/* Netscape Certificate Type */

/* Extended Key Usage OIDs */

/* Number of Cert Policy */
/* CRL Distribution points */

/* raw issuer info */
/* raw subject info */

/* encode as PrintableString */

/* user oid and value to go in req extensions */

/* Extensions to go into X.509 certificates */

/* internal DecodedCert allocated from heap */
/* Pointer to buffer of current DecodedCert cache */
/* heap hint */
/* Indicator for when Basic Constaint is set */
/* Indicator for when path length is set */

/* Indicator of criticality of SAN extension */

/* Initialize and Set Certificate defaults:
   version    = 3 (0x2)
   serial     = 0 (Will be randomly generated)
   sigType    = SHA_WITH_RSA
   issuer     = blank
   daysValid  = 500
   selfSigned = 1 (true) use subject as issuer
   subject    = blank
   isCA       = 0 (false)
   keyType    = RSA_KEY (default)
*/

/* Set the KeyUsage.
 * Value is a string separated tokens with ','. Accepted tokens are :
 * digitalSignature,nonRepudiation,contentCommitment,keyCertSign,cRLSign,
 * dataEncipherment,keyAgreement,keyEncipherment,encipherOnly and decipherOnly.
 *
 * nonRepudiation and contentCommitment are for the same usage.
 */

/* Set ExtendedKeyUsage
 * Value is a string separated tokens with ','. Accepted tokens are :
 * any,serverAuth,clientAuth,codeSigning,emailProtection,timeStamping,OCSPSigning
 */

/* Set ExtendedKeyUsage with unique OID
 * oid is expected to be in byte representation
 */

/* WOLFSSL_EKU_OID */

/* WOLFSSL_CERT_EXT */
/* WOLFSSL_CERT_GEN */

int wc_GetDateInfo (
    const(ubyte)* certDate,
    int certDateSz,
    const(ubyte*)* date,
    ubyte* format,
    int* length);

int wc_GetDateAsCalendarTime (
    const(ubyte)* date,
    int length,
    ubyte format,
    tm* timearg);

int wc_PemGetHeaderFooter (
    int type,
    const(char*)* header,
    const(char*)* footer);

int wc_AllocDer (DerBuffer** pDer, word32 length, int type, void* heap);
void wc_FreeDer (DerBuffer** pDer);

int wc_PemToDer (
    const(ubyte)* buff,
    c_long longSz,
    int type,
    DerBuffer** pDer,
    void* heap,
    EncryptedInfo* info,
    int* keyFormat);

int wc_KeyPemToDer (
    const(ubyte)* pem,
    int pemSz,
    ubyte* buff,
    int buffSz,
    const(char)* pass);
int wc_CertPemToDer (
    const(ubyte)* pem,
    int pemSz,
    ubyte* buff,
    int buffSz,
    int type);
/* WOLFSSL_PEM_TO_DER */

int wc_PemPubKeyToDer (const(char)* fileName, ubyte* derBuf, int derSz);
int wc_PemPubKeyToDer_ex (const(char)* fileName, DerBuffer** der);

int wc_PubKeyPemToDer (const(ubyte)* pem, int pemSz, ubyte* buff, int buffSz);
/* WOLFSSL_CERT_EXT || WOLFSSL_PUB_PEM_TO_DER */

/* WOLFSSL_CERT_GEN */

int wc_RsaPublicKeyDecode_ex (
    const(ubyte)* input,
    word32* inOutIdx,
    word32 inSz,
    const(ubyte*)* n,
    word32* nSz,
    const(ubyte*)* e,
    word32* eSz);
/* For FIPS v1/v2 and selftest this is in rsa.h */

int wc_RsaKeyToPublicDer (RsaKey* key, ubyte* output, word32 inLen);

int wc_RsaPublicKeyDerSize (RsaKey* key, int with_header);
int wc_RsaKeyToPublicDer_ex (
    RsaKey* key,
    ubyte* output,
    word32 inLen,
    int with_header);

/* DSA parameter DER helper functions */
int wc_DsaParamsDecode (
    const(ubyte)* input,
    word32* inOutIdx,
    DsaKey* key,
    word32 inSz);
int wc_DsaKeyToParamsDer (DsaKey* key, ubyte* output, word32 inLen);
int wc_DsaKeyToParamsDer_ex (DsaKey* key, ubyte* output, word32* inLen);

/* private key helpers */

/* public key helper */

/* RFC 5958 (Asymmetric Key Packages) */

/* HAVE_ED25519 */

/* HAVE_CURVE25519 */

/* HAVE_ED448 */

/* HAVE_PQC */

/* HAVE_CURVE448 */

/* DER encode signature */
word32 wc_EncodeSignature (
    ubyte* out_,
    const(ubyte)* digest,
    word32 digSz,
    int hashOID);
int wc_GetCTC_HashOID (int type);

int wc_GetPkcs8TraditionalOffset (ubyte* input, word32* inOutIdx, word32 sz);
int wc_CreatePKCS8Key (
    ubyte* out_,
    word32* outSz,
    ubyte* key,
    word32 keySz,
    int algoID,
    const(ubyte)* curveOID,
    word32 oidSz);
int wc_EncryptPKCS8Key (
    ubyte* key,
    word32 keySz,
    ubyte* out_,
    word32* outSz,
    const(char)* password,
    int passwordSz,
    int vPKCS,
    int pbeOid,
    int encAlgId,
    ubyte* salt,
    word32 saltSz,
    int itt,
    WC_RNG* rng,
    void* heap);
int wc_DecryptPKCS8Key (
    ubyte* input,
    word32 sz,
    const(char)* password,
    int passwordSz);
int wc_CreateEncryptedPKCS8Key (
    ubyte* key,
    word32 keySz,
    ubyte* out_,
    word32* outSz,
    const(char)* password,
    int passwordSz,
    int vPKCS,
    int pbeOid,
    int encAlgId,
    ubyte* salt,
    word32 saltSz,
    int itt,
    WC_RNG* rng,
    void* heap);

/* Time */
/* Returns seconds (Epoch/UTC)
 * timePtr: is "time_t", which is typically "long"
 * Example:
    long lTime;
    rc = wc_GetTime(&lTime, (word32)sizeof(lTime));
*/
int wc_GetTime (void* timePtr, word32 timeSize);

alias wc_time_cb = c_long function (time_t* t);
int wc_SetTimeCb (wc_time_cb f);
time_t wc_Time (time_t* t);

/* Identiv Only */
/* Identiv Only */
/* Identiv Only */
/* Identiv Only */

/* flags */

/* WOLFSSL_CERT_PIV */

/* Forward declaration needed, as DecodedCert is defined in asn.h.*/
struct DecodedCert;

void wc_InitDecodedCert (
    DecodedCert* cert,
    const(ubyte)* source,
    word32 inSz,
    void* heap);
void wc_FreeDecodedCert (DecodedCert* cert);
int wc_ParseCert (DecodedCert* cert, int type, int verify, void* cm);

int wc_GetPubKeyDerFromCert (
    DecodedCert* cert,
    ubyte* derKey,
    word32* derKeySz);

/* WOLFSSL_FPKI */

/* extern "C" */

/* WOLF_CRYPT_ASN_PUBLIC_H */
