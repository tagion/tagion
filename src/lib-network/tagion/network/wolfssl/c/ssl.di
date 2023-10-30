/* ssl.h
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

module tagion.network.wolfssl.c.ssl;

import core.stdc.config;
import core.stdc.stdarg;
import core.stdc.stdio;
import core.sys.posix.pthread;
import core.sys.posix.sys.uio;
import tagion.network.wolfssl.c.callbacks;
import tagion.network.wolfssl.c.openssl.compat_types;
import tagion.network.wolfssl.c.wolfcrypt.asn_public;
import tagion.network.wolfssl.c.wolfcrypt.random;
import tagion.network.wolfssl.c.wolfcrypt.settings;
import tagion.network.wolfssl.c.wolfcrypt.types;
import tagion.network.wolfssl.c.wolfcrypt.wc_port;
import tagion.network.wolfssl.c.wolfssl_version;

extern (C):
nothrow:
@nogc:

/*!
    \file ../wolfssl/ssl.h
    \brief Header file containing key wolfSSL API
*/

/* wolfSSL API */

/* for users not using preprocessor flags*/

/* For the types */

/* used internally by wolfSSL while OpenSSL types aren't */

enum WOLFSSL_VERSION = LIBWOLFSSL_VERSION_STRING;

/* wincrypt.h clashes */

/* mode to allow wolfSSL and OpenSSL to exist together */

/*
./configure --enable-opensslcoexist \
    CFLAGS="-I/usr/local/opt/openssl/include -DTEST_OPENSSL_COEXIST" \
    LDFLAGS="-L/usr/local/opt/openssl/lib -lcrypto"
*/

/* We need the old SSL names */

/* LHASH is implemented as a stack */
struct WOLFSSL_STACK;
alias WOLFSSL_LHASH = WOLFSSL_STACK;

extern (D) auto WOLF_LHASH_OF(T)(auto ref T x)
{
    return WOLFSSL_LHASH;
}

extern (D) auto WOLF_STACK_OF(T)(auto ref T x)
{
    return WOLFSSL_STACK;
}

struct WOLFSSL;

struct WOLFSSL_SESSION;
struct WOLFSSL_METHOD;

struct WOLFSSL_CTX;

struct WOLFSSL_X509;
struct WOLFSSL_X509_NAME;
struct WOLFSSL_X509_NAME_ENTRY;
struct WOLFSSL_X509_CHAIN;
struct WC_PKCS12;
alias WOLFSSL_X509_PKCS12 = WC_PKCS12;

struct WOLFSSL_CERT_MANAGER;
struct WOLFSSL_SOCKADDR;
struct WOLFSSL_CRL;

alias WOLFSSL_X509_STORE_CTX_verify_cb = int function (int, WOLFSSL_X509_STORE_CTX*);

struct WOLFSSL_BY_DIR_HASH;
struct WOLFSSL_BY_DIR_entry;
struct WOLFSSL_BY_DIR;

/* redeclare guard */

/* guard on redeclaration */
struct WOLFSSL_RSA; /* guard on redeclaration */

/* guard on redeclaration */
struct WOLFSSL_DSA;

/* guard on redeclaration */
struct WOLFSSL_EC_KEY;
struct WOLFSSL_EC_POINT;
struct WOLFSSL_EC_GROUP;
struct WOLFSSL_EC_BUILTIN_CURVE;
/* WOLFSSL_EC_METHOD is just an alias of WOLFSSL_EC_GROUP for now */
alias WOLFSSL_EC_METHOD = WOLFSSL_EC_GROUP;

/* guard on redeclaration */
struct WOLFSSL_ECDSA_SIG;

struct WOLFSSL_CIPHER;
alias WOLFSSL_X509_CRL = WOLFSSL_CRL;
struct WOLFSSL_X509_VERIFY_PARAM;
struct WOLFSSL_X509_EXTENSION;
struct WOLFSSL_v3_ext_method;
struct WOLFSSL_OBJ_NAME;

struct WOLFSSL_dynlock_value;
/* guard on redeclaration */
struct WOLFSSL_DH; /* guard on redeclaration */

struct WOLFSSL_ASN1_BIT_STRING;

struct WOLFSSL_AUTHORITY_KEYID;
struct WOLFSSL_BASIC_CONSTRAINTS;

struct WOLFSSL_CONF_CTX;

/* OPENSSL_ALL || OPENSSL_EXTRA*/

alias WOLFSSL_ASN1_UTCTIME = WOLFSSL_ASN1_TIME;
alias WOLFSSL_ASN1_GENERALIZEDTIME = WOLFSSL_ASN1_TIME;

struct WOLFSSL_ASN1_STRING
{
    import std.bitmanip : bitfields;

    char[Ctc_Misc.CTC_NAME_SIZE] strData;
    int length;
    int type; /* type of string i.e. CTC_UTF8 */
    int nid;
    char* data;
    c_long flags;

    mixin(bitfields!(
        uint, "isDynamic", 1,
        uint, "", 7));

    /* flag for if data pointer dynamic (1 is yes 0 is no) */
}

enum WOLFSSL_MAX_SNAME = 40;

enum WOLFSSL_ASN1_DYNAMIC = 0x1;
enum WOLFSSL_ASN1_DYNAMIC_DATA = 0x2;

struct WOLFSSL_ASN1_OTHERNAME
{
    WOLFSSL_ASN1_OBJECT* type_id;
    WOLFSSL_ASN1_TYPE* value;
}

struct WOLFSSL_GENERAL_NAME
{
    int type;

    union _Anonymous_0
    {
        char* ptr;
        WOLFSSL_ASN1_OTHERNAME* otherName;
        WOLFSSL_ASN1_STRING* rfc822Name;
        WOLFSSL_ASN1_STRING* dNSName;
        WOLFSSL_ASN1_TYPE* x400Address;
        WOLFSSL_X509_NAME* directoryName;
        WOLFSSL_ASN1_STRING* uniformResourceIdentifier;
        WOLFSSL_ASN1_STRING* iPAddress;
        WOLFSSL_ASN1_OBJECT* registeredID;
        WOLFSSL_ASN1_STRING* ip;
        WOLFSSL_X509_NAME* dirn;
        WOLFSSL_ASN1_STRING* ia5;
        WOLFSSL_ASN1_OBJECT* rid;
        WOLFSSL_ASN1_TYPE* other;
    }

    _Anonymous_0 d; /* dereference */
}

struct WOLFSSL_DIST_POINT_NAME
{
    int type;

    /* name 'name.fullname' needs to remain the same, in some ports the elements
     * of the structure are accessed directly */
    union _Anonymous_1
    {
        WOLFSSL_STACK* fullname;
    }

    _Anonymous_1 name;
}

struct WOLFSSL_DIST_POINT
{
    /* name 'distpoint' needs to remain the same, in some ports the elements of
     * the structure are accessed directly */
    WOLFSSL_DIST_POINT_NAME* distpoint;
}

struct WOLFSSL_ACCESS_DESCRIPTION
{
    WOLFSSL_ASN1_OBJECT* method;
    WOLFSSL_GENERAL_NAME* location;
}

struct WOLFSSL_X509V3_CTX
{
    WOLFSSL_X509* x509;
}

struct WOLFSSL_ASN1_OBJECT
{
    void* heap;
    const(ubyte)* obj;
    /* sName is short name i.e sha256 rather than oid (null terminated) */
    char[WOLFSSL_MAX_SNAME] sName;
    int type; /* oid */
    int grp; /* type of OID, i.e. oidCertPolicyType */
    int nid;
    uint objSz;

    ubyte dynamic; /* Use WOLFSSL_ASN1_DYNAMIC and WOLFSSL_ASN1_DYNAMIC_DATA
     * to determine what needs to be freed. */

    /* dereferenced */

    /* points to ia5_internal */

    /* added for Apache httpd */

    /* points to iPAddress_internal */
    struct _D
    {
        WOLFSSL_ASN1_STRING* dNSName;
        WOLFSSL_ASN1_STRING ia5_internal;
        WOLFSSL_ASN1_STRING* ia5;
        WOLFSSL_ASN1_STRING* iPAddress;
    }

    _D d;
}

/* wrap ASN1 types */
struct WOLFSSL_ASN1_TYPE
{
    int type;

    union _Anonymous_2
    {
        char* ptr;
        WOLFSSL_ASN1_STRING* asn1_string;
        WOLFSSL_ASN1_OBJECT* object;
        WOLFSSL_ASN1_INTEGER* integer;
        WOLFSSL_ASN1_BIT_STRING* bit_string;
        WOLFSSL_ASN1_STRING* octet_string;
        WOLFSSL_ASN1_STRING* printablestring;
        WOLFSSL_ASN1_STRING* ia5string;
        WOLFSSL_ASN1_TIME* utctime;
        WOLFSSL_ASN1_TIME* generalizedtime;
        WOLFSSL_ASN1_STRING* utf8string;
        WOLFSSL_ASN1_STRING* set;
        WOLFSSL_ASN1_STRING* sequence;
    }

    _Anonymous_2 value;
}

struct WOLFSSL_X509_ATTRIBUTE
{
    WOLFSSL_ASN1_OBJECT* object;
    WOLFSSL_ASN1_TYPE* value;
    WOLFSSL_STACK* set;
}

struct WOLFSSL_EVP_PKEY
{
    import std.bitmanip : bitfields;

    void* heap;
    int type; /* openssh dereference */
    int save_type; /* openssh dereference */
    int pkey_sz;
    int references; /*number of times free should be called for complete free*/

    wolfSSL_Mutex refMutex; /* ref count mutex */

    /* der format of key */
    union _Anonymous_3
    {
        char* ptr;
    }

    _Anonymous_3 pkey;

    /* OPENSSL_EXTRA || OPENSSL_EXTRA_X509_SMALL */

    word16 pkcs8HeaderSz;

    mixin(bitfields!(
        ubyte, "ownDh", 1,
        ubyte, "ownEcc", 1,
        ubyte, "ownDsa", 1,
        ubyte, "ownRsa", 1,
        uint, "", 4));

    /* option bits */
    /* if struct owns DH  and should free it */
    /* if struct owns ECC and should free it */
    /* if struct owns DSA and should free it */
    /* if struct owns RSA and should free it */
}

struct WOLFSSL_X509_PKEY
{
    WOLFSSL_EVP_PKEY* dec_pkey; /* dereferenced by Apache */
    void* heap;
}

struct WOLFSSL_X509_INFO
{
    WOLFSSL_X509* x509;
    WOLFSSL_X509_CRL* crl;
    WOLFSSL_X509_PKEY* x_pkey; /* dereferenced by Apache */
    EncryptedInfo enc_cipher;
    int enc_len;
    char* enc_data;
    int num;
}

// DSTEP: enum WOLFSSL_EVP_PKEY_DEFAULT = EVP_PKEY_RSA; /* default key type */

struct WOLFSSL_X509_ALGOR
{
    WOLFSSL_ASN1_OBJECT* algorithm;
    WOLFSSL_ASN1_TYPE* parameter;
}

struct WOLFSSL_X509_PUBKEY
{
    WOLFSSL_X509_ALGOR* algor;
    WOLFSSL_EVP_PKEY* pkey;
    int pubKeyOID;
}

enum BIO_TYPE
{
    WOLFSSL_BIO_UNDEF = 0,
    WOLFSSL_BIO_BUFFER = 1,
    WOLFSSL_BIO_SOCKET = 2,
    WOLFSSL_BIO_SSL = 3,
    WOLFSSL_BIO_MEMORY = 4,
    WOLFSSL_BIO_BIO = 5,
    WOLFSSL_BIO_FILE = 6,
    WOLFSSL_BIO_BASE64 = 7,
    WOLFSSL_BIO_MD = 8
}

enum BIO_FLAGS
{
    WOLFSSL_BIO_FLAG_BASE64_NO_NL = 0x01,
    WOLFSSL_BIO_FLAG_READ = 0x02,
    WOLFSSL_BIO_FLAG_WRITE = 0x04,
    WOLFSSL_BIO_FLAG_IO_SPECIAL = 0x08,
    WOLFSSL_BIO_FLAG_RETRY = 0x10
}

enum BIO_CB_OPS
{
    WOLFSSL_BIO_CB_FREE = 0x01,
    WOLFSSL_BIO_CB_READ = 0x02,
    WOLFSSL_BIO_CB_WRITE = 0x03,
    WOLFSSL_BIO_CB_PUTS = 0x04,
    WOLFSSL_BIO_CB_GETS = 0x05,
    WOLFSSL_BIO_CB_CTRL = 0x06,
    WOLFSSL_BIO_CB_RETURN = 0x80
}

struct WOLFSSL_BUF_MEM
{
    char* data; /* dereferenced */
    size_t length; /* current length */
    size_t max; /* maximum length */
}

/* custom method with user set callbacks */
alias wolfSSL_BIO_meth_write_cb = int function (WOLFSSL_BIO*, const(char)*, int);
alias wolfSSL_BIO_meth_read_cb = int function (WOLFSSL_BIO*, char*, int);
alias wolfSSL_BIO_meth_puts_cb = int function (WOLFSSL_BIO*, const(char)*);
alias wolfSSL_BIO_meth_gets_cb = int function (WOLFSSL_BIO*, char*, int);
alias wolfSSL_BIO_meth_ctrl_get_cb = c_long function (WOLFSSL_BIO*, int, c_long, void*);
alias wolfSSL_BIO_meth_create_cb = int function (WOLFSSL_BIO*);
alias wolfSSL_BIO_meth_destroy_cb = int function (WOLFSSL_BIO*);

alias wolfSSL_BIO_info_cb = int function (WOLFSSL_BIO*, int, int);
alias wolfssl_BIO_meth_ctrl_info_cb = c_long function (WOLFSSL_BIO*, int, int function ());

/* wolfSSL BIO_METHOD type */

enum MAX_BIO_METHOD_NAME = 256;

struct WOLFSSL_BIO_METHOD
{
    ubyte type; /* method type */
    char[MAX_BIO_METHOD_NAME] name;
    wolfSSL_BIO_meth_write_cb writeCb;
    wolfSSL_BIO_meth_read_cb readCb;
    wolfSSL_BIO_meth_puts_cb putsCb;
    wolfSSL_BIO_meth_gets_cb getsCb;
    wolfSSL_BIO_meth_ctrl_get_cb ctrlCb;
    wolfSSL_BIO_meth_create_cb createCb;
    wolfSSL_BIO_meth_destroy_cb freeCb;
    wolfssl_BIO_meth_ctrl_info_cb ctrlInfoCb;
}

/* wolfSSL BIO type */
alias wolf_bio_info_cb = c_long function (
    WOLFSSL_BIO* bio,
    int event,
    const(char)* parg,
    int iarg,
    c_long larg,
    c_long return_value);

struct WOLFSSL_BIO
{
    import std.bitmanip : bitfields;

    WOLFSSL_BUF_MEM* mem_buf;
    WOLFSSL_BIO_METHOD* method;
    WOLFSSL_BIO* prev; /* previous in chain */
    WOLFSSL_BIO* next; /* next in chain */
    WOLFSSL_BIO* pair; /* BIO paired with */
    void* heap; /* user heap hint */
    void* ptr; /* WOLFSSL, file descriptor, MD, or mem buf */
    void* usrCtx; /* user set pointer */
    char* ip; /* IP address for wolfIO_TcpConnect */
    word16 port; /* Port for wolfIO_TcpConnect */
    char* infoArg; /* BIO callback argument */
    wolf_bio_info_cb infoCb; /* BIO callback */
    int wrSz; /* write buffer size (mem) */
    int wrIdx; /* current index for write buffer */
    int rdIdx; /* current read index */
    int readRq; /* read request */
    int num; /* socket num or length */
    int eof; /* eof flag */
    int flags;
    ubyte type;

    mixin(bitfields!(
        ubyte, "init", 1,
        ubyte, "shutdown", 1,
        uint, "", 6)); /* method type */
    /* bio has been initialized */
    /* close flag */

    /* ref count mutex */

    /* reference count */
}

struct WOLFSSL_COMP_METHOD
{
    int type; /* stunnel dereference */
}

struct WOLFSSL_COMP
{
    int id;
    const(char)* name;
    WOLFSSL_COMP_METHOD* method;
}

enum WOLFSSL_X509_L_FILE_LOAD = 0x1;
enum WOLFSSL_X509_L_ADD_DIR = 0x2;
enum WOLFSSL_X509_L_ADD_STORE = 0x3;
enum WOLFSSL_X509_L_LOAD_STORE = 0x4;

struct WOLFSSL_X509_LOOKUP_METHOD
{
    int type;
}

struct WOLFSSL_X509_LOOKUP
{
    WOLFSSL_X509_STORE* store;
    int type;
    WOLFSSL_BY_DIR* dirs;
}

struct WOLFSSL_X509_STORE
{
    int cache; /* stunnel dereference */
    WOLFSSL_CERT_MANAGER* cm;
    WOLFSSL_X509_LOOKUP lookup;

    /* certificate validation parameter */

    /* object stack cache */

    /* points to cm->crl */

    wolfSSL_Mutex refMutex; /* reference count mutex */

    int refCount; /* reference count */
}

enum WOLFSSL_ALWAYS_CHECK_SUBJECT = 0x1;
enum WOLFSSL_NO_WILDCARDS = 0x2;
enum WOLFSSL_NO_PARTIAL_WILDCARDS = 0x4;

/* max ip size IPv4 mapped IPv6 */

/* OPENSSL_EXTRA || WOLFSSL_WPAS_SMALL */

struct WOLFSSL_ALERT
{
    int code;
    int level;
}

struct WOLFSSL_ALERT_HISTORY
{
    WOLFSSL_ALERT last_rx;
    WOLFSSL_ALERT last_tx;
}

struct WOLFSSL_X509_REVOKED
{
    WOLFSSL_ASN1_INTEGER* serialNumber; /* stunnel dereference */
}

enum WOLFSSL_X509_LOOKUP_TYPE
{
    WOLFSSL_X509_LU_NONE = 0,
    WOLFSSL_X509_LU_X509 = 1,
    WOLFSSL_X509_LU_CRL = 2
}

struct WOLFSSL_X509_OBJECT
{
    WOLFSSL_X509_LOOKUP_TYPE type;

    /* stunnel dereference */
    union _Anonymous_4
    {
        char* ptr;
        WOLFSSL_X509* x509;
        WOLFSSL_X509_CRL* crl;
    }

    _Anonymous_4 data;
}

alias WOLFSSL_ASN1_BOOLEAN = int;

struct WOLFSSL_BUFFER_INFO
{
    ubyte* buffer;
    uint length;
}

struct WOLFSSL_X509_STORE_CTX
{
    WOLFSSL_X509_STORE* store; /* Store full of a CA cert chain */
    WOLFSSL_X509* current_cert; /* current X509 (OPENSSL_EXTRA) */

