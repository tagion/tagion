module tagion.network.SSLSocket;

import core.stdc.stdio;

//import core.stdc.string : strerror;

import std.socket;
import std.range.primitives : isBidirectionalRange;
import std.string : format, toStringz;
import std.typecons : Tuple;
import std.array : join;
import std.algorithm.iteration : map;
import std.typecons : Flag, Yes, No;
import std.traits : EnumMembers;

import tagion.network.SSLSocketException;
import tagion.network.SSL;

import io = std.stdio;

enum EndpointType {
    Client,
    Server
}

enum Ownership {
    COMMON, /// Uses common clinet context
    OWNS, /// Ex. used by the server context
    BORROWS, /// Used by a server response socket
}

/++
 Socket for OpenSSL & WolfSSL
+/
@safe
class SSLSocket : Socket {
    enum ERR_TEXT_SIZE = 256;

    protected {
        SSL* _ssl;
        SSL_CTX* _ctx;
        __gshared SSL_CTX* _client_ctx;
        Ownership _ownership;
    }

    @trusted
    shared static this() {
        SSL_Init;
        SSL_METHOD* method;
        method = TLS_client_method();
        _client_ctx = SSL_CTX_new(method);
        assert(_client_ctx !is null, "Faild to create SSL context");

    }

    @trusted
    shared static ~this() {
        SSL_CTX_free(_client_ctx);
        SSL_Cleanup;
    }

    @trusted
    protected static SSL_CTX* client_ctx() nothrow @nogc {
        return _client_ctx;
    }

    /++
     Constructs a new socket
     +/
    this(AddressFamily af,
            SocketType type = SocketType.STREAM,
            string certificate_filename = null,
            string prvkey_filename = null) {
        ERR_clear_error;
        super(af, type);
        _init(certificate_filename, prvkey_filename);
    }

    this(AddressFamily af,
            EndpointType et,
            SocketType type = SocketType.STREAM,
            bool verifyPeer = true) {
        ERR_clear_error;
        super(af, type);
        //    _init(certificate_filename, prvkey_filename);
    }

    /// ditto
    this(socket_t sock,
            AddressFamily af,
            SSLSocket seed_socket) {
        ERR_clear_error;
        super(sock, af);
        if (seed_socket) {
            _ctx = seed_socket._ctx;
        }
        else {
            _init(null, null);
        }
        //        _init(certificate_filename, prvkey_filename);
    }

    this(socket_t sock,
            AddressFamily af,
            SSL_CTX* ctx = null) {
        if (ctx !is null) {
            _ownership = Ownership.BORROWS;
            _ctx = ctx;
        }
        else {
            _ownership = Ownership.COMMON;
            _ctx = client_ctx;
        }
        _ssl = SSL_new(_ctx);
        SSL_set_fd(_ssl, sock);
        super(sock, af);
    }

    bool verifyPeer; // = true;
    /++
     The client use this configuration by default.
     +/
    protected final void _init(
            string certificate_filename = null,
            string prvkey_filename = null) {
        if (certificate_filename.length) {
            configureContext(certificate_filename, prvkey_filename);
        }
        if (_ctx is null) {
            // If _ctx is null then it is uses a client SSL
            _ctx = client_ctx;
            _ownership = Ownership.COMMON;
        }
        _ssl = SSL_new(_ctx);
        SSL_set_fd(_ssl, this.handle);
        if (verifyPeer) {
            SSL_set_verify(_ssl, SSL_VERIFY_NONE, null);
        }
    }

    version (none) bool isClient() nothrow const @nogc {
        return !endpoint;
    }

    Ownership ownership() pure nothrow const @nogc {
        return _ownership;
    }

    ~this() {
        SSL_free(_ssl);
        if (_ownership is Ownership.OWNS) {
            SSL_CTX_free(_ctx);
        }
    }

    static string errorText(const long error_code) @trusted nothrow {
        import core.stdc.string : strlen;
        import std.exception : assumeUnique;

        auto result = new char[ERR_TEXT_SIZE];
        ERR_error_string_n(error_code, result.ptr, result
                .length);
        return assumeUnique(result[0 .. strlen(result.ptr)]);
    }

