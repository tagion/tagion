module tagion.network.SslSocket;

import std.stdio : writeln, writefln;
import std.socket;
import core.stdc.stdio;
import std.range.primitives : isBidirectionalRange;

enum EndpointType {Client, Server};

@safe
class SslSocketException : SocketException {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line);
    }
}

debug {
    void printDebugInformation (string msg) {
        int i;
        auto fmsg = msg ~ "\nPress a number to continue. \n";
        printf(fmsg.ptr);
        scanf("%d\n", i);
    }
}



version=use_openssl;

version(use_openssl) {
    pragma(lib, "crypto");
    pragma(lib, "ssl");
    pragma(msg, "Compiles SslSocket with OpenSsl");


    extern(C) {
        enum SSL_VERIFY_NONE = 0;
        enum SSL_FILETYPE_PEM = 1;

        struct SSL;
        struct SSL_CTX;
        struct SSL_METHOD;

        SSL* SSL_new(SSL_CTX*);
        void SSL_free(SSL*);
        void SSL_set_verify(SSL*, int, void*);
        int SSL_set_fd(SSL*, int);
        int SSL_connect(SSL*);
        int SSL_accept(SSL*);
        int SSL_write(SSL*, const void*, int);
        int SSL_read(SSL*, void*, int);

        SSL_CTX* SSL_CTX_new(const SSL_METHOD* method);
        void SSL_CTX_free(SSL_CTX*);

        SSL_METHOD* TLS_client_method();
        SSL_METHOD* TLS_server_method();

        int SSL_CTX_use_certificate_file(SSL_CTX*, const char*, int);
        int SSL_CTX_use_PrivateKey_file(SSL_CTX*, const char*, int);
        int SSL_CTX_check_private_key(SSL_CTX*);

        void ERR_print_errors_fp(FILE*);

    }

    enum SocketStatus {
        SSL_ERROR_NONE,
        SSL_ERROR_ZERO_RETURN,
        SSL_ERROR_WANT_READ,
        SSL_ERROR_WANT_WRITE,
        SSL_ERROR_WANT_CONNECT,
        SSL_ERROR_WANT_ACCEPT,
        SSL_ERROR_WANT_X509_LOOKUP,
        SSL_ERROR_SYSCALL,
        SSL_ERROR_SSL
    }

    class OpenSslSocket : Socket {

        private:
            debug{
                pragma(msg,"Compiles SslSocket in debug mode" );
                enum in_debugging_mode = true;
            }

            SSL* _ssl;

            SSL_CTX* _ctx;

            //Static are used as default as context. A setter/argu. in cons. for the context
            //could be impl. if diff. contexts for diff SSL are needed.
            static SSL_CTX* client_ctx;
            static SSL_CTX* server_ctx;

            //The client use this configuration by default.
            void init(bool verifyPeer, EndpointType et) {
                checkContext(et);
                assert(_ctx !is null);

                _ssl = SSL_new(_ctx);

                if ( et == EndpointType.Client ) {
                    SSL_set_fd(_ssl, this.handle);
                    if ( !verifyPeer ) {
                        SSL_set_verify(_ssl, SSL_VERIFY_NONE, null);
                    }
                }
            }

            void checkContext(EndpointType et) {
                //Maybe implement more versions....
                if ( et == EndpointType.Client) {
                    if ( client_ctx is null ) {
                        client_ctx = SSL_CTX_new(TLS_client_method());
                    }
                    _ctx = client_ctx;

                }
                else if ( et == EndpointType.Server ) {
                    if ( server_ctx is null ) {
                        server_ctx = SSL_CTX_new(TLS_server_method());
                    }
                    _ctx = server_ctx;
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
            Socket client = super.accept();

            auto ssl_client = new OpenSslSocket(client.handle, EndpointType.Server, AddressFamily.INET);

            SSL_set_fd(ssl_client.getSsl, client.handle);

            if ( SSL_accept(ssl_client.getSsl) <= 0 ) {
                ERR_print_errors_fp(stderr);

                client.shutdown(SocketShutdown.BOTH);
                client.close();
				throw new SslSocketException("ssl handsake, accept");
            }
            else {
                return cast(Socket)ssl_client;
            }
        }

        //false=operation not complete and 1, operation complete.
        bool acceptSslAsync(ref OpenSslSocket ssl_client) {
            if ( ssl_client is null ) {
                Socket client = super.accept();
                client.blocking = false;
                ssl_client = new OpenSslSocket(client.handle, EndpointType.Server, AddressFamily.INET);
                SSL_set_fd(ssl_client.getSsl, client.handle);
            }

            int res = SSL_accept(ssl_client.getSsl);
            writeln("The result code is: ", res);
            if ( res <= 0 ) {
                // client.shutdown(SocketShutdown.BOTH);
                // client.close();
				// throw new SslSocketException("ssl handsake, accept");

                return SocketStatus.SSL_ERROR_SSL;
            }
            else {
                return SocketStatus.SSL_ERROR_NONE;
            }
        }


        @trusted
        void disconnect() {
            try
            {
                if ( _ssl !is null ) {
                    SSL_free(_ssl);
                }


                if ((client_ctx !is null || server_ctx !is null) &&
                    client_ctx != _ctx && server_ctx != _ctx && _ctx !is null) {

                    SSL_CTX_free(_ctx);
                }
            } catch(Exception ex) {
                writeln(ex);
            }

            super.close();
        }

        @trusted
        SSL* getSsl() {
            return this._ssl;
        }

        this(AddressFamily af, EndpointType et,
         SocketType type = SocketType.STREAM, bool verifyPeer = true) {
            super(af, type);
            init(verifyPeer, et);
        }

        this(socket_t sock, EndpointType et, AddressFamily af) {
            super(sock, af);
            init(true, et);
        }

        static ~this() {
            if ( server_ctx !is null ) SSL_CTX_free(server_ctx);
            if ( client_ctx !is null ) SSL_CTX_free(client_ctx);
            writeln("Executed static destructor");
        }
    }
}