module tagion.network.SslSocket;

import std.socket;
import deimos.openssl.tls1;
import deimos.openssl.ssl;
import deimos.openssl.err;
import core.stdc.stdio;


version=use_openssl;

version(use_openssl) {
    pragma(lib, "crypto");
    pragma(lib, "ssl");
    pragma(msg, "Compiles SslSocket with OpenSsl");

    class OpenSslSocket : Socket {
        private:
            SSL* _ssl;
            SSL_CTX* _ctx;

            void initSsl(bool verifyPeer) {
                _ctx = SSL_CTX_new(TLS_client_method());
                assert(_ctx !is null);

                _ssl = SSL_new(_ctx);
                if ( verifyPeer ) {
                    SSL_set_verify(_ssl, SSL_VERIFY_NONE, null);
                }
                SSL_set_fd(_ssl, this.handle);
            }

        public:

        bool dataPending() {
            return SSL_pending(_ssl) > 0;
        }

        @trusted
        override void connect(Address to) {
            super.connect(to);
            if ( SSL_connect(_ssl) == -1 ) {
                ERR_print_errors_fp(stderr);
                int i;
                printf("wtf\n");
                scanf("%d\n", i);
                throw new Exception("ssl connect");
            }
        }

        @trusted
        override ptrdiff_t send(const(void)[] buf, SocketFlags flags) {
            auto res_val = SSL_write(_ssl, buf.ptr, cast(uint)buf.length);
            if ( res_val == -1 ) {
                ERR_print_errors_fp(stderr);
				int i;
				printf("Error in send ssl\n");
				scanf("%d\n", i);
				throw new Exception("ssl send");
            }

            return res_val;
        }

        @trusted
        override ptrdiff_t send(const(void)[] buf) {
            return send(buf, SocketFlags.NONE);
        }

        @trusted
        override ptrdiff_t receive(void[] buf, SocketFlags flags) {
            auto res_val = SSL_read(_ssl, buf.ptr, cast(uint)buf.length);
            if ( res_val == -1 ) {
                ERR_print_errors_fp(stderr);
                int i;
                printf("Error in receive ssl\n");
                scanf("%d\n", i);
				throw new Exception("ssl receive");
            }
            return res_val;
        }

        @trusted
        override ptrdiff_t receive(void[] buf) {
            return receive(buf, SocketFlags.NONE);
        }

        this(AddressFamily af, SocketType type = SocketType.STREAM, bool verifyPeer = true) {
            super(af, type);
            initSsl(verifyPeer);
        }

        this(socket_t sock, AddressFamily af) {
            super(sock, af);
            initSsl(true);
        }

        ~this() {
            SSL_free(_ssl);
            SSL_CTX_free(_ctx);
        }
    }
}