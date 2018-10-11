module tagion.network.SslSocket;

import std.socket;
import deimos.openssl.tls1;
import deimos.openssl.ssl;
import deimos.openssl.err;
import std.stdio:writeln;
import core.stdc.stdio;

enum EndpointType {Client, Server};

@safe
class SslSocketException : Exception {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line);
    }
}

void printDebugInformation (string msg) {
    int i;
    auto fmsg = msg ~ "\nPress a number to continue. \n";
    printf(fmsg.ptr);
    scanf("%d\n", i);
}


version=use_openssl;

version(use_openssl) {
    pragma(lib, "crypto");
    pragma(lib, "ssl");
    pragma(msg, "Compiles SslSocket with OpenSsl");

    class OpenSslSocket : Socket {
        private:
            debug{
                pragma(msg,"Compiles SslSocket in debug mode" );
               bool in_debugging_mode = true;
            }

            SSL* _ssl;
            SSL_CTX* _ctx;

            void initSsl(bool verifyPeer, EndpointType et ) {
                if ( et == EndpointType.Client) {
                    _ctx = SSL_CTX_new(TLS_client_method());
                }
                else if ( et == EndpointType.Server ) {
                    _ctx = SSL_CTX_new(TLS_server_method());
                }

                assert(_ctx !is null);

                _ssl = SSL_new(_ctx);

                if ( !verifyPeer ) {
                    SSL_set_verify(_ssl, SSL_VERIFY_NONE, null);
                }

                if ( et == EndpointType.Client ) {
                    SSL_set_fd(_ssl, this.handle);
                }
            }


        public:

        @trusted
        void configureContext(string certificate_path, string prvkey_path) {

            assert(certificate_path.length > 0, "Empty certificate input.");
            assert(prvkey_path.length > 0, "Empty private key input.");

            if ( SSL_CTX_use_certificate_file(_ctx, certificate_path.ptr, SSL_FILETYPE_PEM) <= 0 ) {
                ERR_print_errors_fp(stderr);
                static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                    printDebugInformation("Error in setting certificate");
                }
                throw new SslSocketException("ssl ctx certificate");
            }

            if ( SSL_CTX_use_PrivateKey_file(_ctx, prvkey_path.ptr, SSL_FILETYPE_PEM) <= 0 ) {
                ERR_print_errors_fp(stderr);
                static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                    printDebugInformation("Error in setting prvkey");
                }

                throw new SslSocketException("ssl ctx private key");
            }
            if (!SSL_CTX_check_private_key(_ctx) ) {
                static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                    printDebugInformation("Error private key not set correctly");
                }
                throw new SslSocketException("Private key not set correctly");
            }
        }

        bool dataPending() {
            return SSL_pending(_ssl) > 0;
        }

        @trusted
        override void connect(Address to) {
            super.connect(to);
            if ( SSL_connect(_ssl) == -1 ) {
                ERR_print_errors_fp(stderr);
                static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation("Error in connect");
                }
                throw new SslSocketException("ssl connect");
            }
        }

        @trusted
        override ptrdiff_t send(const(void)[] buf, SocketFlags flags) {
            auto res_val = SSL_write(_ssl, buf.ptr, cast(uint)buf.length);
            if ( res_val == -1 ) {
                ERR_print_errors_fp(stderr);
				static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation("Error in send");
                }
				throw new SslSocketException("ssl send");
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
                static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation("Error in receive");
                }
				throw new SslSocketException("ssl receive");
            }
            return res_val;
        }

        @trusted
        override ptrdiff_t receive(void[] buf) {
            return receive(buf, SocketFlags.NONE);
        }

        @trusted
        override Socket accept() {
            Socket sn = super.accept();
            writeln(sn.handle());
            SSL_set_fd(_ssl, sn.handle());

            if ( SSL_accept(_ssl) <= 0 ) {
                ERR_print_errors_fp(stderr);
                static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation("Error in handsaking, accept");
                }
                sn.shutdown(SocketShutdown.BOTH);
                sn.close();
				throw new SslSocketException("ssl handsake, accept");
                sn.close();
            }
            else {
                return this;
            }
        }

        this(AddressFamily af, EndpointType et, SocketType type = SocketType.STREAM, bool verifyPeer = true) {
            super(af, type);
            initSsl(verifyPeer, et);
        }

        this(socket_t sock, EndpointType et, AddressFamily af) {
            super(sock, af);
            initSsl(true, et);
        }

        ~this() {
            SSL_free(_ssl);
            SSL_CTX_free(_ctx);
        }
    }
}