    alias SSL_Error = Tuple!(long, "error_code", string, "msg");
    static const(SSL_Error[]) getErrors() nothrow {
        long error_code;
        SSL_Error[] result;
        while ((error_code = ERR_get_error) != 0) {
            result ~= SSL_Error(error_code, errorText(error_code));
        }
        return result;
    }

    static string getAllErrors() {
        return getErrors
            .map!(err => format("Err %d: %s", err.error_code, err.msg))
            .join("\n");
    }

    /++
     Configure the certificate for the SSL
     +/
    @trusted
    void configureContext(
            string certificate_filename,
            string prvkey_filename) {
        if (prvkey_filename.length is 0) {
            prvkey_filename = certificate_filename;
        }
        import std.file : exists;

        ERR_clear_error;
        _ctx = SSL_CTX_new(TLS_server_method);
        _ownership = Ownership.OWNS;
        check(certificate_filename.exists,
                format("Certification file '%s' not found", certificate_filename));
        check(prvkey_filename.exists,
                format("Private key file '%s' not found", prvkey_filename));

        if (SSL_CTX_use_certificate_file(ctx, certificate_filename.toStringz,
                SSL_FILETYPE_PEM) <= 0) {
            throw new SSLSocketException(format("SSL Certificate: %s", getAllErrors));
        }

        if (SSL_CTX_use_PrivateKey_file(ctx, prvkey_filename.toStringz, SSL_FILETYPE_PEM) <= 0) {
            throw new SSLSocketException(format("SSL private key:\n %s", getAllErrors));
        }
        if (SSL_CTX_check_private_key(ctx) <= 0) {
            throw new SSLSocketException(format("Private key not set correctly:\n %s", getAllErrors));
        }
    }

    /++
     Cleans the SSL error queue
     +/
    static void clearError() {
        ERR_clear_error();
    }

    /++
     Connect to an address
     +/
    override void connect(Address to) {
        super.connect(to);
        SSL_set_fd(ssl, handle);
        const res = SSL_connect(_ssl);
        check_error(res, true);
    }

    /**
       Throws: and exception if the SocketShutdown is not set to BOTH
       Params: how has no effect for the SSLSocket
    */
    override void shutdown(SocketShutdown how) {
        assert(how is SocketShutdown.BOTH, "Only shutdown both is supported for SSL");
        SSL_shutdown(_ssl);
    }

    /**
      A SSL socket can only be shutdown for both read/write.
      This function just do the default SSL shutdown
      Returns: true if the socket did shutdown correctly
    */

    bool shutdown() {
        return SSL_shutdown(_ssl) != 0;
    }

    /++
     Send a buffer to the socket using the socket result
     +/
    @trusted
    override ptrdiff_t send(scope const(void)[] buf, SocketFlags flags) {
        const ret = SSL_write(_ssl, &buf[0], cast(int) buf.length);
        //  check_error(res);
        return ret;
    }

    /++
     Send a buffer to the socket with no result
     +/
    override ptrdiff_t send(scope const(void)[] buf) {
        return send(buf, SocketFlags.NONE);
    }