    /* asio dereference */

    WOLFSSL_X509_CHAIN* sesChain; /* pointer to WOLFSSL_SESSION peer chain */
    WOLFSSL_STACK* chain;

    /* certificate validation parameter */

    char* domain; /* subject CN domain name */

    /* external data */

    /* used in X509_STORE_CTX_*_depth */

    void* userCtx; /* user ctx */
    int error; /* current error */
    int error_depth; /* index of cert depth for this error */
    int discardSessionCerts; /* so verify callback can flag for discard */
    int totalCerts; /* number of peer cert buffers */
    WOLFSSL_BUFFER_INFO* certs; /* peer certs */
    WOLFSSL_X509_STORE_CTX_verify_cb verify_cb; /* verify callback */
}

alias WOLFSSL_STRING = char*;

struct WOLFSSL_RAND_METHOD
{
    /* seed = Data to mix into the random generator.
     * len = Number of bytes to mix from seed. */
    int function (const(void)* seed, int len) seed;
    /* buf = Buffer to store random bytes in.
    * len = Number of bytes to store in buf. */
    int function (ubyte* buf, int len) bytes;
    void function () cleanup;
    /* add = Data to mix into the random generator.
     * len = Number of bytes to mix from add.
     * entropy = Estimate of randomness contained in seed.
     *           Should be between 0 and len. */
    int function (const(void)* add, int len, double entropy) add;
    /* buf = Buffer to store pseudorandom bytes in.
     * len = Number of bytes to store in buf. */
    int function (ubyte* buf, int len) pseudorand;
    int function () status;
}

/* Valid Alert types from page 16/17
 * Add alert string to the function wolfSSL_alert_type_string_long in src/ssl.c
 */
enum AlertDescription
{
    close_notify = 0,
    unexpected_message = 10,
    bad_record_mac = 20,
    record_overflow = 22,
    decompression_failure = 30,
    handshake_failure = 40,
    no_certificate = 41,
    bad_certificate = 42,
    unsupported_certificate = 43,
    certificate_revoked = 44,
    certificate_expired = 45,
    certificate_unknown = 46,
    illegal_parameter = 47,
    unknown_ca = 48,
    access_denied = 49,
    decode_error = 50,
    decrypt_error = 51,

    /* catch name conflict for enum protocol with MYSQL build */

    protocol_version = 70,

    insufficient_security = 71,
    internal_error = 80,
    inappropriate_fallback = 86,
    user_canceled = 90,
    no_renegotiation = 100,
    missing_extension = 109,
    unsupported_extension = 110, /**< RFC 5246, section 7.2.2 */
    unrecognized_name = 112, /**< RFC 6066, section 3 */
    bad_certificate_status_response = 113, /**< RFC 6066, section 8 */
    unknown_psk_identity = 115, /**< RFC 4279, section 2 */
    certificate_required = 116, /**< RFC 8446, section 8.2 */
    no_application_protocol = 120
}

enum AlertLevel
{
    alert_none = 0, /* Used to indicate no alert level is set */
    alert_warning = 1,
    alert_fatal = 2
}

enum SNICbReturn
{
    warning_return = cast(int)AlertLevel.alert_warning,
    fatal_return = cast(int)AlertLevel.alert_fatal,
    noack_return = 3
}

/* WS_RETURN_CODE macro
 * Some OpenSSL APIs specify "0" as the return value when an error occurs.
 * However, some corresponding wolfSSL APIs return negative values. Such
 * functions should use this macro to fill this gap. Users who want them
 * to return the same return value as OpenSSL can define
 * WOLFSSL_ERR_CODE_OPENSSL.
 * Give item1 a variable that contains the potentially negative
 * wolfSSL-defined return value or the return value itself, and
 * give item2 the openSSL-defined return value.
 * Note that this macro replaces only negative return values with the
 * specified value.
 * Since wolfSSL 4.7.0, the following functions use this macro:
 * - wolfSSL_CTX_load_verify_locations
 * - wolfSSL_X509_LOOKUP_load_file
 * - wolfSSL_EVP_PKEY_cmp
 */

extern (D) auto WS_RETURN_CODE(T0, T1)(auto ref T0 item1, auto ref T1 item2)
{
    return item1;
}

/* Maximum master key length (SECRET_LEN) */
enum WOLFSSL_MAX_MASTER_KEY_LENGTH = 48;
/* Maximum number of groups that can be set */

enum WOLFSSL_MAX_GROUP_COUNT = 10;

enum WOLFSSL_MODE_AUTO_RETRY_ATTEMPTS = 10;

alias wolfSSL_method_func = WOLFSSL_METHOD* function (void* heap);

/* CTX Method Constructor Functions */

@trusted WOLFSSL_METHOD* wolfTLS_client_method_ex (void* heap);
@trusted WOLFSSL_METHOD* wolfTLS_client_method ();

@trusted WOLFSSL_METHOD* wolfTLS_server_method_ex (void* heap);
@trusted WOLFSSL_METHOD* wolfTLS_server_method ();

WOLFSSL_METHOD* wolfSSLv23_method_ex (void* heap);
WOLFSSL_METHOD* wolfSSLv23_method ();

WOLFSSL_METHOD* wolfSSLv23_client_method_ex (void* heap);
WOLFSSL_METHOD* wolfSSLv23_client_method ();

WOLFSSL_METHOD* wolfSSLv23_server_method_ex (void* heap);
WOLFSSL_METHOD* wolfSSLv23_server_method ();

/* OPENSSL_EXTRA */

/* WOLFSSL_ALLOW_SSLV3 */

/* WOLFSSL_ALLOW_TLSV10 */

WOLFSSL_METHOD* wolfTLSv1_1_method_ex (void* heap);
WOLFSSL_METHOD* wolfTLSv1_1_method ();

WOLFSSL_METHOD* wolfTLSv1_1_client_method_ex (void* heap);
WOLFSSL_METHOD* wolfTLSv1_1_client_method ();

WOLFSSL_METHOD* wolfTLSv1_1_server_method_ex (void* heap);
WOLFSSL_METHOD* wolfTLSv1_1_server_method ();

/* NO_OLD_TLS */

WOLFSSL_METHOD* wolfTLSv1_2_method_ex (void* heap);
WOLFSSL_METHOD* wolfTLSv1_2_method ();

WOLFSSL_METHOD* wolfTLSv1_2_client_method_ex (void* heap);
WOLFSSL_METHOD* wolfTLSv1_2_client_method ();

WOLFSSL_METHOD* wolfTLSv1_2_server_method_ex (void* heap);
WOLFSSL_METHOD* wolfTLSv1_2_server_method ();

/* !WOLFSSL_NO_TLS12 */

/* WOLFSSL_TLS13 */

/* !NO_OLD_TLS */

/* !WOLFSSL_NO_TLS12 */

/* WOLFSSL_DTLS13 */

/* WOLFSSL_DTLS */

/* WOLFSSL_DTLS_EXPORT_TYPES */

/* WOLFSSL_DTLS */
/* WOLFSSL_SESSION_EXPORT */

int wolfSSL_CTX_use_certificate_file (
    WOLFSSL_CTX* ctx,
    const(char)* file,
    int format);
int wolfSSL_CTX_use_PrivateKey_file (
    WOLFSSL_CTX* ctx,
    const(char)* file,
    int format);

enum WOLFSSL_LOAD_FLAG_NONE = 0x00000000;
enum WOLFSSL_LOAD_FLAG_IGNORE_ERR = 0x00000001;
enum WOLFSSL_LOAD_FLAG_DATE_ERR_OKAY = 0x00000002;
enum WOLFSSL_LOAD_FLAG_PEM_CA_ONLY = 0x00000004;

enum WOLFSSL_LOAD_VERIFY_DEFAULT_FLAGS = WOLFSSL_LOAD_FLAG_NONE;

c_long wolfSSL_get_verify_depth (WOLFSSL* ssl);
c_long wolfSSL_CTX_get_verify_depth (WOLFSSL_CTX* ctx);
void wolfSSL_CTX_set_verify_depth (WOLFSSL_CTX* ctx, int depth);
/* !NO_CERTS */

enum WOLFSSL_CIPHER_SUITE_FLAG_NONE = 0x0;
enum WOLFSSL_CIPHER_SUITE_FLAG_NAMEALIAS = 0x1;

int wolfSSL_CTX_load_verify_locations_ex (
    WOLFSSL_CTX* ctx,
    const(char)* file,
    const(char)* path,
    word32 flags);
int wolfSSL_CTX_load_verify_locations (
    WOLFSSL_CTX* ctx,
    const(char)* file,
    const(char)* path);

int wolfSSL_CTX_use_certificate_chain_file (
    WOLFSSL_CTX* ctx,
    const(char)* file);
int wolfSSL_CTX_use_certificate_chain_file_format (
    WOLFSSL_CTX* ctx,
    const(char)* file,
    int format);
int wolfSSL_CTX_use_RSAPrivateKey_file (
    WOLFSSL_CTX* ctx,
    const(char)* file,
    int format);

int wolfSSL_use_certificate_file (WOLFSSL* ssl, const(char)* file, int format);
int wolfSSL_use_PrivateKey_file (WOLFSSL* ssl, const(char)* file, int format);
int wolfSSL_use_certificate_chain_file (WOLFSSL* ssl, const(char)* file);
int wolfSSL_use_certificate_chain_file_format (
    WOLFSSL* ssl,
    const(char)* file,
    int format);
int wolfSSL_use_RSAPrivateKey_file (
    WOLFSSL* ssl,
    const(char)* file,
    int format);

/* !NO_FILESYSTEM && !NO_CERTS */

@trusted WOLFSSL_CTX* wolfSSL_CTX_new_ex (WOLFSSL_METHOD* method, void* heap);
@trusted WOLFSSL_CTX* wolfSSL_CTX_new (WOLFSSL_METHOD* method);
int wolfSSL_CTX_up_ref (WOLFSSL_CTX* ctx);

@trusted WOLFSSL* wolfSSL_new (WOLFSSL_CTX* ctx);
WOLFSSL_CTX* wolfSSL_get_SSL_CTX (WOLFSSL* ssl);
WOLFSSL_X509_VERIFY_PARAM* wolfSSL_CTX_get0_param (WOLFSSL_CTX* ctx);
WOLFSSL_X509_VERIFY_PARAM* wolfSSL_get0_param (WOLFSSL* ssl);
int wolfSSL_CTX_set1_param (WOLFSSL_CTX* ctx, WOLFSSL_X509_VERIFY_PARAM* vpm);
int wolfSSL_is_server (WOLFSSL* ssl);
@trusted WOLFSSL* wolfSSL_write_dup (WOLFSSL* ssl);
@trusted int wolfSSL_set_fd (WOLFSSL* ssl, int fd);

int wolfSSL_set_write_fd (WOLFSSL* ssl, int fd);
int wolfSSL_set_read_fd (WOLFSSL* ssl, int fd);
char* wolfSSL_get_cipher_list (int priority);
char* wolfSSL_get_cipher_list_ex (WOLFSSL* ssl, int priority);
int wolfSSL_get_ciphers (char* buf, int len);
int wolfSSL_get_ciphers_iana (char* buf, int len);
const(char)* wolfSSL_get_cipher_name (WOLFSSL* ssl);
const(char)* wolfSSL_get_cipher_name_from_suite (
    ubyte cipherSuite0,
    ubyte cipherSuite);
const(char)* wolfSSL_get_cipher_name_iana_from_suite (
    ubyte cipherSuite0,
    ubyte cipherSuite);
int wolfSSL_get_cipher_suite_from_name (
    const(char)* name,
    ubyte* cipherSuite0,
    ubyte* cipherSuite,
    int* flags);
const(char)* wolfSSL_get_shared_ciphers (WOLFSSL* ssl, char* buf, int len);
const(char)* wolfSSL_get_curve_name (WOLFSSL* ssl);
int wolfSSL_get_fd (const(WOLFSSL)* ssl);
/* please see note at top of README if you get an error from connect */
@trusted int wolfSSL_connect (WOLFSSL* ssl);
@trusted int wolfSSL_write (WOLFSSL* ssl, const(void)* data, int sz);
@trusted int wolfSSL_read (WOLFSSL* ssl, void* data, int sz);
int wolfSSL_peek (WOLFSSL* ssl, void* data, int sz);
@trusted int wolfSSL_accept (WOLFSSL* ssl);
int wolfSSL_CTX_mutual_auth (WOLFSSL_CTX* ctx, int req);
int wolfSSL_mutual_auth (WOLFSSL* ssl, int req);

/* OPENSSL_EXTRA */
/* WOLFSSL_EARLY_DATA */
/* WOLFSSL_TLS13 */
@trusted void wolfSSL_CTX_free (WOLFSSL_CTX* ctx);
@trusted void wolfSSL_free (WOLFSSL* ssl);
@trusted int wolfSSL_shutdown (WOLFSSL* ssl);
int wolfSSL_send (WOLFSSL* ssl, const(void)* data, int sz, int flags);
int wolfSSL_recv (WOLFSSL* ssl, void* data, int sz, int flags);

void wolfSSL_CTX_set_quiet_shutdown (WOLFSSL_CTX* ctx, int mode);
void wolfSSL_set_quiet_shutdown (WOLFSSL* ssl, int mode);

@trusted int wolfSSL_get_error (const(WOLFSSL)* ssl, int ret);
int wolfSSL_get_alert_history (WOLFSSL* ssl, WOLFSSL_ALERT_HISTORY* h);

int wolfSSL_set_session (WOLFSSL* ssl, WOLFSSL_SESSION* session);
c_long wolfSSL_SSL_SESSION_set_timeout (WOLFSSL_SESSION* ses, c_long t);
WOLFSSL_SESSION* wolfSSL_get_session (WOLFSSL* ssl);
void wolfSSL_flush_sessions (WOLFSSL_CTX* ctx, c_long tm);
int wolfSSL_SetServerID (WOLFSSL* ssl, const(ubyte)* id, int len, int newSession);

/* OPENSSL_ALL || WOLFSSL_ASIO */

/* SESSION_INDEX */

/* SESSION_INDEX && SESSION_CERTS */

alias VerifyCallback = int function (int, WOLFSSL_X509_STORE_CTX*);
alias CallbackInfoState = void function (const(WOLFSSL)* ssl, int, int);

/* class index for wolfSSL_CRYPTO_get_ex_new_index */
enum WOLF_CRYPTO_EX_INDEX_SSL = 0;
enum WOLF_CRYPTO_EX_INDEX_SSL_CTX = 1;
enum WOLF_CRYPTO_EX_INDEX_SSL_SESSION = 2;
enum WOLF_CRYPTO_EX_INDEX_X509 = 3;
enum WOLF_CRYPTO_EX_INDEX_X509_STORE = 4;
enum WOLF_CRYPTO_EX_INDEX_X509_STORE_CTX = 5;
enum WOLF_CRYPTO_EX_INDEX_DH = 6;
enum WOLF_CRYPTO_EX_INDEX_DSA = 7;
enum WOLF_CRYPTO_EX_INDEX_EC_KEY = 8;
enum WOLF_CRYPTO_EX_INDEX_RSA = 9;
enum WOLF_CRYPTO_EX_INDEX_ENGINE = 10;
enum WOLF_CRYPTO_EX_INDEX_UI = 11;
enum WOLF_CRYPTO_EX_INDEX_BIO = 12;
enum WOLF_CRYPTO_EX_INDEX_APP = 13;
enum WOLF_CRYPTO_EX_INDEX_UI_METHOD = 14;
enum WOLF_CRYPTO_EX_INDEX_DRBG = 15;
enum WOLF_CRYPTO_EX_INDEX__COUNT = 16;

/* Helper macro to log that input arguments should not be used */

void wolfSSL_CTX_set_verify (
    WOLFSSL_CTX* ctx,
    int mode,
    VerifyCallback verify_callback);

@trusted void wolfSSL_set_verify (WOLFSSL* ssl, int mode, VerifyCallback verify_callback);
@trusted void wolfSSL_set_verify_result (WOLFSSL* ssl, c_long v);

void wolfSSL_SetCertCbCtx (WOLFSSL* ssl, void* ctx);
void wolfSSL_CTX_SetCertCbCtx (WOLFSSL_CTX* ctx, void* userCtx);

@trusted int wolfSSL_pending (WOLFSSL* ssl);
int wolfSSL_has_pending (const(WOLFSSL)* ssl);

void wolfSSL_load_error_strings ();
int wolfSSL_library_init ();
c_long wolfSSL_CTX_set_session_cache_mode (WOLFSSL_CTX* ctx, c_long mode);

/* HAVE_SECRET_CALLBACK */

/* session cache persistence */
int wolfSSL_save_session_cache (const(char)* fname);
int wolfSSL_restore_session_cache (const(char)* fname);
int wolfSSL_memsave_session_cache (void* mem, int sz);
int wolfSSL_memrestore_session_cache (const(void)* mem, int sz);
int wolfSSL_get_session_cache_memsize ();

/* certificate cache persistence, uses ctx since certs are per ctx */
int wolfSSL_CTX_save_cert_cache (WOLFSSL_CTX* ctx, const(char)* fname);
int wolfSSL_CTX_restore_cert_cache (WOLFSSL_CTX* ctx, const(char)* fname);
int wolfSSL_CTX_memsave_cert_cache (WOLFSSL_CTX* ctx, void* mem, int sz, int* used);
int wolfSSL_CTX_memrestore_cert_cache (WOLFSSL_CTX* ctx, const(void)* mem, int sz);
int wolfSSL_CTX_get_cert_cache_memsize (WOLFSSL_CTX* ctx);

/* only supports full name from cipher_name[] delimited by : */
int wolfSSL_CTX_set_cipher_list (WOLFSSL_CTX* ctx, const(char)* list);
int wolfSSL_set_cipher_list (WOLFSSL* ssl, const(char)* list);

/* Keying Material Exporter for TLS */

/* HAVE_KEYING_MATERIAL */

/* WOLFSSL_WOLFSENTRY_HOOKS */

/* Nonblocking DTLS helper functions */
void wolfSSL_dtls_set_using_nonblock (WOLFSSL* ssl, int nonblock);
int wolfSSL_dtls_get_using_nonblock (WOLFSSL* ssl);
alias wolfSSL_set_using_nonblock = wolfSSL_dtls_set_using_nonblock;
alias wolfSSL_get_using_nonblock = wolfSSL_dtls_get_using_nonblock;
/* The old names are deprecated. */
int wolfSSL_dtls_get_current_timeout (WOLFSSL* ssl);
int wolfSSL_dtls13_use_quick_timeout (WOLFSSL* ssl);
void wolfSSL_dtls13_set_send_more_acks (WOLFSSL* ssl, int value);
int wolfSSL_DTLSv1_get_timeout (WOLFSSL* ssl, WOLFSSL_TIMEVAL* timeleft);
void wolfSSL_DTLSv1_set_initial_timeout_duration (
    WOLFSSL* ssl,
    word32 duration_ms);
