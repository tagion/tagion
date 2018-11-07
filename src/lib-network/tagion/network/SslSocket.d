module tagion.network.SslSocket;

import std.socket;
import core.stdc.stdio;
import std.range.primitives : isBidirectionalRange;
import std.string : format;

enum EndpointType {Client, Server};

@safe
class SslSocketException : SocketException {
    this( immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__ ) {
        super( msg, file, line);
    }
}

debug {
    import std.stdio : writeln;
    void printDebugInformation (string msg) {
        int i;
        writeln(msg);
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
        int SSL_pending(SSL*);

        SSL_CTX* SSL_CTX_new(const SSL_METHOD* method);
        void SSL_CTX_free(SSL_CTX*);

        SSL_METHOD* TLS_client_method();
        SSL_METHOD* TLS_server_method();

        int SSL_CTX_use_certificate_file(SSL_CTX*, const char*, int);
        int SSL_CTX_use_PrivateKey_file(SSL_CTX*, const char*, int);
        int SSL_CTX_check_private_key(SSL_CTX*);

        void ERR_print_errors_fp(FILE*);
        int SSL_get_error(const SSL *ssl, int ret);

    }

    enum SSLErrorCodes {
        SSL_ERROR_NONE = 0,
        SSL_ERROR_SSL = 1,
        SSL_ERROR_WANT_READ = 2,
        SSL_ERROR_WANT_WRITE = 3,
        SSL_ERROR_WANT_X509_LOOKUP = 4,
        SSL_ERROR_SYSCALL = 5,           /* look at error stack/return
                                           * value/errno */
        SSL_ERROR_ZERO_RETURN = 6,
        SSL_ERROR_WANT_CONNECT = 7,
        SSL_ERROR_WANT_ACCEPT = 8,
        SSL_ERROR_WANT_ASYNC = 9,
        SSL_ERROR_WANT_ASYNC_JOB = 10
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

        //Not made for fibers - reads all data and returns.
        @trusted
        int receiveNonBlocking(ref void[] buf, ref int pending_in_buffer)
        in {
            assert(!this.blocking);
        }
        body{
            auto res = SSL_read(_ssl, buf.ptr, cast(uint)buf.length);

            auto ssl_error = SSL_get_error(_ssl, res);

            with(SSLErrorCodes) switch(ssl_error) {
                case SSL_ERROR_NONE:
                    static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation("Received data.");
                    }
                    break;

                case SSL_ERROR_SSL:
                    this.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_SSL. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;

                case SSL_ERROR_WANT_READ:
                    this.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_WANT_READ. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;

                case SSL_ERROR_WANT_WRITE:
                    this.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_WANT_WRITE. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );

                    break;

                case SSL_ERROR_WANT_X509_LOOKUP:
                    this.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_WANT_X509_LOOKUP. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;

                case SSL_ERROR_SYSCALL:
                    this.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_SYSCALL. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;

                case SSL_ERROR_ZERO_RETURN:
                    this.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_ZERO_RETURN. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;

                default:
                    this.disconnect;
                    throw new SslSocketException( format("SSL Error. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;
            }

            pending_in_buffer = SSL_pending(_ssl);

            return res;
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
        bool acceptSslNonBlocking(ref OpenSslSocket ssl_client) {
            if ( ssl_client is null ) {
                static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                    printDebugInformation("Accepting new client");
                }
                Socket client = super.accept();
                if ( !client.isAlive ) {
                    client.close;
                    throw new SslSocketException("Socket could not connect to client. Socket closed.");
                }
                client.blocking = false;
                ssl_client = new OpenSslSocket(client.handle, EndpointType.Server, AddressFamily.INET);
                SSL_set_fd(ssl_client.getSsl, client.handle);
            }

            auto c_ssl = ssl_client.getSsl;

            const res = SSL_accept(c_ssl);

            auto ssl_error = SSL_get_error(c_ssl, res);
            bool accepted;

            with(SSLErrorCodes) switch(ssl_error) {
                case SSL_ERROR_NONE:
                    accepted = true;
                    static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation("Accepted new SSL connection");
                    }
                    break;

                case SSL_ERROR_SSL:
                    ssl_client.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_SSL. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;

                case SSL_ERROR_WANT_READ:
                    static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation("SSL_ERROR_WANT_READ");
                    }
                    break;

                case SSL_ERROR_WANT_WRITE:
                    static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                        printDebugInformation("SSL_ERROR_WANT_WRITE");
                    }
                    break;

                case SSL_ERROR_WANT_X509_LOOKUP:
                    ssl_client.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_WANT_X509_LOOKUP. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;

                case SSL_ERROR_SYSCALL:
                    ssl_client.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_SYSCALL. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;

                case SSL_ERROR_ZERO_RETURN:
                    ssl_client.disconnect;
                    throw new SslSocketException( format("SSL Error: SSL_ERROR_ZERO_RETURN. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;

                default:
                    ssl_client.disconnect;
                    throw new SslSocketException( format("SSL Error. SSL error code: %d\nConnection closed and cleaned up.", ssl_error) );
                    break;
            }

            auto result = false;

            if(  SSL_pending(c_ssl) || !accepted  ) {
                result = false;
            } else {
                result = true;
            }

            return result;
        }

        @trusted
        void rejectClient () {
            auto client = super.accept();
            static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                printDebugInformation( format( "Rejected connection from %s; too many connections.", client.remoteAddress().toString() ) );
            }
            this.disconnect();
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
                static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                    printDebugInformation( format( "Exception from disconnect(), %s : %s \n msg: ", ex.file, ex.line, ex.msg) );
                }
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
            static if (__traits(hasMember, OpenSslSocket, "in_debugging_mode") ) {
                printDebugInformation( "Executed static destructor" );
            }
        }
    }
}