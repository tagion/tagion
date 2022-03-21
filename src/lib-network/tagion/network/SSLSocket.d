module tagion.network.SSLSocket;

import std.socket;
import core.stdc.stdio;
import std.range.primitives : isBidirectionalRange;
import std.string : format;
import io = std.stdio;

enum EndpointType {
    Client,
    Server
}

@safe
class SSLSocketException : SocketException {
    immutable SSLErrorCodes error_code;
    this(immutable(char)[] msg, const SSLErrorCodes error_code = SSLErrorCodes.SSL_ERROR_NONE,
            string file = __FILE__, size_t line = __LINE__) {
        this.error_code = error_code;
        super(msg, file, line);
    }
}

extern (C) {
    enum SSL_VERIFY_NONE = 0;
    enum SSL_FILETYPE_PEM = 1;

    struct SSL;
    struct SSL_CTX;
    struct SSL_METHOD;

    @trusted
    protected {
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

        SSL_METHOD* TLSv1_client_method();
        SSL_METHOD* TLSv1_server_method();

        int SSL_CTX_use_certificate_file(SSL_CTX* ctx, const char* file, int type);
        int SSL_CTX_use_PrivateKey_file(SSL_CTX* ctx, const char* file, int type);
        int SSL_CTX_check_private_key(SSL_CTX* ctx);

        int SSL_get_error(const SSL* ssl, int ret);

        void ERR_clear_error();
        void ERR_print_errors_fp(FILE* file);
        ulong ERR_get_error();
        void ERR_error_string_n(ulong e, char* buf, size_t len);
        char* strerror(int errnum);
        //        void ERR_error_string(ulong e, char* buf);
    }
}

enum SSLErrorCodes {
    SSL_ERROR_NONE = 0,
    SSL_ERROR_SSL = 1,
    SSL_ERROR_WANT_READ = 2,
    SSL_ERROR_WANT_WRITE = 3,
    SSL_ERROR_WANT_X509_LOOKUP = 4,
    SSL_ERROR_SYSCALL = 5, /* look at error stack/return
                                      * value/errno */
    SSL_ERROR_ZERO_RETURN = 6,
    SSL_ERROR_WANT_CONNECT = 7,
    SSL_ERROR_WANT_ACCEPT = 8,
    SSL_ERROR_WANT_ASYNC = 9,
    SSL_ERROR_WANT_ASYNC_JOB = 10
}

/++
 Socket for OpenSSL
+/
@safe
class SSLSocket : Socket {
    protected {
        debug {
            pragma(msg, "DEBUG: SSLSocket compiled in debug mode");
            enum in_debugging_mode = true;

            import std.stdio : writeln;

            static void printDebugInformation(string msg) {
                int i;
                writeln(msg);
            }
        }
        else {
            enum in_debugging_mode = false;
        }

        SSL* _ssl;

        SSL_CTX* _ctx;

        //Static are used as default as context. A setter/argu. in cons. for the context
        //could be impl. if diff. contexts for diff SSL are needed.
        static SSL_CTX* client_ctx;
        static SSL_CTX* server_ctx;
    }

    /++
     The client use this configuration by default.
     +/
    protected void init(bool verifyPeer, EndpointType et) {
        checkContext(et);
        _ssl = SSL_new(_ctx);

        if (et is EndpointType.Client) {
            SSL_set_fd(_ssl, this.handle);
            if (!verifyPeer) {
                SSL_set_verify(_ssl, SSL_VERIFY_NONE, null);
            }
        }
    }

    protected void checkContext(EndpointType et)
    out {
        assert(_ctx);
    }
    do {
        //Maybe implement more versions....
        if (et is EndpointType.Client) {
            if (client_ctx is null) {
                client_ctx = SSL_CTX_new(TLSv1_client_method());
            }
            _ctx = client_ctx;
        }
        else if (et is EndpointType.Server) {
            if (server_ctx is null) {
                server_ctx = SSL_CTX_new(TLSv1_server_method());
            }
            _ctx = server_ctx;
        }
    }