int wolfSSL_DTLSv1_handle_timeout (WOLFSSL* ssl);

int wolfSSL_dtls_set_timeout_init (WOLFSSL* ssl, int timeout);
int wolfSSL_dtls_set_timeout_max (WOLFSSL* ssl, int timeout);
int wolfSSL_dtls_got_timeout (WOLFSSL* ssl);
int wolfSSL_dtls_retransmit (WOLFSSL* ssl);
int wolfSSL_dtls (WOLFSSL* ssl);

void* wolfSSL_dtls_create_peer (int port, char* ip);
int wolfSSL_dtls_free_peer (void* addr);

int wolfSSL_dtls_set_peer (WOLFSSL* ssl, void* peer, uint peerSz);
int wolfSSL_dtls_get_peer (WOLFSSL* ssl, void* peer, uint* peerSz);

int wolfSSL_CTX_dtls_set_sctp (WOLFSSL_CTX* ctx);
int wolfSSL_dtls_set_sctp (WOLFSSL* ssl);
int wolfSSL_CTX_dtls_set_mtu (WOLFSSL_CTX* ctx, ushort);
int wolfSSL_dtls_set_mtu (WOLFSSL* ssl, ushort);

/* SRTP Profile ID's from RFC 5764 and RFC 7714 */
/* For WebRTC support for profile SRTP_AES128_CM_SHA1_80 is required per
 * draft-ietf-rtcweb-security-arch) */

/* not supported */
/* not supported */

/* Compatibility API's for SRTP */

/* Non standard API for getting the SRTP session keys using KDF */

/* WOLFSSL_SRTP */

int wolfSSL_dtls_get_drop_stats (WOLFSSL* ssl, uint*, uint*);
int wolfSSL_CTX_mcast_set_member_id (WOLFSSL_CTX* ctx, ushort id);
int wolfSSL_set_secret (
    WOLFSSL* ssl,
    ushort epoch,
    const(ubyte)* preMasterSecret,
    uint preMasterSz,
    const(ubyte)* clientRandom,
    const(ubyte)* serverRandom,
    const(ubyte)* suite);
int wolfSSL_mcast_read (WOLFSSL* ssl, ushort* id, void* data, int sz);
int wolfSSL_mcast_peer_add (WOLFSSL* ssl, ushort peerId, int sub);
int wolfSSL_mcast_peer_known (WOLFSSL* ssl, ushort peerId);
int wolfSSL_mcast_get_max_peers ();
alias CallbackMcastHighwater = int function (
    ushort peerId,
    uint maxSeq,
    uint curSeq,
    void* ctx);
int wolfSSL_CTX_mcast_set_highwater_cb (
    WOLFSSL_CTX* ctx,
    uint maxSeq,
    uint first,
    uint second,
    CallbackMcastHighwater cb);
int wolfSSL_mcast_set_highwater_ctx (WOLFSSL* ssl, void* ctx);

int wolfSSL_ERR_GET_LIB (c_ulong err);
int wolfSSL_ERR_GET_REASON (c_ulong err);
char* wolfSSL_ERR_error_string (c_ulong errNumber, char* data);
void wolfSSL_ERR_error_string_n (c_ulong e, char* buf, c_ulong sz);
const(char)* wolfSSL_ERR_reason_error_string (c_ulong e);
const(char)* wolfSSL_ERR_func_error_string (c_ulong e);
const(char)* wolfSSL_ERR_lib_error_string (c_ulong e);

/* extras */

WOLFSSL_STACK* wolfSSL_sk_new_node (void* heap);
void wolfSSL_sk_free (WOLFSSL_STACK* sk);
void wolfSSL_sk_free_node (WOLFSSL_STACK* in_);
WOLFSSL_STACK* wolfSSL_sk_dup (WOLFSSL_STACK* sk);
int wolfSSL_sk_push_node (WOLFSSL_STACK** stack, WOLFSSL_STACK* in_);
WOLFSSL_STACK* wolfSSL_sk_get_node (WOLFSSL_STACK* sk, int idx);
int wolfSSL_sk_push (WOLFSSL_STACK* st, const(void)* data);

/* defined(OPENSSL_ALL) || OPENSSL_EXTRA || defined(WOLFSSL_QT) */

alias WOLFSSL_GENERAL_NAMES = WOLFSSL_STACK;
alias WOLFSSL_DIST_POINTS = WOLFSSL_STACK;

int wolfSSL_sk_X509_push (WOLFSSL_STACK* sk, WOLFSSL_X509* x509);
WOLFSSL_X509* wolfSSL_sk_X509_pop (WOLFSSL_STACK* sk);
void wolfSSL_sk_X509_free (WOLFSSL_STACK* sk);

WOLFSSL_STACK* wolfSSL_sk_X509_CRL_new ();
void wolfSSL_sk_X509_CRL_pop_free (
    WOLFSSL_STACK* sk,
    void function (WOLFSSL_X509_CRL*) f);
void wolfSSL_sk_X509_CRL_free (WOLFSSL_STACK* sk);
int wolfSSL_sk_X509_CRL_push (WOLFSSL_STACK* sk, WOLFSSL_X509_CRL* crl);
WOLFSSL_X509_CRL* wolfSSL_sk_X509_CRL_value (WOLFSSL_STACK* sk, int i);
int wolfSSL_sk_X509_CRL_num (WOLFSSL_STACK* sk);

WOLFSSL_GENERAL_NAME* wolfSSL_GENERAL_NAME_new ();
void wolfSSL_GENERAL_NAME_free (WOLFSSL_GENERAL_NAME* gn);
WOLFSSL_GENERAL_NAME* wolfSSL_GENERAL_NAME_dup (WOLFSSL_GENERAL_NAME* gn);
int wolfSSL_GENERAL_NAME_set_type (WOLFSSL_GENERAL_NAME* name, int typ);
WOLFSSL_GENERAL_NAMES* wolfSSL_GENERAL_NAMES_dup (WOLFSSL_GENERAL_NAMES* gns);
int wolfSSL_sk_GENERAL_NAME_push (
    WOLFSSL_GENERAL_NAMES* sk,
    WOLFSSL_GENERAL_NAME* gn);
WOLFSSL_GENERAL_NAME* wolfSSL_sk_GENERAL_NAME_value (WOLFSSL_STACK* sk, int i);
int wolfSSL_sk_GENERAL_NAME_num (WOLFSSL_STACK* sk);
void wolfSSL_sk_GENERAL_NAME_pop_free (
    WOLFSSL_STACK* sk,
    void function (WOLFSSL_GENERAL_NAME*) f);
void wolfSSL_sk_GENERAL_NAME_free (WOLFSSL_STACK* sk);
void wolfSSL_GENERAL_NAMES_free (WOLFSSL_GENERAL_NAMES* name);
int wolfSSL_GENERAL_NAME_print (WOLFSSL_BIO* out_, WOLFSSL_GENERAL_NAME* name);

WOLFSSL_DIST_POINT* wolfSSL_DIST_POINT_new ();
void wolfSSL_DIST_POINT_free (WOLFSSL_DIST_POINT* dp);
int wolfSSL_sk_DIST_POINT_push (
    WOLFSSL_DIST_POINTS* sk,
    WOLFSSL_DIST_POINT* dp);
WOLFSSL_DIST_POINT* wolfSSL_sk_DIST_POINT_value (WOLFSSL_STACK* sk, int i);
int wolfSSL_sk_DIST_POINT_num (WOLFSSL_STACK* sk);
void wolfSSL_sk_DIST_POINT_pop_free (
    WOLFSSL_STACK* sk,
    void function (WOLFSSL_DIST_POINT*) f);
void wolfSSL_sk_DIST_POINT_free (WOLFSSL_STACK* sk);
void wolfSSL_DIST_POINTS_free (WOLFSSL_DIST_POINTS* dp);

int wolfSSL_sk_ACCESS_DESCRIPTION_num (WOLFSSL_STACK* sk);
void wolfSSL_AUTHORITY_INFO_ACCESS_free (WOLFSSL_STACK* sk);
void wolfSSL_AUTHORITY_INFO_ACCESS_pop_free (
    WOLFSSL_STACK* sk,
    void function (WOLFSSL_ACCESS_DESCRIPTION*) f);
WOLFSSL_ACCESS_DESCRIPTION* wolfSSL_sk_ACCESS_DESCRIPTION_value (
    WOLFSSL_STACK* sk,
    int idx);
void wolfSSL_sk_ACCESS_DESCRIPTION_free (WOLFSSL_STACK* sk);
void wolfSSL_sk_ACCESS_DESCRIPTION_pop_free (
    WOLFSSL_STACK* sk,
    void function (WOLFSSL_ACCESS_DESCRIPTION*) f);
void wolfSSL_ACCESS_DESCRIPTION_free (WOLFSSL_ACCESS_DESCRIPTION* a);
void wolfSSL_sk_X509_EXTENSION_pop_free (
    WOLFSSL_STACK* sk,
    void function (WOLFSSL_X509_EXTENSION*) f);
WOLFSSL_STACK* wolfSSL_sk_X509_EXTENSION_new_null ();
WOLFSSL_ASN1_OBJECT* wolfSSL_ASN1_OBJECT_new ();
WOLFSSL_ASN1_OBJECT* wolfSSL_ASN1_OBJECT_dup (WOLFSSL_ASN1_OBJECT* obj);
void wolfSSL_ASN1_OBJECT_free (WOLFSSL_ASN1_OBJECT* obj);
WOLFSSL_STACK* wolfSSL_sk_new_asn1_obj ();
int wolfSSL_sk_ASN1_OBJECT_push (WOLFSSL_STACK* sk, WOLFSSL_ASN1_OBJECT* obj);
WOLFSSL_ASN1_OBJECT* wolfSSL_sk_ASN1_OBJECT_pop (WOLFSSL_STACK* sk);
void wolfSSL_sk_ASN1_OBJECT_free (WOLFSSL_STACK* sk);
void wolfSSL_sk_ASN1_OBJECT_pop_free (
    WOLFSSL_STACK* sk,
    void function (WOLFSSL_ASN1_OBJECT*) f);
int wolfSSL_ASN1_STRING_to_UTF8 (ubyte** out_, WOLFSSL_ASN1_STRING* in_);
int wolfSSL_ASN1_UNIVERSALSTRING_to_string (WOLFSSL_ASN1_STRING* s);
int wolfSSL_sk_X509_EXTENSION_num (WOLFSSL_STACK* sk);
WOLFSSL_X509_EXTENSION* wolfSSL_sk_X509_EXTENSION_value (
    WOLFSSL_STACK* sk,
    int idx);
int wolfSSL_set_ex_data (WOLFSSL* ssl, int idx, void* data);

int wolfSSL_get_shutdown (const(WOLFSSL)* ssl);
int wolfSSL_set_rfd (WOLFSSL* ssl, int rfd);
int wolfSSL_set_wfd (WOLFSSL* ssl, int wfd);
void wolfSSL_set_shutdown (WOLFSSL* ssl, int opt);
int wolfSSL_set_session_id_context (WOLFSSL* ssl, const(ubyte)* id, uint len);
void wolfSSL_set_connect_state (WOLFSSL* ssl);
void wolfSSL_set_accept_state (WOLFSSL* ssl);
int wolfSSL_session_reused (WOLFSSL* ssl);
int wolfSSL_SESSION_up_ref (WOLFSSL_SESSION* session);
WOLFSSL_SESSION* wolfSSL_SESSION_dup (WOLFSSL_SESSION* session);
WOLFSSL_SESSION* wolfSSL_SESSION_new ();
WOLFSSL_SESSION* wolfSSL_SESSION_new_ex (void* heap);
void wolfSSL_SESSION_free (WOLFSSL_SESSION* session);
int wolfSSL_CTX_add_session (WOLFSSL_CTX* ctx, WOLFSSL_SESSION* session);
int wolfSSL_SESSION_set_cipher (
    WOLFSSL_SESSION* session,
    const(WOLFSSL_CIPHER)* cipher);
int wolfSSL_is_init_finished (WOLFSSL* ssl);

const(char)* wolfSSL_get_version (const(WOLFSSL)* ssl);
int wolfSSL_get_current_cipher_suite (WOLFSSL* ssl);
WOLFSSL_CIPHER* wolfSSL_get_current_cipher (WOLFSSL* ssl);
char* wolfSSL_CIPHER_description (const(WOLFSSL_CIPHER)* cipher, char* in_, int len);
const(char)* wolfSSL_CIPHER_get_name (const(WOLFSSL_CIPHER)* cipher);
const(char)* wolfSSL_CIPHER_get_version (const(WOLFSSL_CIPHER)* cipher);
word32 wolfSSL_CIPHER_get_id (const(WOLFSSL_CIPHER)* cipher);
int wolfSSL_CIPHER_get_auth_nid (const(WOLFSSL_CIPHER)* cipher);
int wolfSSL_CIPHER_get_cipher_nid (const(WOLFSSL_CIPHER)* cipher);
int wolfSSL_CIPHER_get_digest_nid (const(WOLFSSL_CIPHER)* cipher);
int wolfSSL_CIPHER_get_kx_nid (const(WOLFSSL_CIPHER)* cipher);
int wolfSSL_CIPHER_is_aead (const(WOLFSSL_CIPHER)* cipher);
const(WOLFSSL_CIPHER)* wolfSSL_get_cipher_by_value (word16 value);
const(char)* wolfSSL_SESSION_CIPHER_get_name (const(WOLFSSL_SESSION)* session);
const(char)* wolfSSL_get_cipher (WOLFSSL* ssl);
void wolfSSL_sk_CIPHER_free (WOLFSSL_STACK* sk);
WOLFSSL_SESSION* wolfSSL_get1_session (WOLFSSL* ssl);

WOLFSSL_X509* wolfSSL_X509_new ();
WOLFSSL_X509* wolfSSL_X509_dup (WOLFSSL_X509* x);

int wolfSSL_OCSP_parse_url (
    char* url,
    char** host,
    char** port,
    char** path,
    int* ssl);

WOLFSSL_BIO* wolfSSL_BIO_new (WOLFSSL_BIO_METHOD*);

int wolfSSL_BIO_free (WOLFSSL_BIO* bio);
void wolfSSL_BIO_vfree (WOLFSSL_BIO* bio);
void wolfSSL_BIO_free_all (WOLFSSL_BIO* bio);
int wolfSSL_BIO_gets (WOLFSSL_BIO* bio, char* buf, int sz);
int wolfSSL_BIO_puts (WOLFSSL_BIO* bio, const(char)* buf);
WOLFSSL_BIO* wolfSSL_BIO_next (WOLFSSL_BIO* bio);
WOLFSSL_BIO* wolfSSL_BIO_find_type (WOLFSSL_BIO* bio, int type);
int wolfSSL_BIO_read (WOLFSSL_BIO* bio, void* buf, int len);
int wolfSSL_BIO_write (WOLFSSL_BIO* bio, const(void)* data, int len);
WOLFSSL_BIO* wolfSSL_BIO_push (WOLFSSL_BIO* top, WOLFSSL_BIO* append);
WOLFSSL_BIO* wolfSSL_BIO_pop (WOLFSSL_BIO* bio);
int wolfSSL_BIO_flush (WOLFSSL_BIO* bio);
int wolfSSL_BIO_pending (WOLFSSL_BIO* bio);
void wolfSSL_BIO_set_callback (
    WOLFSSL_BIO* bio,
    wolf_bio_info_cb callback_func);
wolf_bio_info_cb wolfSSL_BIO_get_callback (WOLFSSL_BIO* bio);
void wolfSSL_BIO_set_callback_arg (WOLFSSL_BIO* bio, char* arg);
char* wolfSSL_BIO_get_callback_arg (const(WOLFSSL_BIO)* bio);

WOLFSSL_BIO_METHOD* wolfSSL_BIO_f_md ();
int wolfSSL_BIO_get_md_ctx (WOLFSSL_BIO* bio, WOLFSSL_EVP_MD_CTX** mdcp);

WOLFSSL_BIO_METHOD* wolfSSL_BIO_f_buffer ();
c_long wolfSSL_BIO_set_write_buffer_size (WOLFSSL_BIO* bio, c_long size);
WOLFSSL_BIO_METHOD* wolfSSL_BIO_f_ssl ();
WOLFSSL_BIO* wolfSSL_BIO_new_socket (int sfd, int flag);
int wolfSSL_BIO_eof (WOLFSSL_BIO* b);

WOLFSSL_BIO_METHOD* wolfSSL_BIO_s_mem ();
WOLFSSL_BIO_METHOD* wolfSSL_BIO_f_base64 ();
void wolfSSL_BIO_set_flags (WOLFSSL_BIO* bio, int flags);
void wolfSSL_BIO_clear_flags (WOLFSSL_BIO* bio, int flags);
int wolfSSL_BIO_get_fd (WOLFSSL_BIO* bio, int* fd);
int wolfSSL_BIO_set_ex_data (WOLFSSL_BIO* bio, int idx, void* data);

void* wolfSSL_BIO_get_ex_data (WOLFSSL_BIO* bio, int idx);
c_long wolfSSL_BIO_set_nbio (WOLFSSL_BIO* bio, c_long on);

int wolfSSL_BIO_get_mem_data (WOLFSSL_BIO* bio, void* p);

void wolfSSL_BIO_set_init (WOLFSSL_BIO* bio, int init);
void wolfSSL_BIO_set_data (WOLFSSL_BIO* bio, void* ptr);
void* wolfSSL_BIO_get_data (WOLFSSL_BIO* bio);
void wolfSSL_BIO_set_shutdown (WOLFSSL_BIO* bio, int shut);
int wolfSSL_BIO_get_shutdown (WOLFSSL_BIO* bio);
void wolfSSL_BIO_clear_retry_flags (WOLFSSL_BIO* bio);
int wolfSSL_BIO_should_retry (WOLFSSL_BIO* bio);

WOLFSSL_BIO_METHOD* wolfSSL_BIO_meth_new (int type, const(char)* name);
void wolfSSL_BIO_meth_free (WOLFSSL_BIO_METHOD* biom);
int wolfSSL_BIO_meth_set_write (WOLFSSL_BIO_METHOD* biom, wolfSSL_BIO_meth_write_cb biom_write);
int wolfSSL_BIO_meth_set_read (WOLFSSL_BIO_METHOD* biom, wolfSSL_BIO_meth_read_cb biom_read);
int wolfSSL_BIO_meth_set_puts (WOLFSSL_BIO_METHOD* biom, wolfSSL_BIO_meth_puts_cb biom_puts);
int wolfSSL_BIO_meth_set_gets (WOLFSSL_BIO_METHOD* biom, wolfSSL_BIO_meth_gets_cb biom_gets);
int wolfSSL_BIO_meth_set_ctrl (WOLFSSL_BIO_METHOD* biom, wolfSSL_BIO_meth_ctrl_get_cb biom_ctrl);
int wolfSSL_BIO_meth_set_create (WOLFSSL_BIO_METHOD* biom, wolfSSL_BIO_meth_create_cb biom_create);
int wolfSSL_BIO_meth_set_destroy (WOLFSSL_BIO_METHOD* biom, wolfSSL_BIO_meth_destroy_cb biom_destroy);
WOLFSSL_BIO* wolfSSL_BIO_new_mem_buf (const(void)* buf, int len);

