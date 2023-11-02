module tagion.network.SSL;

import core.stdc.stdio;
import std.format;

enum SSL_VERIFY_NONE = 0;
enum SSL_FILETYPE_PEM = 1;
protected enum _SSLErrorCodes {
    SSL_ERROR_NONE = 0,
    SSL_ERROR_SSL = 1,
    SSL_ERROR_WANT_READ = 2,
    SSL_ERROR_WANT_WRITE = 3,
    SSL_ERROR_WANT_X509_LOOKUP = 4,
    SSL_ERROR_SYSCALL = 5, /* look at error stack/return * value/errno */
    SSL_ERROR_ZERO_RETURN = 6,
    SSL_ERROR_WANT_CONNECT = 7,
    SSL_ERROR_WANT_ACCEPT = 8,
    SSL_ERROR_WANT_ASYNC = 9,
    SSL_ERROR_WANT_ASYNC_JOB = 10
}

version (WOLFSSL) {
    // alias SSLErrorCodes = _SSLErrorCodes;
    extern (C) {
        private import tagion.network.wolfssl.c.error_ssl;
        private import tagion.network.wolfssl.c.wolfcrypt.error_crypt;
        private import tagion.network.wolfssl.c.ssl;

        //        package {
        alias SSL = WOLFSSL;
        alias SSL_CTX = WOLFSSL_CTX;
        alias SSL_CTX_use_certificate_file = wolfSSL_CTX_use_certificate_file;

        alias SSL_write = wolfSSL_write;
        alias SSL_read = wolfSSL_read;
        alias SSL_CTX_new = wolfSSL_CTX_new;
        alias SSL_CTX_free = wolfSSL_CTX_free;
        alias SSL_set_fd = wolfSSL_set_fd;
        alias SSL_get_fd = wolfSSL_get_fd;
        alias SSL_set_verify = wolfSSL_set_verify;
        alias SSL_new = wolfSSL_new;
        alias SSL_free = wolfSSL_free;
        alias SSL_get_error = wolfSSL_get_error;
        alias SSL_connect = wolfSSL_connect;
        alias SSL_accept = wolfSSL_accept;
        alias SSL_pending = wolfSSL_pending;
        alias SSL_shutdown = wolfSSL_shutdown;
        alias TLS_client_method = wolfTLS_client_method;
        alias TLS_server_method = wolfTLS_server_method;
        alias SSL_METHOD = WOLFSSL_METHOD;
        alias SSL_CTX_check_private_key = wolfSSL_CTX_check_private_key;
        alias SSL_CTX_use_PrivateKey_file = wolfSSL_CTX_use_PrivateKey_file;
        alias ERR_clear_error = wolfSSL_ERR_clear_error;
        alias ERR_get_error = wolfSSL_ERR_get_error;
        alias ERR_error_string_n = wolfSSL_ERR_error_string_n;
        /// Code generator which collects all WOLF and OPENSSL error into one enum
        protected string generator_SSLErrorCodes() {

            string[] enum_list;
            import std.conv : to;
            import std.traits : EnumMembers;
            import std.array : join;

            static foreach (E; EnumMembers!wolfSSL_ErrorCodes) {
                enum_list ~= format(q{    %1$s = cast(int)wolfSSL_ErrorCodes.%1$s,}, E.stringof);
            }
            static foreach (E; EnumMembers!wolfCrypt_ErrorCodes) {
                enum_list ~= format(q{    %1$s = cast(int)wolfCrypt_ErrorCodes.%1$s,}, E.stringof);
            }
            static foreach (E; EnumMembers!_SSLErrorCodes) {
                enum_list ~= format(q{    %1$s = cast(int)_SSLErrorCodes.%1$s,}, E.stringof);
            }

            return format("enum SSLErrorCodes {\n%-(%s \n%)\n};", enum_list);
        }
    }

    alias SSL_Init = wolfSSL_Init;
    alias SSL_Cleanup = wolfSSL_Cleanup;
    enum SSLErrorCodes_code = generator_SSLErrorCodes;
    mixin(SSLErrorCodes_code);
}
else {
    extern (C) {

        struct SSL;
        struct SSL_CTX;
        struct SSL_METHOD;

        @trusted nothrow @nogc {
            //        package {
            SSL* SSL_new(SSL_CTX* ctx);
            void SSL_free(SSL* ssl);
            void SSL_set_verify(SSL* ssl, int mode, void* callback);
            int SSL_set_fd(SSL* ssl, int fd);
            int SSL_connect(SSL* ssl);
            int SSL_accept(SSL* ssl);
            int SSL_write(SSL* ssl, const void* buf, int num);
            int SSL_read(SSL* ssl, void* buf, int num);
            int SSL_pending(SSL* ssl);
            int SSL_shutdown(SSL* ssl);

            SSL_CTX* SSL_CTX_new(const SSL_METHOD* method);
            void SSL_CTX_free(SSL_CTX* ctx);

            SSL_METHOD* TLS_client_method();
            SSL_METHOD* TLS_server_method();

            int SSL_CTX_use_certificate_file(SSL_CTX* ctx, const char* file, int type);
            int SSL_CTX_use_PrivateKey_file(SSL_CTX* ctx, const char* file, int type);
            int SSL_CTX_check_private_key(SSL_CTX* ctx);

            int SSL_get_error(const SSL* ssl, int ret);

            void ERR_clear_error();
            void ERR_print_errors_fp(FILE* file);
            ulong ERR_get_error();
            void ERR_error_string_n(ulong e, char* buf, size_t len);
            // char* strerror(int errnum);
            //        void ERR_error_string(ulong e, char* buf);
            void SSL_set_info_callback(SSL* ssl, void*);
            char* SSL_alert_type_string(int);
            char* SSL_alert_type_string_long(int);
            char* SSL_alert_desc_string_long(int);
            char* SSL_state_string_long(const SSL*);
            int OPENSSL_init_ssl(ulong opt, const void* settings);

        }

        void SSL_Init() {
            OPENSSL_init_ssl(0, null);
        }

        void SSL_Cleanup() {
            // Dummy function for compatibility with WolfSSL
        }
    }
    alias SSLErrorCodes = _SSLErrorCodes;
}