    /++
     Configure the certificate for the SSL
     +/
    @trusted
    void configureContext(string certificate_filename, string prvkey_filename)
    in {
        assert(certificate_filename.length > 0, "Empty certificate input.");
        assert(prvkey_filename.length > 0, "Empty private key input.");
    }
    do {
        if (SSL_CTX_use_certificate_file(_ctx, certificate_filename.ptr, SSL_FILETYPE_PEM) <= 0) {
            ERR_print_errors_fp(stderr);
            static if (in_debugging_mode) {
                printDebugInformation("Error in setting certificate");
            }
            throw new SSLSocketException("ssl ctx certificate");
        }

        if (SSL_CTX_use_PrivateKey_file(_ctx, prvkey_filename.ptr, SSL_FILETYPE_PEM) <= 0) {
            ERR_print_errors_fp(stderr);
            static if (in_debugging_mode) {
                printDebugInformation("Error in setting prvkey");
            }

            throw new SSLSocketException("ssl ctx private key");
        }
        if (!SSL_CTX_check_private_key(_ctx)) {
            static if (in_debugging_mode) {
                printDebugInformation("Error private key not set correctly");
            }
            throw new SSLSocketException("Private key not set correctly");
        }
    }

    /++
     Cleans the SSL error que
     +/
    void clearError() {
        ERR_clear_error();
    }

    /++
     Connect to an address
     +/
    override void connect(Address to) {
        super.connect(to);
        const res = SSL_connect(_ssl);
        check_error(res, true);
    }

    /++
     Send a buffer to the socket using the socket flag
     +/
    @trusted
    override ptrdiff_t send(const(void)[] buf, SocketFlags flags) {
        auto res_val = SSL_write(_ssl, buf.ptr, cast(int) buf.length);
        const ssl_error = cast(SSLErrorCodes) SSL_get_error(_ssl, res_val);
        check_error(res_val);
        return res_val;
    }

    /++
     Send a buffer to the socket with no flag
     +/
    override ptrdiff_t send(const(void)[] buf) {
        return send(buf, SocketFlags.NONE);
    }

    /++
     Check the return flag for a SSL system function
     +/
    void check_error(const int res, const bool check_read_write = false) const {
        const ssl_error = cast(SSLErrorCodes) SSL_get_error(_ssl, res);
        with (SSLErrorCodes) final switch (ssl_error) {
        case SSL_ERROR_NONE:
            // Ignore
            break;
        case SSL_ERROR_WANT_WRITE,
        SSL_ERROR_WANT_READ:
            if (check_read_write) {
                throw new SSLSocketException(str_error(ssl_error), ssl_error);
            }
            break;
        case SSL_ERROR_WANT_X509_LOOKUP,
            SSL_ERROR_SYSCALL,
            SSL_ERROR_ZERO_RETURN,
            SSL_ERROR_WANT_CONNECT,
            SSL_ERROR_WANT_ACCEPT,
            SSL_ERROR_WANT_ASYNC,
            SSL_ERROR_WANT_ASYNC_JOB,
        SSL_ERROR_SSL:
            throw new SSLSocketException(str_error(ssl_error), ssl_error);
            break;
        }

    }

    /++
     Returns:
     pending bytes in the socket que
     +/
    uint pending() {
        const result = SSL_pending(_ssl);
        return cast(uint) result;
    }

    /++
     Receive a buffer from the socket using the flags
     +/
    @trusted
    override ptrdiff_t receive(void[] buf, SocketFlags flags) {
        const res_val = SSL_read(_ssl, buf.ptr, cast(uint) buf.length);
        check_error(res_val);
        return res_val;
    }

    /++
     Receive a buffer from the socket with not flags
     +/
    override ptrdiff_t receive(void[] buf) {
        return receive(buf, SocketFlags.NONE);
    }

    version (none) {
        @trusted
        int receiveNonBlocking(void[] buf, ref int pending_in_buffer)
        in {
            assert(!this.blocking);
        }
        do {
            int res = SSL_read(_ssl, buf.ptr, cast(int) buf.length);

            check_error(res);
            pending_in_buffer = SSL_pending(_ssl);

            return res;
        }
    }