c_long wolfSSL_BIO_set_ssl (WOLFSSL_BIO* b, WOLFSSL* ssl, int flag);
c_long wolfSSL_BIO_get_ssl (WOLFSSL_BIO* bio, WOLFSSL** ssl);

c_long wolfSSL_BIO_set_fd (WOLFSSL_BIO* b, int fd, int flag);

int wolfSSL_BIO_set_close (WOLFSSL_BIO* b, c_long flag);
void wolfSSL_set_bio (WOLFSSL* ssl, WOLFSSL_BIO* rd, WOLFSSL_BIO* wr);
int wolfSSL_BIO_method_type (const(WOLFSSL_BIO)* b);

WOLFSSL_BIO_METHOD* wolfSSL_BIO_s_file ();
WOLFSSL_BIO* wolfSSL_BIO_new_fd (int fd, int close_flag);

WOLFSSL_BIO_METHOD* wolfSSL_BIO_s_bio ();
WOLFSSL_BIO_METHOD* wolfSSL_BIO_s_socket ();

WOLFSSL_BIO* wolfSSL_BIO_new_connect (const(char)* str);
WOLFSSL_BIO* wolfSSL_BIO_new_accept (const(char)* port);
c_long wolfSSL_BIO_set_conn_hostname (WOLFSSL_BIO* b, char* name);
c_long wolfSSL_BIO_set_conn_port (WOLFSSL_BIO* b, char* port);
c_long wolfSSL_BIO_do_connect (WOLFSSL_BIO* b);
int wolfSSL_BIO_do_accept (WOLFSSL_BIO* b);
WOLFSSL_BIO* wolfSSL_BIO_new_ssl_connect (WOLFSSL_CTX* ctx);

c_long wolfSSL_BIO_do_handshake (WOLFSSL_BIO* b);
void wolfSSL_BIO_ssl_shutdown (WOLFSSL_BIO* b);

c_long wolfSSL_BIO_ctrl (WOLFSSL_BIO* bp, int cmd, c_long larg, void* parg);
c_long wolfSSL_BIO_int_ctrl (WOLFSSL_BIO* bp, int cmd, c_long larg, int iarg);

int wolfSSL_BIO_set_write_buf_size (WOLFSSL_BIO* b, c_long size);
int wolfSSL_BIO_make_bio_pair (WOLFSSL_BIO* b1, WOLFSSL_BIO* b2);
int wolfSSL_BIO_up_ref (WOLFSSL_BIO* b);
int wolfSSL_BIO_ctrl_reset_read_request (WOLFSSL_BIO* b);
int wolfSSL_BIO_nread0 (WOLFSSL_BIO* bio, char** buf);
int wolfSSL_BIO_nread (WOLFSSL_BIO* bio, char** buf, int num);
int wolfSSL_BIO_nwrite (WOLFSSL_BIO* bio, char** buf, int num);
int wolfSSL_BIO_reset (WOLFSSL_BIO* bio);

int wolfSSL_BIO_seek (WOLFSSL_BIO* bio, int ofs);
int wolfSSL_BIO_tell (WOLFSSL_BIO* bio);
int wolfSSL_BIO_write_filename (WOLFSSL_BIO* bio, char* name);
c_long wolfSSL_BIO_set_mem_eof_return (WOLFSSL_BIO* bio, int v);
c_long wolfSSL_BIO_get_mem_ptr (WOLFSSL_BIO* bio, WOLFSSL_BUF_MEM** m);
int wolfSSL_BIO_get_len (WOLFSSL_BIO* bio);

void wolfSSL_RAND_screen ();
const(char)* wolfSSL_RAND_file_name (char* fname, c_ulong len);
int wolfSSL_RAND_write_file (const(char)* fname);
int wolfSSL_RAND_load_file (const(char)* fname, c_long len);
int wolfSSL_RAND_egd (const(char)* nm);
int wolfSSL_RAND_seed (const(void)* seed, int len);
void wolfSSL_RAND_Cleanup ();
void wolfSSL_RAND_add (const(void)* add, int len, double entropy);
int wolfSSL_RAND_poll ();

WOLFSSL_COMP_METHOD* wolfSSL_COMP_zlib ();
WOLFSSL_COMP_METHOD* wolfSSL_COMP_rle ();
int wolfSSL_COMP_add_compression_method (int method, void* data);

c_ulong wolfSSL_thread_id ();
void wolfSSL_set_id_callback (c_ulong function () f);
void wolfSSL_set_locking_callback (
    void function (int, int, const(char)*, int) f);
void wolfSSL_set_dynlock_create_callback (
    WOLFSSL_dynlock_value* function (const(char)*, int) f);
void wolfSSL_set_dynlock_lock_callback (
    void function (int, WOLFSSL_dynlock_value*, const(char)*, int) f);
void wolfSSL_set_dynlock_destroy_callback (
    void function (WOLFSSL_dynlock_value*, const(char)*, int) f);
int wolfSSL_num_locks ();

WOLFSSL_X509* wolfSSL_X509_STORE_CTX_get_current_cert (
    WOLFSSL_X509_STORE_CTX* ctx);
int wolfSSL_X509_STORE_CTX_get_error (WOLFSSL_X509_STORE_CTX* ctx);
int wolfSSL_X509_STORE_CTX_get_error_depth (WOLFSSL_X509_STORE_CTX* ctx);

void wolfSSL_X509_STORE_CTX_set_verify_cb (
    WOLFSSL_X509_STORE_CTX* ctx,
    WOLFSSL_X509_STORE_CTX_verify_cb verify_cb);
void wolfSSL_X509_STORE_set_verify_cb (
    WOLFSSL_X509_STORE* st,
    WOLFSSL_X509_STORE_CTX_verify_cb verify_cb);
int wolfSSL_i2d_X509_NAME (WOLFSSL_X509_NAME* n, ubyte** out_);
int wolfSSL_i2d_X509_NAME_canon (WOLFSSL_X509_NAME* name, ubyte** out_);
WOLFSSL_X509_NAME* wolfSSL_d2i_X509_NAME (
    WOLFSSL_X509_NAME** name,
    ubyte** in_,
    c_long length);

int wolfSSL_RSA_print_fp (FILE* fp, WOLFSSL_RSA* rsa, int indent);
/* !NO_FILESYSTEM && !NO_STDIO_FILESYSTEM */

int wolfSSL_RSA_print (WOLFSSL_BIO* bio, WOLFSSL_RSA* rsa, int offset);
/* !NO_BIO */
/* !NO_RSA */

int wolfSSL_X509_print_ex (
    WOLFSSL_BIO* bio,
    WOLFSSL_X509* x509,
    c_ulong nmflags,
    c_ulong cflag);

int wolfSSL_X509_print_fp (FILE* fp, WOLFSSL_X509* x509);

int wolfSSL_X509_signature_print (
    WOLFSSL_BIO* bp,
    const(WOLFSSL_X509_ALGOR)* sigalg,
    const(WOLFSSL_ASN1_STRING)* sig);
void wolfSSL_X509_get0_signature (
    const(WOLFSSL_ASN1_BIT_STRING*)* psig,
    const(WOLFSSL_X509_ALGOR*)* palg,
    const(WOLFSSL_X509)* x509);
int wolfSSL_X509_print (WOLFSSL_BIO* bio, WOLFSSL_X509* x509);
int wolfSSL_X509_REQ_print (WOLFSSL_BIO* bio, WOLFSSL_X509* x509);
char* wolfSSL_X509_NAME_oneline (WOLFSSL_X509_NAME* name, char* in_, int sz);
c_ulong wolfSSL_X509_NAME_hash (WOLFSSL_X509_NAME* name);

WOLFSSL_X509_NAME* wolfSSL_X509_get_issuer_name (WOLFSSL_X509* cert);
c_ulong wolfSSL_X509_issuer_name_hash (const(WOLFSSL_X509)* x509);
WOLFSSL_X509_NAME* wolfSSL_X509_get_subject_name (WOLFSSL_X509* cert);
c_ulong wolfSSL_X509_subject_name_hash (const(WOLFSSL_X509)* x509);
int wolfSSL_X509_ext_isSet_by_NID (WOLFSSL_X509* x509, int nid);
int wolfSSL_X509_ext_get_critical_by_NID (WOLFSSL_X509* x509, int nid);
int wolfSSL_X509_EXTENSION_set_critical (WOLFSSL_X509_EXTENSION* ex, int crit);
int wolfSSL_X509_get_isCA (WOLFSSL_X509* x509);
int wolfSSL_X509_get_isSet_pathLength (WOLFSSL_X509* x509);
uint wolfSSL_X509_get_pathLength (WOLFSSL_X509* x509);
uint wolfSSL_X509_get_keyUsage (WOLFSSL_X509* x509);
ubyte* wolfSSL_X509_get_authorityKeyID (
    WOLFSSL_X509* x509,
    ubyte* dst,
    int* dstLen);
ubyte* wolfSSL_X509_get_subjectKeyID (
    WOLFSSL_X509* x509,
    ubyte* dst,
    int* dstLen);

int wolfSSL_X509_verify (WOLFSSL_X509* x509, WOLFSSL_EVP_PKEY* pkey);

int wolfSSL_X509_set_subject_name (WOLFSSL_X509* cert, WOLFSSL_X509_NAME* name);
int wolfSSL_X509_set_issuer_name (WOLFSSL_X509* cert, WOLFSSL_X509_NAME* name);
int wolfSSL_X509_set_pubkey (WOLFSSL_X509* cert, WOLFSSL_EVP_PKEY* pkey);
int wolfSSL_X509_set_notAfter (WOLFSSL_X509* x509, const(WOLFSSL_ASN1_TIME)* t);
int wolfSSL_X509_set_notBefore (
    WOLFSSL_X509* x509,
    const(WOLFSSL_ASN1_TIME)* t);
WOLFSSL_ASN1_TIME* wolfSSL_X509_get_notBefore (const(WOLFSSL_X509)* x509);
WOLFSSL_ASN1_TIME* wolfSSL_X509_get_notAfter (const(WOLFSSL_X509)* x509);
int wolfSSL_X509_set_serialNumber (WOLFSSL_X509* x509, WOLFSSL_ASN1_INTEGER* s);
int wolfSSL_X509_set_version (WOLFSSL_X509* x509, c_long v);
int wolfSSL_X509_sign (
    WOLFSSL_X509* x509,
    WOLFSSL_EVP_PKEY* pkey,
    const(WOLFSSL_EVP_MD)* md);
int wolfSSL_X509_sign_ctx (WOLFSSL_X509* x509, WOLFSSL_EVP_MD_CTX* ctx);

int wolfSSL_X509_NAME_entry_count (WOLFSSL_X509_NAME* name);
int wolfSSL_X509_NAME_get_sz (WOLFSSL_X509_NAME* name);
int wolfSSL_X509_NAME_get_text_by_NID (
    WOLFSSL_X509_NAME* name,
    int nid,
    char* buf,
    int len);
int wolfSSL_X509_NAME_get_index_by_NID (
    WOLFSSL_X509_NAME* name,
    int nid,
    int pos);
WOLFSSL_ASN1_STRING* wolfSSL_X509_NAME_ENTRY_get_data (WOLFSSL_X509_NAME_ENTRY* in_);

WOLFSSL_ASN1_STRING* wolfSSL_ASN1_STRING_new ();
WOLFSSL_ASN1_STRING* wolfSSL_ASN1_STRING_dup (WOLFSSL_ASN1_STRING* asn1);
WOLFSSL_ASN1_STRING* wolfSSL_ASN1_STRING_type_new (int type);
int wolfSSL_ASN1_STRING_type (const(WOLFSSL_ASN1_STRING)* asn1);
WOLFSSL_ASN1_STRING* wolfSSL_d2i_DISPLAYTEXT (WOLFSSL_ASN1_STRING** asn, const(ubyte*)* in_, c_long len);
int wolfSSL_ASN1_STRING_cmp (const(WOLFSSL_ASN1_STRING)* a, const(WOLFSSL_ASN1_STRING)* b);
void wolfSSL_ASN1_STRING_free (WOLFSSL_ASN1_STRING* asn1);
int wolfSSL_ASN1_STRING_set (
    WOLFSSL_ASN1_STRING* asn1,
    const(void)* data,
    int dataSz);
ubyte* wolfSSL_ASN1_STRING_data (WOLFSSL_ASN1_STRING* asn);
const(ubyte)* wolfSSL_ASN1_STRING_get0_data (const(WOLFSSL_ASN1_STRING)* asn);
int wolfSSL_ASN1_STRING_length (WOLFSSL_ASN1_STRING* asn);
int wolfSSL_ASN1_STRING_copy (
    WOLFSSL_ASN1_STRING* dst,
    const(WOLFSSL_ASN1_STRING)* src);
int wolfSSL_X509_verify_cert (WOLFSSL_X509_STORE_CTX* ctx);
const(char)* wolfSSL_X509_verify_cert_error_string (c_long err);
int wolfSSL_X509_get_signature_type (WOLFSSL_X509* x509);
int wolfSSL_X509_get_signature (WOLFSSL_X509* x509, ubyte* buf, int* bufSz);
int wolfSSL_X509_get_pubkey_buffer (WOLFSSL_X509* x509, ubyte* buf, int* bufSz);
int wolfSSL_X509_get_pubkey_type (WOLFSSL_X509* x509);

int wolfSSL_X509_LOOKUP_add_dir (WOLFSSL_X509_LOOKUP* lookup, const(char)* dir, c_long len);
int wolfSSL_X509_LOOKUP_load_file (
    WOLFSSL_X509_LOOKUP* lookup,
    const(char)* file,
    c_long type);
WOLFSSL_X509_LOOKUP_METHOD* wolfSSL_X509_LOOKUP_hash_dir ();
WOLFSSL_X509_LOOKUP_METHOD* wolfSSL_X509_LOOKUP_file ();
int wolfSSL_X509_LOOKUP_ctrl (
    WOLFSSL_X509_LOOKUP* ctx,
    int cmd,
    const(char)* argc,
    c_long argl,
    char** ret);

WOLFSSL_X509_LOOKUP* wolfSSL_X509_STORE_add_lookup (
    WOLFSSL_X509_STORE* store,
    WOLFSSL_X509_LOOKUP_METHOD* m);
WOLFSSL_X509_STORE* wolfSSL_X509_STORE_new ();
void wolfSSL_X509_STORE_free (WOLFSSL_X509_STORE* store);
int wolfSSL_X509_STORE_up_ref (WOLFSSL_X509_STORE* store);
int wolfSSL_X509_STORE_add_cert (WOLFSSL_X509_STORE* store, WOLFSSL_X509* x509);
WOLFSSL_STACK* wolfSSL_X509_STORE_CTX_get_chain (WOLFSSL_X509_STORE_CTX* ctx);
WOLFSSL_STACK* wolfSSL_X509_STORE_CTX_get1_chain (WOLFSSL_X509_STORE_CTX* ctx);
WOLFSSL_X509_STORE_CTX* wolfSSL_X509_STORE_CTX_get0_parent_ctx (
    WOLFSSL_X509_STORE_CTX* ctx);
int wolfSSL_X509_STORE_set_flags (WOLFSSL_X509_STORE* store, c_ulong flag);
int wolfSSL_X509_STORE_set_default_paths (WOLFSSL_X509_STORE* store);
int wolfSSL_X509_STORE_get_by_subject (
    WOLFSSL_X509_STORE_CTX* ctx,
    int idx,
    WOLFSSL_X509_NAME* name,
    WOLFSSL_X509_OBJECT* obj);
WOLFSSL_X509_STORE_CTX* wolfSSL_X509_STORE_CTX_new ();
int wolfSSL_X509_STORE_CTX_init (
    WOLFSSL_X509_STORE_CTX* ctx,
    WOLFSSL_X509_STORE* store,
    WOLFSSL_X509* x509,
    WOLFSSL_STACK*);
void wolfSSL_X509_STORE_CTX_free (WOLFSSL_X509_STORE_CTX* ctx);
void wolfSSL_X509_STORE_CTX_cleanup (WOLFSSL_X509_STORE_CTX* ctx);
void wolfSSL_X509_STORE_CTX_trusted_stack (
    WOLFSSL_X509_STORE_CTX* ctx,
    WOLFSSL_STACK* sk);

WOLFSSL_ASN1_TIME* wolfSSL_X509_CRL_get_lastUpdate (WOLFSSL_X509_CRL* crl);
WOLFSSL_ASN1_TIME* wolfSSL_X509_CRL_get_nextUpdate (WOLFSSL_X509_CRL* crl);

WOLFSSL_EVP_PKEY* wolfSSL_X509_get_pubkey (WOLFSSL_X509* x509);
int wolfSSL_X509_CRL_verify (WOLFSSL_X509_CRL* crl, WOLFSSL_EVP_PKEY* pkey);
void wolfSSL_X509_OBJECT_free_contents (WOLFSSL_X509_OBJECT* obj);
WOLFSSL_PKCS8_PRIV_KEY_INFO* wolfSSL_d2i_PKCS8_PKEY_bio (
    WOLFSSL_BIO* bio,
    WOLFSSL_PKCS8_PRIV_KEY_INFO** pkey);
WOLFSSL_PKCS8_PRIV_KEY_INFO* wolfSSL_d2i_PKCS8_PKEY (
    WOLFSSL_PKCS8_PRIV_KEY_INFO** pkey,
    const(ubyte*)* keyBuf,
    c_long keyLen);
WOLFSSL_EVP_PKEY* wolfSSL_d2i_PUBKEY_bio (
    WOLFSSL_BIO* bio,
    WOLFSSL_EVP_PKEY** out_);
WOLFSSL_EVP_PKEY* wolfSSL_d2i_PUBKEY (
    WOLFSSL_EVP_PKEY** key,
    const(ubyte*)* in_,
    c_long inSz);
int wolfSSL_i2d_PUBKEY (const(WOLFSSL_EVP_PKEY)* key, ubyte** der);
WOLFSSL_EVP_PKEY* wolfSSL_d2i_PublicKey (
    int type,
    WOLFSSL_EVP_PKEY** pkey,
    const(ubyte*)* in_,
    c_long inSz);