    /* Helper function to convert a ssl_error to an exception
     * This function should only called after an ssl function call
     * Throws: a SSLSocketException if the _ssl handler contains an error
     * Params:
     *   ssl_ret = Return code for SSL (ssl_ret > 0) means no error
     *   false = Enable ignore temporary errors for (Want to read or write)
     */
    protected void check_error(const int ssl_ret, const bool check_read_write = false) const {
        const ssl_error = cast(SSLErrorCodes) SSL_get_error(_ssl, ssl_ret);
        with (SSLErrorCodes) {
        SSLErrorCase:
            final switch (ssl_error) {
                static foreach (ErrorCode; EnumMembers!SSLErrorCodes) {
            case ErrorCode:
                    static if (ErrorCode is SSLErrorCodes.SSL_ERROR_NONE) {
                        // None
                    }
                    else static if (ErrorCode is SSLErrorCodes.SSL_ERROR_WANT_WRITE &&
                            ErrorCode is SSLErrorCodes.SSL_ERROR_WANT_READ) {
                        if (check_read_write) {
                            throw new SSLSocketException(errorText(ssl_error), ssl_error);
                        }
                    }
                    else {
                        throw new SSLSocketException(errorText(ssl_error), ssl_error);
                    }
                }
            }
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
    override ptrdiff_t receive(scope void[] buf, SocketFlags flags) {
        const size = SSL_read(_ssl, buf.ptr, cast(uint) buf.length);
        // check_error(size);
        //buf = buf[0 .. size];
        return size;
    }

    /++
     Receive a buffer from the socket with not flags
     +/
    override ptrdiff_t receive(scope void[] buf) {
        return receive(buf, SocketFlags.NONE);
    }

    /**
	Returns: SSLSocket from the socket listener
	*/
    @trusted
    override SSLSocket accept() {
        auto newsock = cast(socket_t).accept(handle, null, null);
        if (socket_t.init is newsock) {
            throw new SocketAcceptException("Unable to accept socket connection");
        }

        auto socket = new SSLSocket(newsock, addressFamily, _ctx);

        const ret = SSL_accept(socket.ssl);
        if (ret != 0) {
            check_error(ret);
        }

        return socket;
    }

    /**
	Returns: true if data is pending the socket
	*/
    @trusted
    ptrdiff_t pending() nothrow @nogc {
        return SSL_pending(_ssl);
    }

    /++
     Returns:
     the SSL system handler
     +/
    @nogc
    SSL* ssl() pure nothrow {
        return _ssl;
    }

    @nogc
    SSL_CTX* ctx() pure nothrow {
        return _ctx;
    }

    unittest {
        // The SSLSocket test is done in the BDD
        import std.array;
        import std.string;
        import std.file;
        import std.exception : assertNotThrown, assertThrown, collectException;
        import tagion.basic.basic : fileId;
        import std.stdio;

        import tagion.basic.Debug : testfile;

        immutable cert_path = testfile(__MODULE__ ~ ".pem");
        immutable key_path = testfile(__MODULE__ ~ ".key.pem");
        version (SSL_PEM_FILES) {
            /// This switch can beable of a new .pem should be created
            immutable stab = "stab";

            import tagion.network.SSLServerOptions;

            const OpenSSL ssl_options = {
                certificate: cert_path, /// Certificate file name
                private_key: key_path, /// Private key
                key_size: 1024, /// Key size (RSA 1024,2048,4096)
                days: 1, /// Number of days the certificate is valid
                country: "UA", /// Country Name two letters
                state: stab, /// State or Province Name (full name)
                city: stab, /// Locality Name (eg, city)
                organisation: stab, /// Organization Name (eg, company)
                unit: stab, /// Organizational Unit Name (eg, section)
                name: stab, /// Common Name (e.g. server FQDN or YOUR name)
                email: stab, /// Email Address

            
            };
            configureOpenSSL(ssl_options);
        }
        //! [File reading - incorrect certificate]
        {
            SSLSocket testItem_server;
            const exception = collectException!SSLSocketException(
                    new SSLSocket(AddressFamily.UNIX, SocketType.STREAM, "_", "_"),
                    testItem_server);
            assert(exception !is null);
            assert(testItem_server is null);
        }

        //! [file loading correct]
        {
            SSLSocket testItem_server;
            const exception = collectException!SSLSocketException(
                    new SSLSocket(AddressFamily.UNIX, SocketType.STREAM,
                    cert_path, key_path),
                    testItem_server);
            scope (exit) {
                testItem_server.close;
            }
            assert(exception is null);
            assert(testItem_server !is null);
        }

        //! [file loading key incorrect]
        {
            auto false_key_path = cert_path;
            SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX);
            const exception = collectException!SSLSocketException(
                    testItem_server.configureContext(cert_path, false_key_path)
            );
            assert(exception !is null);
            assert(exception.error_code == SSLErrorCodes.SSL_ERROR_NONE);
        }
    }
}