    version (none) static string errorMessage(const SSLErrorCodes ssl_error) {
        return format("SSL Error: %s. SSL error code: %d", ssl_error, ssl_error);
    }

    /++
     Returns:
     the SSL system error message
     +/
    @trusted
    static string str_error(const int errornum) {
        const str = strerror(errornum);
        import std.string : fromStringz;

        return fromStringz(str).idup;
    }

    version (none) @trusted
    static string err_string() {
        enum ERROR_LENGTH = 0x100;
        const error_code = ERR_get_error;
        scope char[ERROR_LENGTH] err_text;
        ERR_error_string_n(ERR_get_error, err_text.ptr, ERROR_LENGTH);
        import std.string : fromStringz;

        return fromStringz(err_text.ptr).idup;
    }

    /++
       Create a SSL socket from a socket
       Returns:
       true of the ssl_socket is succesfully created
       a ssl_client for the client
       Params:
       client = Standard socket (non ssl socket)
       ssl_socket = The SSL
    +/
    bool acceptSSL(ref SSLSocket ssl_client, Socket client) {
        if (ssl_client is null) {
            static if (in_debugging_mode) {
                printDebugInformation("Accepting new client");
            }
            // Socket client = super.accept();
            if (!client.isAlive) {
                client.close;
                throw new SSLSocketException("Socket could not connect to client. Socket closed.");
            }
            client.blocking = false;
            ssl_client = new SSLSocket(client.handle, EndpointType.Server, AddressFamily.INET);
            const fd_res = SSL_set_fd(ssl_client.getSSL, client.handle);
            if (fd_res) {
                return false;
            }
        }

        auto c_ssl = ssl_client.getSSL;

        const res = SSL_accept(c_ssl);
        bool accepted;

        const ssl_error = cast(SSLErrorCodes) SSL_get_error(c_ssl, res);

        with (SSLErrorCodes) switch (ssl_error) {
        case SSL_ERROR_NONE:
            accepted = true;
            break;

        case SSL_ERROR_WANT_READ, SSL_ERROR_WANT_WRITE:
            // Ignore
            break;
        case SSL_ERROR_SSL, SSL_ERROR_WANT_X509_LOOKUP, SSL_ERROR_SYSCALL, SSL_ERROR_ZERO_RETURN:
            throw new SSLSocketException(str_error(ssl_error), ssl_error);
            break;
        default:
            throw new SSLSocketException(format("SSL Error. SSL error code: %d.", ssl_error));
            break;
        }
        return !SSL_pending(c_ssl) && accepted;
    }

    /++
       Reject a client connect and close the socket
     +/
    void rejectClient() {
        auto client = super.accept();
        client.close();
    }

    /++
     Disconnect the socket
     +/
    void disconnect() {
        static if (in_debugging_mode) {
            printDebugInformation("Disconnet client. Closing client and clean up SSL.");
        }
        try {
            if (_ssl !is null) {
                SSL_free(_ssl);
            }

            if ((client_ctx !is null || server_ctx !is null) &&
                    client_ctx != _ctx && server_ctx != _ctx && _ctx !is null) {

                SSL_CTX_free(_ctx);
            }
        }
        catch (Exception ex) {
            static if (in_debugging_mode) {
                printDebugInformation(format("Exception from disconnect(), %s : %s \n msg: ", ex.file, ex.line, ex
                        .msg));
            }
        }

        super.close();
    }

    /++
     Returns:
     the SSL system handler
     +/
    @trusted
    SSL* getSSL() {
        return this._ssl;
    }

    /++
     Constructs a new socket
     +/
    this(AddressFamily af, EndpointType et,
            SocketType type = SocketType.STREAM, bool verifyPeer = true) {
        super(af, type);
        init(verifyPeer, et);
    }

    /// ditto
    this(socket_t sock, EndpointType et, AddressFamily af) {
        super(sock, af);
        init(true, et);
    }

    static ~this() {
        if (server_ctx !is null)
            SSL_CTX_free(server_ctx);
        if (client_ctx !is null)
            SSL_CTX_free(client_ctx);
    }
}