WOLFSSL_EVP_PKEY* wolfSSL_d2i_PrivateKey (
    int type,
    WOLFSSL_EVP_PKEY** out_,
    const(ubyte*)* in_,
    c_long inSz);

WOLFSSL_EVP_PKEY* wolfSSL_d2i_PrivateKey_EVP (
    WOLFSSL_EVP_PKEY** key,
    ubyte** in_,
    c_long inSz);
int wolfSSL_i2d_PrivateKey (const(WOLFSSL_EVP_PKEY)* key, ubyte** der);
int wolfSSL_i2d_PublicKey (const(WOLFSSL_EVP_PKEY)* key, ubyte** der);

/* OPENSSL_EXTRA && !WOLFCRYPT_ONLY */
int wolfSSL_X509_cmp_current_time (const(WOLFSSL_ASN1_TIME)* asnTime);

WOLFSSL_X509_REVOKED* wolfSSL_X509_CRL_get_REVOKED (WOLFSSL_X509_CRL* crl);
WOLFSSL_X509_REVOKED* wolfSSL_sk_X509_REVOKED_value (
    WOLFSSL_X509_REVOKED* revoked,
    int value);
WOLFSSL_ASN1_INTEGER* wolfSSL_X509_get_serialNumber (WOLFSSL_X509* x509);
void wolfSSL_ASN1_INTEGER_free (WOLFSSL_ASN1_INTEGER* in_);
WOLFSSL_ASN1_INTEGER* wolfSSL_ASN1_INTEGER_new ();
WOLFSSL_ASN1_INTEGER* wolfSSL_ASN1_INTEGER_dup (
    const(WOLFSSL_ASN1_INTEGER)* src);
int wolfSSL_ASN1_INTEGER_set (WOLFSSL_ASN1_INTEGER* a, c_long v);
WOLFSSL_ASN1_INTEGER* wolfSSL_d2i_ASN1_INTEGER (
    WOLFSSL_ASN1_INTEGER** a,
    const(ubyte*)* in_,
    c_long inSz);
int wolfSSL_i2d_ASN1_INTEGER (WOLFSSL_ASN1_INTEGER* a, ubyte** out_);

int wolfSSL_ASN1_TIME_print (WOLFSSL_BIO* bio, const(WOLFSSL_ASN1_TIME)* asnTime);

char* wolfSSL_ASN1_TIME_to_string (WOLFSSL_ASN1_TIME* t, char* buf, int len);

int wolfSSL_ASN1_TIME_to_tm (const(WOLFSSL_ASN1_TIME)* asnTime, tm* tm);

int wolfSSL_ASN1_INTEGER_cmp (
    const(WOLFSSL_ASN1_INTEGER)* a,
    const(WOLFSSL_ASN1_INTEGER)* b);
c_long wolfSSL_ASN1_INTEGER_get (const(WOLFSSL_ASN1_INTEGER)* a);

WOLFSSL_STACK* wolfSSL_load_client_CA_file (const(char)* fname);
WOLFSSL_STACK* wolfSSL_CTX_get_client_CA_list (const(WOLFSSL_CTX)* ctx);
/* deprecated function name */
alias wolfSSL_SSL_CTX_get_client_CA_list = wolfSSL_CTX_get_client_CA_list;

void wolfSSL_CTX_set_client_CA_list (WOLFSSL_CTX* ctx, WOLFSSL_STACK*);
void wolfSSL_set_client_CA_list (WOLFSSL* ssl, WOLFSSL_STACK*);
WOLFSSL_STACK* wolfSSL_get_client_CA_list (const(WOLFSSL)* ssl);

alias client_cert_cb = int function (
    WOLFSSL* ssl,
    WOLFSSL_X509** x509,
    WOLFSSL_EVP_PKEY** pkey);
void wolfSSL_CTX_set_client_cert_cb (WOLFSSL_CTX* ctx, client_cert_cb cb);

alias CertSetupCallback = int function (WOLFSSL* ssl, void*);
void wolfSSL_CTX_set_cert_cb (
    WOLFSSL_CTX* ctx,
    CertSetupCallback cb,
    void* arg);
int CertSetupCbWrapper (WOLFSSL* ssl);

void* wolfSSL_X509_STORE_CTX_get_ex_data (WOLFSSL_X509_STORE_CTX* ctx, int idx);
int wolfSSL_X509_STORE_CTX_set_ex_data (
    WOLFSSL_X509_STORE_CTX* ctx,
    int idx,
    void* data);

void* wolfSSL_X509_STORE_get_ex_data (WOLFSSL_X509_STORE* store, int idx);
int wolfSSL_X509_STORE_set_ex_data (
    WOLFSSL_X509_STORE* store,
    int idx,
    void* data);

void wolfSSL_X509_STORE_CTX_set_depth (WOLFSSL_X509_STORE_CTX* ctx, int depth);
WOLFSSL_X509* wolfSSL_X509_STORE_CTX_get0_current_issuer (
    WOLFSSL_X509_STORE_CTX* ctx);
WOLFSSL_X509_STORE* wolfSSL_X509_STORE_CTX_get0_store (
    WOLFSSL_X509_STORE_CTX* ctx);
WOLFSSL_X509* wolfSSL_X509_STORE_CTX_get0_cert (WOLFSSL_X509_STORE_CTX* ctx);
int wolfSSL_get_ex_data_X509_STORE_CTX_idx ();
void wolfSSL_X509_STORE_CTX_set_error (WOLFSSL_X509_STORE_CTX* ctx, int er);
void wolfSSL_X509_STORE_CTX_set_error_depth (
    WOLFSSL_X509_STORE_CTX* ctx,
    int depth);
void* wolfSSL_get_ex_data (const(WOLFSSL)* ssl, int idx);

void wolfSSL_CTX_set_default_passwd_cb_userdata (
    WOLFSSL_CTX* ctx,
    void* userdata);
void wolfSSL_CTX_set_default_passwd_cb (WOLFSSL_CTX* ctx, int function () cb);
int function (WOLFSSL_CTX* ctx) wolfSSL_CTX_get_default_passwd_cb (WOLFSSL_CTX* ctx);
void* wolfSSL_CTX_get_default_passwd_cb_userdata (WOLFSSL_CTX* ctx);

void wolfSSL_CTX_set_info_callback (
    WOLFSSL_CTX* ctx,
    void function (const(WOLFSSL)* ssl, int type, int val) f);

c_ulong wolfSSL_ERR_peek_error ();
int wolfSSL_GET_REASON (int);

const(char)* wolfSSL_alert_type_string_long (int alertID);
const(char)* wolfSSL_alert_desc_string_long (int alertID);
const(char)* wolfSSL_state_string_long (const(WOLFSSL)* ssl);

WOLFSSL_RSA* wolfSSL_RSA_generate_key (
    int len,
    c_ulong e,
    void function (int, int, void*) f,
    void* data);
WOLFSSL_RSA* wolfSSL_d2i_RSAPublicKey (
    WOLFSSL_RSA** r,
    const(ubyte*)* pp,
    c_long len);
WOLFSSL_RSA* wolfSSL_d2i_RSAPrivateKey (
    WOLFSSL_RSA** r,
    const(ubyte*)* derBuf,
    c_long derSz);
int wolfSSL_i2d_RSAPublicKey (WOLFSSL_RSA* r, ubyte** pp);
int wolfSSL_i2d_RSAPrivateKey (WOLFSSL_RSA* r, ubyte** pp);
void wolfSSL_CTX_set_tmp_rsa_callback (
    WOLFSSL_CTX* ctx,
    WOLFSSL_RSA* function (WOLFSSL*, int, int) f);

int wolfSSL_PEM_def_callback (char* name, int num, int w, void* key);

c_long wolfSSL_CTX_sess_accept (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_connect (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_accept_good (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_connect_good (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_accept_renegotiate (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_connect_renegotiate (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_hits (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_cb_hits (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_cache_full (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_misses (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_timeouts (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_sess_number (WOLFSSL_CTX* ctx);

c_long wolfSSL_CTX_add_extra_chain_cert (WOLFSSL_CTX* ctx, WOLFSSL_X509* x509);
c_long wolfSSL_CTX_sess_set_cache_size (WOLFSSL_CTX* ctx, c_long sz);
c_long wolfSSL_CTX_sess_get_cache_size (WOLFSSL_CTX* ctx);

c_long wolfSSL_CTX_get_session_cache_mode (WOLFSSL_CTX* ctx);
int wolfSSL_get_read_ahead (const(WOLFSSL)* ssl);
int wolfSSL_set_read_ahead (WOLFSSL* ssl, int v);
int wolfSSL_CTX_get_read_ahead (WOLFSSL_CTX* ctx);
int wolfSSL_CTX_set_read_ahead (WOLFSSL_CTX* ctx, int v);
c_long wolfSSL_CTX_set_tlsext_status_arg (WOLFSSL_CTX* ctx, void* arg);
c_long wolfSSL_CTX_set_tlsext_opaque_prf_input_callback_arg (
    WOLFSSL_CTX* ctx,
    void* arg);
int wolfSSL_CTX_add_client_CA (WOLFSSL_CTX* ctx, WOLFSSL_X509* x509);
int wolfSSL_CTX_set_srp_password (WOLFSSL_CTX* ctx, char* password);
int wolfSSL_CTX_set_srp_username (WOLFSSL_CTX* ctx, char* username);
int wolfSSL_CTX_set_srp_strength (WOLFSSL_CTX* ctx, int strength);

char* wolfSSL_get_srp_username (WOLFSSL* ssl);

c_long wolfSSL_set_options (WOLFSSL* s, c_long op);
c_long wolfSSL_get_options (const(WOLFSSL)* s);
c_long wolfSSL_clear_options (WOLFSSL* s, c_long op);
c_long wolfSSL_clear_num_renegotiations (WOLFSSL* s);
c_long wolfSSL_total_renegotiations (WOLFSSL* s);
c_long wolfSSL_num_renegotiations (WOLFSSL* s);
int wolfSSL_SSL_renegotiate_pending (WOLFSSL* s);
c_long wolfSSL_set_tmp_dh (WOLFSSL* s, WOLFSSL_DH* dh);
c_long wolfSSL_set_tlsext_debug_arg (WOLFSSL* s, void* arg);
c_long wolfSSL_set_tlsext_status_type (WOLFSSL* s, int type);
c_long wolfSSL_get_tlsext_status_type (WOLFSSL* s);
c_long wolfSSL_set_tlsext_status_exts (WOLFSSL* s, void* arg);
c_long wolfSSL_get_tlsext_status_ids (WOLFSSL* s, void* arg);
c_long wolfSSL_set_tlsext_status_ids (WOLFSSL* s, void* arg);
c_long wolfSSL_get_tlsext_status_ocsp_resp (WOLFSSL* s, ubyte** resp);
c_long wolfSSL_set_tlsext_status_ocsp_resp (WOLFSSL* s, ubyte* resp, int len);
int wolfSSL_set_tlsext_max_fragment_length (WOLFSSL* s, ubyte mode);
int wolfSSL_CTX_set_tlsext_max_fragment_length (WOLFSSL_CTX* c, ubyte mode);
void wolfSSL_CONF_modules_unload (int all);
char* wolfSSL_CONF_get1_default_config_file ();
c_long wolfSSL_get_tlsext_status_exts (WOLFSSL* s, void* arg);
c_long wolfSSL_get_verify_result (const(WOLFSSL)* ssl);

enum WOLFSSL_DEFAULT_CIPHER_LIST = ""; /* default all */

/* These are bit-masks */
enum
{
    WOLFSSL_OCSP_URL_OVERRIDE = 1,
    WOLFSSL_OCSP_NO_NONCE = 2,
    WOLFSSL_OCSP_CHECKALL = 4,

    WOLFSSL_CRL_CHECKALL = 1,
    WOLFSSL_CRL_CHECK = 2
}

/* Separated out from other enums because of size */
enum
{
    WOLFSSL_OP_MICROSOFT_SESS_ID_BUG = 0x00000001,
    WOLFSSL_OP_NETSCAPE_CHALLENGE_BUG = 0x00000002,
    WOLFSSL_OP_NETSCAPE_REUSE_CIPHER_CHANGE_BUG = 0x00000004,
    WOLFSSL_OP_SSLREF2_REUSE_CERT_TYPE_BUG = 0x00000008,
    WOLFSSL_OP_MICROSOFT_BIG_SSLV3_BUFFER = 0x00000010,
    WOLFSSL_OP_MSIE_SSLV2_RSA_PADDING = 0x00000020,
    WOLFSSL_OP_SSLEAY_080_CLIENT_DH_BUG = 0x00000040,
    WOLFSSL_OP_TLS_D5_BUG = 0x00000080,
    WOLFSSL_OP_TLS_BLOCK_PADDING_BUG = 0x00000100,
    WOLFSSL_OP_TLS_ROLLBACK_BUG = 0x00000200,
    WOLFSSL_OP_EPHEMERAL_RSA = 0x00000800,
    WOLFSSL_OP_NO_SSLv3 = 0x00001000,
    WOLFSSL_OP_NO_TLSv1 = 0x00002000,
    WOLFSSL_OP_PKCS1_CHECK_1 = 0x00004000,
    WOLFSSL_OP_PKCS1_CHECK_2 = 0x00008000,
    WOLFSSL_OP_NETSCAPE_CA_DN_BUG = 0x00010000,
    WOLFSSL_OP_NETSCAPE_DEMO_CIPHER_CHANGE_BUG = 0x00020000,
    WOLFSSL_OP_SINGLE_DH_USE = 0x00040000,
    WOLFSSL_OP_NO_TICKET = 0x00080000,
    WOLFSSL_OP_DONT_INSERT_EMPTY_FRAGMENTS = 0x00100000,
    WOLFSSL_OP_NO_QUERY_MTU = 0x00200000,
    WOLFSSL_OP_COOKIE_EXCHANGE = 0x00400000,
    WOLFSSL_OP_NO_SESSION_RESUMPTION_ON_RENEGOTIATION = 0x00800000,
    WOLFSSL_OP_SINGLE_ECDH_USE = 0x01000000,
    WOLFSSL_OP_CIPHER_SERVER_PREFERENCE = 0x02000000,
    WOLFSSL_OP_NO_TLSv1_1 = 0x04000000,
    WOLFSSL_OP_NO_TLSv1_2 = 0x08000000,
    WOLFSSL_OP_NO_COMPRESSION = 0x10000000,
    WOLFSSL_OP_NO_TLSv1_3 = 0x20000000,
    WOLFSSL_OP_NO_SSLv2 = 0x40000000,
    WOLFSSL_OP_ALL = WOLFSSL_OP_MICROSOFT_SESS_ID_BUG | WOLFSSL_OP_NETSCAPE_CHALLENGE_BUG | WOLFSSL_OP_NETSCAPE_REUSE_CIPHER_CHANGE_BUG | WOLFSSL_OP_SSLREF2_REUSE_CERT_TYPE_BUG | WOLFSSL_OP_MICROSOFT_BIG_SSLV3_BUFFER | WOLFSSL_OP_MSIE_SSLV2_RSA_PADDING | WOLFSSL_OP_SSLEAY_080_CLIENT_DH_BUG | WOLFSSL_OP_TLS_D5_BUG | WOLFSSL_OP_TLS_BLOCK_PADDING_BUG | WOLFSSL_OP_DONT_INSERT_EMPTY_FRAGMENTS | WOLFSSL_OP_TLS_ROLLBACK_BUG
}

/* for compatibility these must be macros */

/* apache uses SSL_OP_NO_TLSv1_3 to determine if TLS 1.3 is enabled */

/* OCSP Flags */

/* OCSP Types */

/* wolfSSL default is to return WANT_{READ|WRITE}
 * to the user. This is set by default with
 * OPENSSL_COMPATIBLE_DEFAULTS. The macro
 * WOLFSSL_MODE_AUTO_RETRY_ATTEMPTS is used to
 * limit the possibility of an infinite retry loop
 */
/* For libwebsockets build. No current use. */

/* Not all of these are actually used in wolfSSL. Some are included to
 * satisfy OpenSSL compatibility consumers to prevent compilation errors. */

/* extras end */

/* wolfSSL extension, provide last error from SSL_get_error
   since not using thread storage error queue */

void wolfSSL_ERR_print_errors_fp (FILE* fp, int err);

void wolfSSL_ERR_print_errors (WOLFSSL_BIO* bio);

enum SSL_ERROR_NONE = .WOLFSSL_ERROR_NONE;
enum SSL_FAILURE = .WOLFSSL_FAILURE;
enum SSL_SUCCESS = .WOLFSSL_SUCCESS;
enum SSL_SHUTDOWN_NOT_DONE = .WOLFSSL_SHUTDOWN_NOT_DONE;

enum SSL_ALPN_NOT_FOUND = .WOLFSSL_ALPN_NOT_FOUND;
enum SSL_BAD_CERTTYPE = .WOLFSSL_BAD_CERTTYPE;
enum SSL_BAD_STAT = .WOLFSSL_BAD_STAT;
enum SSL_BAD_PATH = .WOLFSSL_BAD_PATH;
enum SSL_BAD_FILETYPE = .WOLFSSL_BAD_FILETYPE;
enum SSL_BAD_FILE = .WOLFSSL_BAD_FILE;
enum SSL_NOT_IMPLEMENTED = .WOLFSSL_NOT_IMPLEMENTED;
enum SSL_UNKNOWN = .WOLFSSL_UNKNOWN;
enum SSL_FATAL_ERROR = .WOLFSSL_FATAL_ERROR;

enum SSL_FILETYPE_ASN1 = .WOLFSSL_FILETYPE_ASN1;
enum SSL_FILETYPE_PEM = .WOLFSSL_FILETYPE_PEM;
enum SSL_FILETYPE_DEFAULT = .WOLFSSL_FILETYPE_DEFAULT;

enum SSL_VERIFY_NONE = .WOLFSSL_VERIFY_NONE;
enum SSL_VERIFY_PEER = .WOLFSSL_VERIFY_PEER;
enum SSL_VERIFY_FAIL_IF_NO_PEER_CERT = .WOLFSSL_VERIFY_FAIL_IF_NO_PEER_CERT;
enum SSL_VERIFY_CLIENT_ONCE = .WOLFSSL_VERIFY_CLIENT_ONCE;
enum SSL_VERIFY_POST_HANDSHAKE = .WOLFSSL_VERIFY_POST_HANDSHAKE;
enum SSL_VERIFY_FAIL_EXCEPT_PSK = .WOLFSSL_VERIFY_FAIL_EXCEPT_PSK;

enum SSL_SESS_CACHE_OFF = .WOLFSSL_SESS_CACHE_OFF;
enum SSL_SESS_CACHE_CLIENT = .WOLFSSL_SESS_CACHE_CLIENT;
enum SSL_SESS_CACHE_SERVER = .WOLFSSL_SESS_CACHE_SERVER;
enum SSL_SESS_CACHE_BOTH = .WOLFSSL_SESS_CACHE_BOTH;
enum SSL_SESS_CACHE_NO_AUTO_CLEAR = .WOLFSSL_SESS_CACHE_NO_AUTO_CLEAR;
enum SSL_SESS_CACHE_NO_INTERNAL_LOOKUP = .WOLFSSL_SESS_CACHE_NO_INTERNAL_LOOKUP;
enum SSL_SESS_CACHE_NO_INTERNAL_STORE = .WOLFSSL_SESS_CACHE_NO_INTERNAL_STORE;
enum SSL_SESS_CACHE_NO_INTERNAL = .WOLFSSL_SESS_CACHE_NO_INTERNAL;

enum SSL_ERROR_WANT_READ = .WOLFSSL_ERROR_WANT_READ;
enum SSL_ERROR_WANT_WRITE = .WOLFSSL_ERROR_WANT_WRITE;
enum SSL_ERROR_WANT_CONNECT = .WOLFSSL_ERROR_WANT_CONNECT;
enum SSL_ERROR_WANT_ACCEPT = .WOLFSSL_ERROR_WANT_ACCEPT;
enum SSL_ERROR_SYSCALL = .WOLFSSL_ERROR_SYSCALL;
enum SSL_ERROR_WANT_X509_LOOKUP = .WOLFSSL_ERROR_WANT_X509_LOOKUP;
enum SSL_ERROR_ZERO_RETURN = .WOLFSSL_ERROR_ZERO_RETURN;
enum SSL_ERROR_SSL = .WOLFSSL_ERROR_SSL;

enum SSL_SENT_SHUTDOWN = .WOLFSSL_SENT_SHUTDOWN;
enum SSL_RECEIVED_SHUTDOWN = .WOLFSSL_RECEIVED_SHUTDOWN;
enum SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER = .WOLFSSL_MODE_ACCEPT_MOVING_WRITE_BUFFER;

enum SSL_R_SSL_HANDSHAKE_FAILURE = .WOLFSSL_R_SSL_HANDSHAKE_FAILURE;
enum SSL_R_TLSV1_ALERT_UNKNOWN_CA = .WOLFSSL_R_TLSV1_ALERT_UNKNOWN_CA;
enum SSL_R_SSLV3_ALERT_CERTIFICATE_UNKNOWN = .WOLFSSL_R_SSLV3_ALERT_CERTIFICATE_UNKNOWN;
enum SSL_R_SSLV3_ALERT_BAD_CERTIFICATE = .WOLFSSL_R_SSLV3_ALERT_BAD_CERTIFICATE;

enum PEM_BUFSIZE = .WOLF_PEM_BUFSIZE;

enum
{
    /* ssl Constants */
    WOLFSSL_ERROR_NONE = 0, /* for most functions */
    WOLFSSL_FAILURE = 0, /* for some functions */
    WOLFSSL_SUCCESS = 1,

    /* WOLFSSL_SHUTDOWN_NOT_DONE is returned by wolfSSL_shutdown when the other end
     * of the connection has yet to send its close notify alert as part of the
     * bidirectional shutdown. To complete the shutdown, either keep calling
     * wolfSSL_shutdown until it returns WOLFSSL_SUCCESS or call wolfSSL_read until
     * it returns <= 0 AND SSL_get_error returns SSL_ERROR_ZERO_RETURN. See OpenSSL
     * docs for more: https://www.openssl.org/docs/man1.1.1/man3/SSL_shutdown.html
     */

    /* SSL_shutdown returns 0 when not done, per OpenSSL documentation. */

    WOLFSSL_SHUTDOWN_NOT_DONE = 2,

    WOLFSSL_ALPN_NOT_FOUND = -9,
    WOLFSSL_BAD_CERTTYPE = -8,
    WOLFSSL_BAD_STAT = -7,
    WOLFSSL_BAD_PATH = -6,
    WOLFSSL_BAD_FILETYPE = -5,
    WOLFSSL_BAD_FILE = -4,
    WOLFSSL_NOT_IMPLEMENTED = -3,
    WOLFSSL_UNKNOWN = -2,
    WOLFSSL_FATAL_ERROR = -1,

    WOLFSSL_FILETYPE_ASN1 = Ctc_Misc.CTC_FILETYPE_ASN1,
    WOLFSSL_FILETYPE_PEM = Ctc_Misc.CTC_FILETYPE_PEM,
    WOLFSSL_FILETYPE_DEFAULT = Ctc_Misc.CTC_FILETYPE_ASN1, /* ASN1 */

    WOLFSSL_VERIFY_NONE = 0,
    WOLFSSL_VERIFY_PEER = 1 << 0,
    WOLFSSL_VERIFY_FAIL_IF_NO_PEER_CERT = 1 << 1,
    WOLFSSL_VERIFY_CLIENT_ONCE = 1 << 2,
    WOLFSSL_VERIFY_POST_HANDSHAKE = 1 << 3,
    WOLFSSL_VERIFY_FAIL_EXCEPT_PSK = 1 << 4,
    WOLFSSL_VERIFY_DEFAULT = 1 << 9,

    WOLFSSL_SESS_CACHE_OFF = 0x0000,
    WOLFSSL_SESS_CACHE_CLIENT = 0x0001,
    WOLFSSL_SESS_CACHE_SERVER = 0x0002,
    WOLFSSL_SESS_CACHE_BOTH = 0x0003,
    WOLFSSL_SESS_CACHE_NO_AUTO_CLEAR = 0x0008,
    WOLFSSL_SESS_CACHE_NO_INTERNAL_LOOKUP = 0x0100,
    WOLFSSL_SESS_CACHE_NO_INTERNAL_STORE = 0x0200,
    WOLFSSL_SESS_CACHE_NO_INTERNAL = 0x0300,

    WOLFSSL_ERROR_WANT_READ = 2,
    WOLFSSL_ERROR_WANT_WRITE = 3,
    WOLFSSL_ERROR_WANT_CONNECT = 7,
    WOLFSSL_ERROR_WANT_ACCEPT = 8,
    WOLFSSL_ERROR_SYSCALL = 5,
    WOLFSSL_ERROR_WANT_X509_LOOKUP = 83,
    WOLFSSL_ERROR_ZERO_RETURN = 6,
    WOLFSSL_ERROR_SSL = 85,

    WOLFSSL_SENT_SHUTDOWN = 1,
    WOLFSSL_RECEIVED_SHUTDOWN = 2,
    WOLFSSL_MODE_ACCEPT_MOVING_WRITE_BUFFER = 4,

    WOLFSSL_R_SSL_HANDSHAKE_FAILURE = 101,
    WOLFSSL_R_TLSV1_ALERT_UNKNOWN_CA = 102,
    WOLFSSL_R_SSLV3_ALERT_CERTIFICATE_UNKNOWN = 103,
    WOLFSSL_R_SSLV3_ALERT_BAD_CERTIFICATE = 104,

    WOLF_PEM_BUFSIZE = 1024
}

alias wc_psk_client_callback = uint function (
    WOLFSSL* ssl,
    const(char)*,
    char*,
    uint,
    ubyte*,
    uint);
void wolfSSL_CTX_set_psk_client_callback (
    WOLFSSL_CTX* ctx,
    wc_psk_client_callback cb);
void wolfSSL_set_psk_client_callback (WOLFSSL* ssl, wc_psk_client_callback cb);

const(char)* wolfSSL_get_psk_identity_hint (const(WOLFSSL)* ssl);
const(char)* wolfSSL_get_psk_identity (const(WOLFSSL)* ssl);

int wolfSSL_CTX_use_psk_identity_hint (WOLFSSL_CTX* ctx, const(char)* hint);
int wolfSSL_use_psk_identity_hint (WOLFSSL* ssl, const(char)* hint);

alias wc_psk_server_callback = uint function (
    WOLFSSL* ssl,
    const(char)*,
    ubyte*,
    uint);
void wolfSSL_CTX_set_psk_server_callback (
    WOLFSSL_CTX* ctx,
    wc_psk_server_callback cb);
void wolfSSL_set_psk_server_callback (WOLFSSL* ssl, wc_psk_server_callback cb);

void* wolfSSL_get_psk_callback_ctx (WOLFSSL* ssl);
int wolfSSL_set_psk_callback_ctx (WOLFSSL* ssl, void* psk_ctx);

void* wolfSSL_CTX_get_psk_callback_ctx (WOLFSSL_CTX* ctx);
int wolfSSL_CTX_set_psk_callback_ctx (WOLFSSL_CTX* ctx, void* psk_ctx);

/* NO_PSK */

/* HAVE_ANON */

/* extra begins */

/* ERR Constants */

/* bio misc */

/* default BIO write size if not set */

void wolfSSL_ERR_put_error (
    int lib,
    int fun,
    int err,
    const(char)* file,
    int line);
@trusted c_ulong wolfSSL_ERR_get_error_line (const(char*)* file, int* line);
@trusted c_ulong wolfSSL_ERR_get_error_line_data (
    const(char*)* file,
    int* line,
    const(char*)* data,
    int* flags);

@trusted c_ulong wolfSSL_ERR_get_error ();
@trusted void wolfSSL_ERR_clear_error ();

int wolfSSL_RAND_status ();
int wolfSSL_RAND_pseudo_bytes (ubyte* buf, int num);
int wolfSSL_RAND_bytes (ubyte* buf, int num);
c_long wolfSSL_CTX_set_options (WOLFSSL_CTX* ctx, c_long opt);
c_long wolfSSL_CTX_get_options (WOLFSSL_CTX* ctx);
c_long wolfSSL_CTX_clear_options (WOLFSSL_CTX* ctx, c_long opt);

int wolfSSL_CTX_check_private_key (const(WOLFSSL_CTX)* ctx);

WOLFSSL_EVP_PKEY* wolfSSL_CTX_get0_privatekey (const(WOLFSSL_CTX)* ctx);

void wolfSSL_ERR_free_strings ();
void wolfSSL_ERR_remove_state (c_ulong id);
int wolfSSL_clear (WOLFSSL* ssl);
int wolfSSL_state (WOLFSSL* ssl);

void wolfSSL_cleanup_all_ex_data ();
c_long wolfSSL_CTX_set_mode (WOLFSSL_CTX* ctx, c_long mode);
c_long wolfSSL_CTX_clear_mode (WOLFSSL_CTX* ctx, c_long mode);
c_long wolfSSL_CTX_get_mode (WOLFSSL_CTX* ctx);
void wolfSSL_CTX_set_default_read_ahead (WOLFSSL_CTX* ctx, int m);
c_long wolfSSL_SSL_get_mode (WOLFSSL* ssl);

int wolfSSL_CTX_set_default_verify_paths (WOLFSSL_CTX* ctx);
const(char)* wolfSSL_X509_get_default_cert_file_env ();
const(char)* wolfSSL_X509_get_default_cert_file ();
const(char)* wolfSSL_X509_get_default_cert_dir_env ();
const(char)* wolfSSL_X509_get_default_cert_dir ();
int wolfSSL_CTX_set_session_id_context (
    WOLFSSL_CTX* ctx,
    const(ubyte)* sid_ctx,
    uint sid_ctx_len);
WOLFSSL_X509* wolfSSL_get_peer_certificate (WOLFSSL* ssl);

int wolfSSL_want_read (WOLFSSL* ssl);
int wolfSSL_want_write (WOLFSSL* ssl);

/* var_arg */
int wolfSSL_BIO_vprintf (WOLFSSL_BIO* bio, const(char)* format, va_list args);
int wolfSSL_BIO_printf (WOLFSSL_BIO* bio, const(char)* format, ...);
int wolfSSL_BIO_dump (WOLFSSL_BIO* bio, const(char)* buf, int length);
int wolfSSL_ASN1_UTCTIME_print (WOLFSSL_BIO* bio, const(WOLFSSL_ASN1_TIME)* a);
int wolfSSL_ASN1_GENERALIZEDTIME_print (
    WOLFSSL_BIO* bio,
    const(WOLFSSL_ASN1_TIME)* asnTime);
void wolfSSL_ASN1_GENERALIZEDTIME_free (WOLFSSL_ASN1_TIME*);
int wolfSSL_ASN1_TIME_check (const(WOLFSSL_ASN1_TIME)* a);
int wolfSSL_ASN1_TIME_diff (
    int* days,
    int* secs,
    const(WOLFSSL_ASN1_TIME)* from,
    const(WOLFSSL_ASN1_TIME)* to);
int wolfSSL_ASN1_TIME_compare (
    const(WOLFSSL_ASN1_TIME)* a,
    const(WOLFSSL_ASN1_TIME)* b);

int wolfSSL_sk_num (const(WOLFSSL_STACK)* sk);
void* wolfSSL_sk_value (const(WOLFSSL_STACK)* sk, int i);

/* stunnel 4.28 needs */
void* wolfSSL_CTX_get_ex_data (const(WOLFSSL_CTX)* ctx, int idx);
int wolfSSL_CTX_set_ex_data (WOLFSSL_CTX* ctx, int idx, void* data);

void wolfSSL_CTX_sess_set_get_cb (
    WOLFSSL_CTX* ctx,
    WOLFSSL_SESSION* function (WOLFSSL* ssl, const(ubyte)*, int, int*) f);
void wolfSSL_CTX_sess_set_new_cb (
    WOLFSSL_CTX* ctx,
    int function (WOLFSSL* ssl, WOLFSSL_SESSION*) f);
void wolfSSL_CTX_sess_set_remove_cb (
    WOLFSSL_CTX* ctx,
    void function (WOLFSSL_CTX* ctx, WOLFSSL_SESSION*) f);

int wolfSSL_i2d_SSL_SESSION (WOLFSSL_SESSION* sess, ubyte** p);
WOLFSSL_SESSION* wolfSSL_d2i_SSL_SESSION (
    WOLFSSL_SESSION** sess,
    const(ubyte*)* p,
    c_long i);

int wolfSSL_SESSION_has_ticket (const(WOLFSSL_SESSION)* session);
c_ulong wolfSSL_SESSION_get_ticket_lifetime_hint (const(WOLFSSL_SESSION)* sess);
c_long wolfSSL_SESSION_get_timeout (const(WOLFSSL_SESSION)* session);
c_long wolfSSL_SESSION_get_time (const(WOLFSSL_SESSION)* session);
int wolfSSL_CTX_get_ex_new_index (c_long idx, void* arg, void* a, void* b, void* c);

/* extra ends */

/* wolfSSL extensions */

/* call before SSL_connect, if verifying will add name check to
   date check and signature check */
int wolfSSL_check_domain_name (WOLFSSL* ssl, const(char)* dn);

/* need to call once to load library (session cache) */
int wolfSSL_Init ();
/* call when done to cleanup/free session cache mutex / resources  */
int wolfSSL_Cleanup ();

/* which library version do we have */
const(char)* wolfSSL_lib_version ();

const(char)* wolfSSL_OpenSSL_version ();

/* which library version do we have in hex */
word32 wolfSSL_lib_version_hex ();

/* do accept or connect depedning on side */
int wolfSSL_negotiate (WOLFSSL* ssl);
/* turn on wolfSSL data compression */
int wolfSSL_set_compression (WOLFSSL* ssl);

int wolfSSL_set_timeout (WOLFSSL* ssl, uint to);
int wolfSSL_CTX_set_timeout (WOLFSSL_CTX* ctx, uint to);
void wolfSSL_CTX_set_current_time_cb (
    WOLFSSL_CTX* ctx,
    void function (const(WOLFSSL)* ssl, WOLFSSL_TIMEVAL* out_clock) cb);

/* get wolfSSL peer X509_CHAIN */
WOLFSSL_X509_CHAIN* wolfSSL_get_peer_chain (WOLFSSL* ssl);

/* get wolfSSL alternate peer X509_CHAIN */

/* peer chain count */
int wolfSSL_get_chain_count (WOLFSSL_X509_CHAIN* chain);
/* index cert length */
int wolfSSL_get_chain_length (WOLFSSL_X509_CHAIN* chain, int idx);
/* index cert */
ubyte* wolfSSL_get_chain_cert (WOLFSSL_X509_CHAIN* chain, int idx);
/* index cert in X509 */
WOLFSSL_X509* wolfSSL_get_chain_X509 (WOLFSSL_X509_CHAIN* chain, int idx);
/* free X509 */
alias wolfSSL_FreeX509 = wolfSSL_X509_free;
void wolfSSL_X509_free (WOLFSSL_X509* x509);
/* get index cert in PEM */
int wolfSSL_get_chain_cert_pem (
    WOLFSSL_X509_CHAIN* chain,
    int idx,
    ubyte* buf,
    int inLen,
    int* outLen);
const(ubyte)* wolfSSL_get_sessionID (const(WOLFSSL_SESSION)* s);
int wolfSSL_X509_get_serial_number (WOLFSSL_X509* x509, ubyte* in_, int* inOutSz);
char* wolfSSL_X509_get_subjectCN (WOLFSSL_X509* x509);
const(ubyte)* wolfSSL_X509_get_der (WOLFSSL_X509* x509, int* outSz);
const(ubyte)* wolfSSL_X509_get_tbs (WOLFSSL_X509* x509, int* outSz);
const(ubyte)* wolfSSL_X509_notBefore (WOLFSSL_X509* x509);
const(ubyte)* wolfSSL_X509_notAfter (WOLFSSL_X509* x509);
int wolfSSL_X509_version (WOLFSSL_X509* x509);

int wolfSSL_cmp_peer_cert_to_file (WOLFSSL* ssl, const(char)* fname);

char* wolfSSL_X509_get_next_altname (WOLFSSL_X509* cert);
int wolfSSL_X509_add_altname_ex (WOLFSSL_X509* x509, const(char)* name, word32 nameSz, int type);
int wolfSSL_X509_add_altname (WOLFSSL_X509* x509, const(char)* name, int type);

WOLFSSL_X509* wolfSSL_d2i_X509 (
    WOLFSSL_X509** x509,
    const(ubyte*)* in_,
    int len);
WOLFSSL_X509* wolfSSL_X509_d2i (
    WOLFSSL_X509** x509,
    const(ubyte)* in_,
    int len);

int wolfSSL_i2d_X509 (WOLFSSL_X509* x509, ubyte** out_);
WOLFSSL_X509_CRL* wolfSSL_d2i_X509_CRL (
    WOLFSSL_X509_CRL** crl,
    const(ubyte)* in_,
    int len);
WOLFSSL_X509_CRL* wolfSSL_d2i_X509_CRL_bio (
    WOLFSSL_BIO* bp,
    WOLFSSL_X509_CRL** crl);

WOLFSSL_X509_CRL* wolfSSL_d2i_X509_CRL_fp (FILE* file, WOLFSSL_X509_CRL** crl);

WOLFSSL_X509* wolfSSL_X509_d2i_fp (WOLFSSL_X509** x509, FILE* file);

WOLFSSL_X509* wolfSSL_X509_load_certificate_file (
    const(char)* fname,
    int format);

WOLFSSL_X509* wolfSSL_X509_load_certificate_buffer (
    const(ubyte)* buf,
    int sz,
    int format);

/* connect enough to get peer cert */
@trusted int wolfSSL_connect_cert (WOLFSSL* ssl);

/* PKCS12 compatibility */
WC_PKCS12* wolfSSL_d2i_PKCS12_bio (WOLFSSL_BIO* bio, WC_PKCS12** pkcs12);
int wolfSSL_i2d_PKCS12_bio (WOLFSSL_BIO* bio, WC_PKCS12* pkcs12);

WOLFSSL_X509_PKCS12* wolfSSL_d2i_PKCS12_fp (
    FILE* fp,
    WOLFSSL_X509_PKCS12** pkcs12);

int wolfSSL_PKCS12_parse (
    WC_PKCS12* pkcs12,
    const(char)* psw,
    WOLFSSL_EVP_PKEY** pkey,
    WOLFSSL_X509** cert,
    WOLFSSL_STACK** ca);
int wolfSSL_PKCS12_verify_mac (WC_PKCS12* pkcs12, const(char)* psw, int pswLen);
WC_PKCS12* wolfSSL_PKCS12_create (
    char* pass,
    char* name,
    WOLFSSL_EVP_PKEY* pkey,
    WOLFSSL_X509* cert,
    WOLFSSL_STACK* ca,
    int keyNID,
    int certNID,
    int itt,
    int macItt,
    int keytype);
void wolfSSL_PKCS12_PBE_add ();

/* server Diffie-Hellman parameters */
int wolfSSL_SetTmpDH (
    WOLFSSL* ssl,
    const(ubyte)* p,
    int pSz,
    const(ubyte)* g,
    int gSz);
int wolfSSL_SetTmpDH_buffer (
    WOLFSSL* ssl,
    const(ubyte)* b,
    c_long sz,
    int format);
int wolfSSL_SetEnableDhKeyTest (WOLFSSL* ssl, int enable);

int wolfSSL_SetTmpDH_file (WOLFSSL* ssl, const(char)* f, int format);

/* server ctx Diffie-Hellman parameters */
int wolfSSL_CTX_SetTmpDH (
    WOLFSSL_CTX* ctx,
    const(ubyte)* p,
    int pSz,
    const(ubyte)* g,
    int gSz);
int wolfSSL_CTX_SetTmpDH_buffer (
    WOLFSSL_CTX* ctx,
    const(ubyte)* b,
    c_long sz,
    int format);

int wolfSSL_CTX_SetTmpDH_file (WOLFSSL_CTX* ctx, const(char)* f, int format);

int wolfSSL_CTX_SetMinDhKey_Sz (WOLFSSL_CTX* ctx, word16 keySz_bits);
int wolfSSL_SetMinDhKey_Sz (WOLFSSL* ssl, word16 keySz_bits);
int wolfSSL_CTX_SetMaxDhKey_Sz (WOLFSSL_CTX* ctx, word16 keySz_bits);
int wolfSSL_SetMaxDhKey_Sz (WOLFSSL* ssl, word16 keySz_bits);
int wolfSSL_GetDhKey_Sz (WOLFSSL* ssl);
/* NO_DH */

int wolfSSL_CTX_SetMinRsaKey_Sz (WOLFSSL_CTX* ctx, short keySz);
int wolfSSL_SetMinRsaKey_Sz (WOLFSSL* ssl, short keySz);
/* NO_RSA */

/* NO_RSA */

int wolfSSL_SetTmpEC_DHE_Sz (WOLFSSL* ssl, word16 sz);
int wolfSSL_CTX_SetTmpEC_DHE_Sz (WOLFSSL_CTX* ctx, word16 sz);

/* keyblock size in bytes or -1 */
/* need to call wolfSSL_KeepArrays before handshake to save keys */
int wolfSSL_get_keyblock_size (WOLFSSL* ssl);
int wolfSSL_get_keys (
    WOLFSSL* ssl,
    ubyte** ms,
    uint* msLen,
    ubyte** sr,
    uint* srLen,
    ubyte** cr,
    uint* crLen);

/* Computes EAP-TLS and EAP-TTLS keying material from the master_secret. */
int wolfSSL_make_eap_keys (
    WOLFSSL* ssl,
    void* key,
    uint len,
    const(char)* label);

/* allow writev style writing */
@trusted int wolfSSL_writev (WOLFSSL* ssl, const(iovec)* iov, int iovcnt);

/* SSL_CTX versions */
int wolfSSL_CTX_UnloadCAs (WOLFSSL_CTX* ctx);

int wolfSSL_CTX_load_verify_buffer_ex (
    WOLFSSL_CTX* ctx,
    const(ubyte)* in_,
    c_long sz,
    int format,
    int userChain,
    word32 flags);
int wolfSSL_CTX_load_verify_buffer (
    WOLFSSL_CTX* ctx,
    const(ubyte)* in_,
    c_long sz,
    int format);
int wolfSSL_CTX_load_verify_chain_buffer_format (
    WOLFSSL_CTX* ctx,
    const(ubyte)* in_,
    c_long sz,
    int format);
int wolfSSL_CTX_use_certificate_buffer (
    WOLFSSL_CTX* ctx,
    const(ubyte)* in_,
    c_long sz,
    int format);
int wolfSSL_CTX_use_PrivateKey_buffer (
    WOLFSSL_CTX* ctx,
    const(ubyte)* in_,
    c_long sz,
    int format);
int wolfSSL_CTX_use_PrivateKey_id (
    WOLFSSL_CTX* ctx,
    const(ubyte)* id,
    c_long sz,
    int devId,
    c_long keySz);
int wolfSSL_CTX_use_PrivateKey_Id (
    WOLFSSL_CTX* ctx,
    const(ubyte)* id,
    c_long sz,
    int devId);
int wolfSSL_CTX_use_PrivateKey_Label (
    WOLFSSL_CTX* ctx,
    const(char)* label,
    int devId);
int wolfSSL_CTX_use_certificate_chain_buffer_format (
    WOLFSSL_CTX* ctx,
    const(ubyte)* in_,
    c_long sz,
    int format);
int wolfSSL_CTX_use_certificate_chain_buffer (
    WOLFSSL_CTX* ctx,
    const(ubyte)* in_,
    c_long sz);

/* SSL versions */
int wolfSSL_use_certificate_buffer (
    WOLFSSL* ssl,
    const(ubyte)* in_,
    c_long sz,
    int format);
int wolfSSL_use_certificate_ASN1 (WOLFSSL* ssl, const(ubyte)* der, int derSz);
int wolfSSL_use_PrivateKey_buffer (
    WOLFSSL* ssl,
    const(ubyte)* in_,
    c_long sz,
    int format);
int wolfSSL_use_PrivateKey_id (
    WOLFSSL* ssl,
    const(ubyte)* id,
    c_long sz,
    int devId,
    c_long keySz);
int wolfSSL_use_PrivateKey_Id (
    WOLFSSL* ssl,
    const(ubyte)* id,
    c_long sz,
    int devId);
int wolfSSL_use_PrivateKey_Label (WOLFSSL* ssl, const(char)* label, int devId);
int wolfSSL_use_certificate_chain_buffer_format (
    WOLFSSL* ssl,
    const(ubyte)* in_,
    c_long sz,
    int format);
int wolfSSL_use_certificate_chain_buffer (
    WOLFSSL* ssl,
    const(ubyte)* in_,
    c_long sz);
int wolfSSL_UnloadCertsKeys (WOLFSSL* ssl);

int wolfSSL_CTX_set_group_messages (WOLFSSL_CTX* ctx);
int wolfSSL_set_group_messages (WOLFSSL* ssl);

int wolfSSL_DTLS_SetCookieSecret (WOLFSSL* ssl, const(ubyte)* secret, word32 secretSz);

/* I/O Callback default errors */
enum IOerrors
{
    WOLFSSL_CBIO_ERR_GENERAL = -1, /* general unexpected err */
    WOLFSSL_CBIO_ERR_WANT_READ = -2, /* need to call read  again */
    WOLFSSL_CBIO_ERR_WANT_WRITE = -2, /* need to call write again */
    WOLFSSL_CBIO_ERR_CONN_RST = -3, /* connection reset */
    WOLFSSL_CBIO_ERR_ISR = -4, /* interrupt */
    WOLFSSL_CBIO_ERR_CONN_CLOSE = -5, /* connection closed or epipe */
    WOLFSSL_CBIO_ERR_TIMEOUT = -6 /* socket timeout */
}

/* CA cache callbacks */
enum
{
    WOLFSSL_SSLV3 = 0,
    WOLFSSL_TLSV1 = 1,
    WOLFSSL_TLSV1_1 = 2,
    WOLFSSL_TLSV1_2 = 3,
    WOLFSSL_TLSV1_3 = 4,
    WOLFSSL_DTLSV1 = 5,
    WOLFSSL_DTLSV1_2 = 6,
    WOLFSSL_DTLSV1_3 = 7,

    WOLFSSL_USER_CA = 1, /* user added as trusted */
    WOLFSSL_CHAIN_CA = 2 /* added to cache from trusted chain */
}

WC_RNG* wolfSSL_GetRNG (WOLFSSL* ssl);

int wolfSSL_CTX_SetMinVersion (WOLFSSL_CTX* ctx, int version_);
int wolfSSL_SetMinVersion (WOLFSSL* ssl, int version_);
int wolfSSL_GetObjectSize (); /* object size based on build */
int wolfSSL_CTX_GetObjectSize ();
int wolfSSL_METHOD_GetObjectSize ();
int wolfSSL_GetOutputSize (WOLFSSL* ssl, int inSz);
int wolfSSL_GetMaxOutputSize (WOLFSSL* ssl);
int wolfSSL_GetVersion (const(WOLFSSL)* ssl);
int wolfSSL_SetVersion (WOLFSSL* ssl, int version_);

/* moved to asn.c, old names kept for backwards compatibility */
alias wolfSSL_KeyPemToDer = wc_KeyPemToDer;
alias wolfSSL_CertPemToDer = wc_CertPemToDer;
alias wolfSSL_PemPubKeyToDer = wc_PemPubKeyToDer;
alias wolfSSL_PubKeyPemToDer = wc_PubKeyPemToDer;
// DSTEP: alias wolfSSL_PemCertToDer = wc_PemCertToDer;

alias CallbackCACache = void function (ubyte* der, int sz, int type);
alias CbMissingCRL = void function (const(char)* url);
alias CbOCSPIO = int function (void*, const(char)*, int, ubyte*, int, ubyte**);
alias CbOCSPRespFree = void function (void*, ubyte*);

/* User Atomic Record Layer CallBacks */
alias CallbackMacEncrypt = int function (
    WOLFSSL* ssl,
    ubyte* macOut,
    const(ubyte)* macIn,
    uint macInSz,
    int macContent,
    int macVerify,
    ubyte* encOut,
    const(ubyte)* encIn,
    uint encSz,
    void* ctx);
void wolfSSL_CTX_SetMacEncryptCb (WOLFSSL_CTX* ctx, CallbackMacEncrypt cb);
void wolfSSL_SetMacEncryptCtx (WOLFSSL* ssl, void* ctx);
void* wolfSSL_GetMacEncryptCtx (WOLFSSL* ssl);

alias CallbackDecryptVerify = int function (
    WOLFSSL* ssl,
    ubyte* decOut,
    const(ubyte)* decIn,
    uint decSz,
    int content,
    int verify,
    uint* padSz,
    void* ctx);
void wolfSSL_CTX_SetDecryptVerifyCb (
    WOLFSSL_CTX* ctx,
    CallbackDecryptVerify cb);
void wolfSSL_SetDecryptVerifyCtx (WOLFSSL* ssl, void* ctx);
void* wolfSSL_GetDecryptVerifyCtx (WOLFSSL* ssl);

alias CallbackEncryptMac = int function (
    WOLFSSL* ssl,
    ubyte* macOut,
    int content,
    int macVerify,
    ubyte* encOut,
    const(ubyte)* encIn,
    uint encSz,
    void* ctx);
void wolfSSL_CTX_SetEncryptMacCb (WOLFSSL_CTX* ctx, CallbackEncryptMac cb);
void wolfSSL_SetEncryptMacCtx (WOLFSSL* ssl, void* ctx);
void* wolfSSL_GetEncryptMacCtx (WOLFSSL* ssl);

alias CallbackVerifyDecrypt = int function (
    WOLFSSL* ssl,
    ubyte* decOut,
    const(ubyte)* decIn,
    uint decSz,
    int content,
    int verify,
    uint* padSz,
    void* ctx);
void wolfSSL_CTX_SetVerifyDecryptCb (
    WOLFSSL_CTX* ctx,
    CallbackVerifyDecrypt cb);
void wolfSSL_SetVerifyDecryptCtx (WOLFSSL* ssl, void* ctx);
void* wolfSSL_GetVerifyDecryptCtx (WOLFSSL* ssl);

const(ubyte)* wolfSSL_GetMacSecret (WOLFSSL* ssl, int verify);
const(ubyte)* wolfSSL_GetDtlsMacSecret (WOLFSSL* ssl, int verify, int epochOrder);
const(ubyte)* wolfSSL_GetClientWriteKey (WOLFSSL* ssl);
const(ubyte)* wolfSSL_GetClientWriteIV (WOLFSSL* ssl);
const(ubyte)* wolfSSL_GetServerWriteKey (WOLFSSL* ssl);
const(ubyte)* wolfSSL_GetServerWriteIV (WOLFSSL* ssl);
int wolfSSL_GetKeySize (WOLFSSL* ssl);
int wolfSSL_GetIVSize (WOLFSSL* ssl);
int wolfSSL_GetSide (WOLFSSL* ssl);
int wolfSSL_IsTLSv1_1 (WOLFSSL* ssl);
int wolfSSL_GetBulkCipher (WOLFSSL* ssl);
int wolfSSL_GetCipherBlockSize (WOLFSSL* ssl);
int wolfSSL_GetAeadMacSize (WOLFSSL* ssl);
int wolfSSL_GetHmacSize (WOLFSSL* ssl);
int wolfSSL_GetHmacType (WOLFSSL* ssl);
int wolfSSL_GetPeerSequenceNumber (WOLFSSL* ssl, word64* seq);
int wolfSSL_GetSequenceNumber (WOLFSSL* ssl, word64* seq);

int wolfSSL_GetCipherType (WOLFSSL* ssl);
int wolfSSL_SetTlsHmacInner (
    WOLFSSL* ssl,
    ubyte* inner,
    word32 sz,
    int content,
    int verify);

/* Atomic User Needs */
enum
{
    WOLFSSL_SERVER_END = 0,
    WOLFSSL_CLIENT_END = 1,
    WOLFSSL_NEITHER_END = 3,
    WOLFSSL_BLOCK_TYPE = 2,
    WOLFSSL_STREAM_TYPE = 3,
    WOLFSSL_AEAD_TYPE = 4,
    WOLFSSL_TLS_HMAC_INNER_SZ = 13 /* SEQ_SZ + ENUM + VERSION_SZ + LEN_SZ */
}

/* for GetBulkCipher and internal use
 * using explicit values to assist with serialization of a TLS session */
enum BulkCipherAlgorithm
{
    wolfssl_cipher_null = 0,
    wolfssl_rc4 = 1,
    wolfssl_rc2 = 2,
    wolfssl_des = 3,
    wolfssl_triple_des = 4,
    wolfssl_des40 = 5,
    wolfssl_aes = 6,
    wolfssl_aes_gcm = 7,
    wolfssl_aes_ccm = 8,
    wolfssl_chacha = 9,
    wolfssl_camellia = 10
}

/* for KDF TLS 1.2 mac types */
enum KDF_MacAlgorithm
{
    wolfssl_sha256 = 4, /* needs to match hash.h wc_MACAlgorithm */
    wolfssl_sha384 = 5,
    wolfssl_sha512 = 6
}

/* Public Key Callback support */

/* side is WOLFSSL_CLIENT_END or WOLFSSL_SERVER_END */

/* Public DH Key Callback support */

/* !NO_DH */

/* side is WOLFSSL_CLIENT_END or WOLFSSL_SERVER_END */

/* side is WOLFSSL_CLIENT_END or WOLFSSL_SERVER_END */

/* RSA Public Encrypt cb */

/* RSA Private Decrypt cb */

/* Protocol Callback */

/* HAVE_PK_CALLBACKS */

void wolfSSL_CTX_SetCACb (WOLFSSL_CTX* ctx, CallbackCACache cb);

WOLFSSL_CERT_MANAGER* wolfSSL_CTX_GetCertManager (WOLFSSL_CTX* ctx);

WOLFSSL_CERT_MANAGER* wolfSSL_CertManagerNew_ex (void* heap);
WOLFSSL_CERT_MANAGER* wolfSSL_CertManagerNew ();
void wolfSSL_CertManagerFree (WOLFSSL_CERT_MANAGER* cm);
int wolfSSL_CertManager_up_ref (WOLFSSL_CERT_MANAGER* cm);

int wolfSSL_CertManagerLoadCA (
    WOLFSSL_CERT_MANAGER* cm,
    const(char)* f,
    const(char)* d);
int wolfSSL_CertManagerLoadCABuffer (
    WOLFSSL_CERT_MANAGER* cm,
    const(ubyte)* in_,
    c_long sz,
    int format);
int wolfSSL_CertManagerUnloadCAs (WOLFSSL_CERT_MANAGER* cm);

int wolfSSL_CertManagerVerify (
    WOLFSSL_CERT_MANAGER* cm,
    const(char)* f,
    int format);
int wolfSSL_CertManagerVerifyBuffer (
    WOLFSSL_CERT_MANAGER* cm,
    const(ubyte)* buff,
    c_long sz,
    int format);
int wolfSSL_CertManagerCheckCRL (WOLFSSL_CERT_MANAGER* cm, ubyte* der, int sz);
int wolfSSL_CertManagerEnableCRL (WOLFSSL_CERT_MANAGER* cm, int options);
int wolfSSL_CertManagerDisableCRL (WOLFSSL_CERT_MANAGER* cm);
void wolfSSL_CertManagerSetVerify (WOLFSSL_CERT_MANAGER* cm, VerifyCallback vc);
int wolfSSL_CertManagerLoadCRL (
    WOLFSSL_CERT_MANAGER* cm,
    const(char)* path,
    int type,
    int monitor);
int wolfSSL_CertManagerLoadCRLFile (
    WOLFSSL_CERT_MANAGER* cm,
    const(char)* file,
    int type);
int wolfSSL_CertManagerLoadCRLBuffer (
    WOLFSSL_CERT_MANAGER* cm,
    const(ubyte)* buff,
    c_long sz,
    int type);
int wolfSSL_CertManagerSetCRL_Cb (WOLFSSL_CERT_MANAGER* cm, CbMissingCRL cb);
int wolfSSL_CertManagerFreeCRL (WOLFSSL_CERT_MANAGER* cm);

int wolfSSL_CertManagerCheckOCSP (WOLFSSL_CERT_MANAGER* cm, ubyte* der, int sz);
int wolfSSL_CertManagerEnableOCSP (WOLFSSL_CERT_MANAGER* cm, int options);
int wolfSSL_CertManagerDisableOCSP (WOLFSSL_CERT_MANAGER* cm);
int wolfSSL_CertManagerSetOCSPOverrideURL (
    WOLFSSL_CERT_MANAGER* cm,
    const(char)* url);
int wolfSSL_CertManagerSetOCSP_Cb (
    WOLFSSL_CERT_MANAGER* cm,
    CbOCSPIO ioCb,
    CbOCSPRespFree respFreeCb,
    void* ioCbCtx);

int wolfSSL_CertManagerEnableOCSPStapling (WOLFSSL_CERT_MANAGER* cm);
int wolfSSL_CertManagerDisableOCSPStapling (WOLFSSL_CERT_MANAGER* cm);
int wolfSSL_CertManagerEnableOCSPMustStaple (WOLFSSL_CERT_MANAGER* cm);
int wolfSSL_CertManagerDisableOCSPMustStaple (WOLFSSL_CERT_MANAGER* cm);

/* OPENSSL_EXTRA && WOLFSSL_SIGNER_DER_CERT && !NO_FILESYSTEM */
int wolfSSL_EnableCRL (WOLFSSL* ssl, int options);
int wolfSSL_DisableCRL (WOLFSSL* ssl);
int wolfSSL_LoadCRL (WOLFSSL* ssl, const(char)* path, int type, int monitor);
int wolfSSL_LoadCRLFile (WOLFSSL* ssl, const(char)* file, int type);
int wolfSSL_LoadCRLBuffer (
    WOLFSSL* ssl,
    const(ubyte)* buff,
    c_long sz,
    int type);
int wolfSSL_SetCRL_Cb (WOLFSSL* ssl, CbMissingCRL cb);

int wolfSSL_EnableOCSP (WOLFSSL* ssl, int options);
int wolfSSL_DisableOCSP (WOLFSSL* ssl);
int wolfSSL_SetOCSP_OverrideURL (WOLFSSL* ssl, const(char)* url);
int wolfSSL_SetOCSP_Cb (WOLFSSL* ssl, CbOCSPIO ioCb, CbOCSPRespFree respFreeCb, void* ioCbCtx);
int wolfSSL_EnableOCSPStapling (WOLFSSL* ssl);
int wolfSSL_DisableOCSPStapling (WOLFSSL* ssl);

int wolfSSL_CTX_EnableCRL (WOLFSSL_CTX* ctx, int options);
int wolfSSL_CTX_DisableCRL (WOLFSSL_CTX* ctx);
int wolfSSL_CTX_LoadCRL (WOLFSSL_CTX* ctx, const(char)* path, int type, int monitor);
int wolfSSL_CTX_LoadCRLFile (WOLFSSL_CTX* ctx, const(char)* path, int type);
int wolfSSL_CTX_LoadCRLBuffer (
    WOLFSSL_CTX* ctx,
    const(ubyte)* buff,
    c_long sz,
    int type);
int wolfSSL_CTX_SetCRL_Cb (WOLFSSL_CTX* ctx, CbMissingCRL cb);

int wolfSSL_CTX_EnableOCSP (WOLFSSL_CTX* ctx, int options);
int wolfSSL_CTX_DisableOCSP (WOLFSSL_CTX* ctx);
int wolfSSL_CTX_SetOCSP_OverrideURL (WOLFSSL_CTX* ctx, const(char)* url);
int wolfSSL_CTX_SetOCSP_Cb (
    WOLFSSL_CTX* ctx,
    CbOCSPIO ioCb,
    CbOCSPRespFree respFreeCb,
    void* ioCbCtx);
int wolfSSL_CTX_EnableOCSPStapling (WOLFSSL_CTX* ctx);
int wolfSSL_CTX_DisableOCSPStapling (WOLFSSL_CTX* ctx);
int wolfSSL_CTX_EnableOCSPMustStaple (WOLFSSL_CTX* ctx);
int wolfSSL_CTX_DisableOCSPMustStaple (WOLFSSL_CTX* ctx);
/* !NO_CERTS */

/* end of handshake frees temporary arrays, if user needs for get_keys or
   psk hints, call KeepArrays before handshake and then FreeArrays when done
   if don't want to wait for object free */
void wolfSSL_KeepArrays (WOLFSSL* ssl);
void wolfSSL_FreeArrays (WOLFSSL* ssl);

int wolfSSL_KeepHandshakeResources (WOLFSSL* ssl);
int wolfSSL_FreeHandshakeResources (WOLFSSL* ssl);

int wolfSSL_CTX_UseClientSuites (WOLFSSL_CTX* ctx);
int wolfSSL_UseClientSuites (WOLFSSL* ssl);

/* async additions */
alias wolfSSL_UseAsync = wolfSSL_SetDevId;
alias wolfSSL_CTX_UseAsync = wolfSSL_CTX_SetDevId;
int wolfSSL_SetDevId (WOLFSSL* ssl, int devId);
int wolfSSL_CTX_SetDevId (WOLFSSL_CTX* ctx, int devId);

/* helpers to get device id and heap */
int wolfSSL_CTX_GetDevId (WOLFSSL_CTX* ctx, WOLFSSL* ssl);
void* wolfSSL_CTX_GetHeap (WOLFSSL_CTX* ctx, WOLFSSL* ssl);

/* TLS Extensions */

/* Server Name Indication */

/* SNI types */

/* SNI options */

/* Do not abort the handshake if the requested SNI didn't match. */

/* Behave as if the requested SNI matched in a case of mismatch.  */
/* In this case, the status will be set to WOLFSSL_SNI_FAKE_MATCH. */

/* Abort the handshake if the client didn't send a SNI request. */

/* NO_WOLFSSL_SERVER */

/* SNI status */

/**< @see WOLFSSL_SNI_ANSWER_ON_MISMATCH */

/** Used with -DWOLFSSL_ALWAYS_KEEP_SNI */

/* HAVE_SNI */

/* Trusted CA Key Indication - RFC 6066 (Section 6) */

/* TCA Identifier Type */

/* HAVE_TRUSTED_CA */

/* Application-Layer Protocol Negotiation */

/* ALPN status code */

/* HAVE_ALPN */

/* Maximum Fragment Length */

/* Fragment lengths */

/*  512 bytes */
/* 1024 bytes */
/* 2048 bytes */
/* 4096 bytes */
/* 8192 bytes */ /* wolfSSL ONLY!!! */
/*  256 bytes */ /* wolfSSL ONLY!!! */

/* HAVE_MAX_FRAGMENT */

/* Truncated HMAC */

/* Certificate Status Request */
/* Certificate Status Type */
enum
{
    WOLFSSL_CSR_OCSP = 1
}

/* Certificate Status Options (flags) */
enum
{
    WOLFSSL_CSR_OCSP_USE_NONCE = 0x01
}

/* Certificate Status Request v2 */
/* Certificate Status Type */
enum
{
    WOLFSSL_CSR2_OCSP = 1,
    WOLFSSL_CSR2_OCSP_MULTI = 2
}

/* Certificate Status v2 Options (flags) */
enum
{
    WOLFSSL_CSR2_OCSP_USE_NONCE = 0x01
}

/* Named Groups */
enum
{
    WOLFSSL_NAMED_GROUP_INVALID = 0,
    /* Not Supported */

    WOLFSSL_ECC_SECP160K1 = 15,
    WOLFSSL_ECC_SECP160R1 = 16,
    WOLFSSL_ECC_SECP160R2 = 17,
    WOLFSSL_ECC_SECP192K1 = 18,
    WOLFSSL_ECC_SECP192R1 = 19,
    WOLFSSL_ECC_SECP224K1 = 20,
    WOLFSSL_ECC_SECP224R1 = 21,
    WOLFSSL_ECC_SECP256K1 = 22,
    WOLFSSL_ECC_SECP256R1 = 23,
    WOLFSSL_ECC_SECP384R1 = 24,
    WOLFSSL_ECC_SECP521R1 = 25,
    WOLFSSL_ECC_BRAINPOOLP256R1 = 26,
    WOLFSSL_ECC_BRAINPOOLP384R1 = 27,
    WOLFSSL_ECC_BRAINPOOLP512R1 = 28,
    WOLFSSL_ECC_X25519 = 29,
    WOLFSSL_ECC_X448 = 30,
    WOLFSSL_ECC_MAX = 30,

    WOLFSSL_FFDHE_2048 = 256,
    WOLFSSL_FFDHE_3072 = 257,
    WOLFSSL_FFDHE_4096 = 258,
    WOLFSSL_FFDHE_6144 = 259,
    WOLFSSL_FFDHE_8192 = 260

    /* These group numbers were taken from OQS's openssl fork, see:
     * https://github.com/open-quantum-safe/openssl/blob/OQS-OpenSSL_1_1_1-stable/
     * oqs-template/oqs-kem-info.md.
     *
     * The levels in the group name refer to the claimed NIST level of each
     * parameter set. The associated parameter set name is listed as a comment
     * beside the group number. Please see the NIST PQC Competition's submitted
     * papers for more details.
     *
     * LEVEL1 means that an attack on that parameter set would reqire the same
     * or more resources as a key search on AES 128. LEVEL3 would reqire the
     * same or more resources as a key search on AES 192. LEVEL5 would require
     * the same or more resources as a key search on AES 256. None of the
     * algorithms have LEVEL2 and LEVEL4 because none of these submissions
     * included them. */

    /* NTRU_HPS2048509 */
    /* NTRU_HPS2048677 */
    /* NTRU_HPS4096821 */
    /* NTRU_HRSS701 */
    /* LIGHTSABER */
    /* SABER */
    /* FIRESABER */
    /* KYBER_512 */
    /* KYBER_768 */
    /* KYBER_1024 */
    /* KYBER_90S_512 */
    /* KYBER_90S_768 */
    /* KYBER_90S_1024 */
}

enum
{
    WOLFSSL_EC_PF_UNCOMPRESSED = 0
    /* Not Supported */
}

/* Secure Renegotiation */

/* Needed by session ticket stuff below */

/* Session Ticket */

/* NO_WOLFSSL_CLIENT */

/* !NO_WOLFSSL_SERVER */

/* fatal error, don't use ticket */
/* ok, use ticket */
/* don't use ticket, but not fatal */
/* existing ticket ok and create new one */

/* NO_WOLFSSL_SERVER */

/* HAVE_SESSION_TICKET */

/* TLS Extended Master Secret Extension */
int wolfSSL_DisableExtendedMasterSecret (WOLFSSL* ssl);
int wolfSSL_CTX_DisableExtendedMasterSecret (WOLFSSL_CTX* ctx);

enum WOLFSSL_CRL_MONITOR = 0x01; /* monitor this dir flag */
enum WOLFSSL_CRL_START_MON = 0x02; /* start monitoring flag */

/* notify user we parsed a verified ClientHello is done. This only has an effect
 * on the server end. */

/* notify user the handshake is done */
alias HandShakeDoneCb = int function (WOLFSSL* ssl, void*);
int wolfSSL_SetHsDoneCb (WOLFSSL* ssl, HandShakeDoneCb cb, void* user_ctx);

int wolfSSL_PrintSessionStats ();
int wolfSSL_get_session_stats (
    uint* active,
    uint* total,
    uint* peak,
    uint* maxSessions);
/* External facing KDF */
int wolfSSL_MakeTlsMasterSecret (
    ubyte* ms,
    word32 msLen,
    const(ubyte)* pms,
    word32 pmsLen,
    const(ubyte)* cr,
    const(ubyte)* sr,
    int tls1_2,
    int hash_type);

int wolfSSL_MakeTlsExtendedMasterSecret (
    ubyte* ms,
    word32 msLen,
    const(ubyte)* pms,
    word32 pmsLen,
    const(ubyte)* sHash,
    word32 sHashLen,
    int tls1_2,
    int hash_type);

int wolfSSL_DeriveTlsKeys (
    ubyte* key_data,
    word32 keyLen,
    const(ubyte)* ms,
    word32 msLen,
    const(ubyte)* sr,
    const(ubyte)* cr,
    int tls1_2,
    int hash_type);

/* wolfSSL connect extension allowing HandShakeCallBack and/or TimeoutCallBack
   for diagnostics */

/* WOLFSSL_CALLBACKS */

/* WOLFSSL_HAVE_WOLFSCEP */

/* Smaller subset of X509 compatibility functions. Avoid increasing the size of
 * this subset and its memory usage */

/* static object just for keeping grp, type */
/* points to data, for lighttpd port */
/* i.e. ASN_COMMON_NAME */

/* Object functions */

/* end of object functions */

/* !NO_CERTS */
/* OPENSSL_ALL || OPENSSL_EXTRA || OPENSSL_EXTRA_X509_SMALL */

/* OPENSSL_EXTRA || WOLFSSL_WPAS_SMALL */

/* !NO_CERTS */

/* OPENSSL_EXTRA || OPENSSL_ALL */

/* OPENSSL_EXTRA || WOLFSSL_WPAS_SMALL */

/* OPENSSL_EXTRA || WOLFSSL_WPAS_SMALL || HAVE_SECRET_CALLBACK */

/* non-standard API to determine if BIO supports "pending" */

/* OPENSSL_EXTRA || OPENSSL_ALL */

/*lighttp compatibility */

/* OPENSSL_EXTRA || WOLFSSL_WPAS_SMALL */

/* These are to be merged shortly */

/* OPENSSL_EXTRA || OPENSSL_ALL || HAVE_LIGHTY || WOLFSSL_MYSQL_COMPATIBLE || HAVE_STUNNEL || WOLFSSL_NGINX || WOLFSSL_HAPROXY */

/* OPENSSL_EXTRA || OPENSSL_ALL */

/* !NO_FILESYSTEM */
/* !NO_BIO */

/* HAVE_STUNNEL || HAVE_LIGHTY */

/* OPENSSL_ALL || HAVE_STUNNEL || WOLFSSL_NGINX || WOLFSSL_HAPROXY || OPENSSL_EXTRA || HAVE_LIGHTY */

/* OPENSSL_EXTRA || WOLFSSL_WPAS_SMALL */

int wolfSSL_version (WOLFSSL* ssl);

/* OPENSSL_ALL || HAVE_STUNNEL || WOLFSSL_NGINX || WOLFSSL_HAPROXY || OPENSSL_EXTRA || HAVE_LIGHTY */

/* OPENSSL_EXTRA || WOLFSSL_WPAS_SMALL */

/* OPENSSL_ALL || HAVE_STUNNEL || WOLFSSL_NGINX || WOLFSSL_HAPROXY || HAVE_LIGHTY */

/* SNI received callback type */

/* support for deprecated old name */

/* OPENSSL_ALL || HAVE_STUNNEL || WOLFSSL_NGINX || WOLFSSL_HAPROXY || HAVE_LIGHTY */

/* OPENSSL_EXTRA || WOLFSSL_WPAS_SMALL */

/* OPENSSL_EXTRA && HAVE_ECC */

/* WOLFSSL_JNI */

/* WOLFSSL_ASYNC_CRYPT */

alias Rem_Sess_Cb = void function (WOLFSSL_CTX*, WOLFSSL_SESSION*);

/* HAVE_SECRET_CALLBACK */

/* Not an OpenSSL API. */

/* Not an OpenSSL API. */

/* Not an OpenSSL API. */

/* OPENSSL_EXTRA || OPENSSL_EXTRA_X509_SMALL || WOLFSSL_WPAS_SMALL */

/* HAVE_OCSP || OPENSSL_EXTRA || OPENSSL_ALL || WOLFSSL_NGINX || WOLFSSL_HAPROXY */

/* OPENSSL_ALL || WOLFSSL_NGINX || WOLFSSL_HAPROXY ||
OPENSSL_EXTRA || HAVE_LIGHTY */

void wolfSSL_get0_alpn_selected (
    const(WOLFSSL)* ssl,
    const(ubyte*)* data,
    uint* len);
int wolfSSL_select_next_proto (
    ubyte** out_,
    ubyte* outlen,
    const(ubyte)* in_,
    uint inlen,
    const(ubyte)* client,
    uint client_len);
void wolfSSL_CTX_set_alpn_select_cb (
    WOLFSSL_CTX* ctx,
    int function (WOLFSSL* ssl, const(ubyte*)* out_, ubyte* outlen, const(ubyte)* in_, uint inlen, void* arg) cb,
    void* arg);
void wolfSSL_CTX_set_next_protos_advertised_cb (
    WOLFSSL_CTX* s,
    int function (WOLFSSL* ssl, const(ubyte*)* out_, uint* outlen, void* arg) cb,
    void* arg);
void wolfSSL_CTX_set_next_proto_select_cb (
    WOLFSSL_CTX* s,
    int function (WOLFSSL* ssl, ubyte** out_, ubyte* outlen, const(ubyte)* in_, uint inlen, void* arg) cb,
    void* arg);
void wolfSSL_get0_next_proto_negotiated (
    const(WOLFSSL)* s,
    const(ubyte*)* data,
    uint* len);

int wolfSSL_X509_check_host (
    WOLFSSL_X509* x,
    const(char)* chk,
    size_t chklen,
    uint flags,
    char** peername);
int wolfSSL_X509_check_ip_asc (WOLFSSL_X509* x, const(char)* ipasc, uint flags);

/* OPENSSL_EXTRA && WOLFSSL_CERT_GEN */

/* !NO_FILESYSTEM && !NO_STDIO_FILESYSTEM */

/* !WOLFCRYPT_ONLY */

/* OPENSSL_EXTRA || OPENSSL_EXTRA_X509_SMALL */

/* WOLFSSL_HAVE_TLS_UNIQUE */

/* This feature is used to set a fixed ephemeral key and is for testing only */
/* Currently allows ECDHE and DHE only */

/* returns pointer to loaded key as ASN.1/DER */

/* OPENSSL_EXTRA */

/* HAVE_EX_DATA || WOLFSSL_WPAS_SMALL */

/* defined(WOLFSSL_DTLS_CID) */

/*  */
enum SSL2_VERSION = 0x0002;
enum SSL3_VERSION = 0x0300;
enum TLS1_VERSION = 0x0301;
enum TLS1_1_VERSION = 0x0302;
enum TLS1_2_VERSION = 0x0303;
enum TLS1_3_VERSION = 0x0304;
enum DTLS1_VERSION = 0xFEFF;
enum DTLS1_2_VERSION = 0xFEFD;

/* extern "C" */

/* WOLFSSL_SSL_H */
