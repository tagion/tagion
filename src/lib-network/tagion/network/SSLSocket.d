module tagion.network.SSLSocket;

import std.socket;
import core.stdc.stdio;
import std.range.primitives : isBidirectionalRange;
import std.string : format, toStringz;
import io = std.stdio;

enum EndpointType
{
    Client,
    Server
}

enum SSL_CB_POINTS : int
{
    CB_LOOP = 0x1,
    CB_EXIT = 0x2,
    CB_READ = CB_EXIT * 2,
    CB_WRITE = CB_READ * 2,
    HANDSHAKE_START = 0x10,
    HANDSHAKE_DONE = HANDSHAKE_START * 2,
    ST_CONNECT = 0x1000,
    ST_CONNECT_LOOP,
    ST_CONNECT_EXIT,
    ST_ACCEPT = ST_CONNECT * 2,
    CB_ACCEPT_LOOP,
    CB_ACCEPT_EXIT,
    CB_ALERT = ST_ACCEPT * 2,
    CB_READ_ALERT = CB_ALERT + CB_READ,
    CB_WRITE_ALERT = CB_ALERT + CB_WRITE
}

@safe
class SSLSocketException : SocketException
{
    immutable SSLErrorCodes error_code;
    this(immutable(char)[] msg, const SSLErrorCodes error_code = SSLErrorCodes.SSL_ERROR_NONE,
        string file = __FILE__, size_t line = __LINE__) pure nothrow
    {
        this.error_code = error_code;
        import std.exception : assumeWontThrow;

        immutable _msg = assumeWontThrow(format("%s (%s)", msg, error_code));
        super(_msg, file, line);
    }
}

version(WOLFSSL)
{
    import tagion.network.wolfssl.c.ssl_mod;
    import tagion.network.wolfssl.c.error_ssl;
    alias SSL_new = wolfSSL_new;
    enum SSLErrorCodes : wolfSSL_ErrorCodes
    {
        SSL_ERROR_NONE = cast(wolfSSL_ErrorCodes)0,
        SSL_ERROR_WANT_WRITE = cast(wolfSSL_ErrorCodes).SSL_ERROR_WANT_WRITE,
        SSL_ERROR_WANT_READ = cast(wolfSSL_ErrorCodes).SSL_ERROR_WANT_READ,
        SSL_ERROR_WANT_X509_LOOKUP = cast(wolfSSL_ErrorCodes).SSL_ERROR_WANT_X509_LOOKUP,
        SSL_ERROR_SYSCALL = cast(wolfSSL_ErrorCodes).SSL_ERROR_SYSCALL,
        SSL_ERROR_ZERO_RETURN = cast(wolfSSL_ErrorCodes).SSL_ERROR_ZERO_RETURN,
        SSL_ERROR_WANT_CONNECT = cast(wolfSSL_ErrorCodes).SSL_ERROR_WANT_CONNECT,
        SSL_ERROR_WANT_ACCEPT = cast(wolfSSL_ErrorCodes).SSL_ERROR_WANT_ACCEPT,
        SSL_ERROR_SSL = cast(wolfSSL_ErrorCodes).SSL_ERROR_SSL,
        SSL_ERROR_WANT_ASYNC = cast(wolfSSL_ErrorCodes)9000,
        SSL_ERROR_WANT_ASYNC_JOB = cast(wolfSSL_ErrorCodes)9001
    }

    alias SSL_CTX = WOLFSSL_CTX;
    alias SSL = WOLFSSL;
    alias SSL_CTX_new = wolfSSL_CTX_new;
    alias TLS_client_method = wolfTLS_client_method;
    alias TLS_server_method = wolfTLS_server_method;
    alias SSL_get_error = wolfSSL_get_error;
    alias SSL_connect = wolfSSL_connect;
    alias ERR_print_errors_fp = wolfSSL_ERR_print_errors_fp;
    alias ERR_clear_error = wolfSSL_ERR_clear_error;
    alias SSL_set_fd = wolfSSL_set_fd;
    alias SSL_pending = wolfSSL_pending;
    alias SSL_read = wolfSSL_read;
    alias SSL_accept = wolfSSL_accept;
    alias SSL_CTX_use_certificate_file = wolfSSL_CTX_use_certificate_file;
    alias SSL_write = wolfSSL_write;
    alias SSL_set_verify = wolfSSL_set_verify;
    alias SSL_free = wolfSSL_free;
    alias SSL_CTX_free = wolfSSL_CTX_free;
    //@trusted {
    alias SSL_CTX_check_private_key = wolfSSL_CTX_check_private_key;
    alias SSL_CTX_use_PrivateKey_file = wolfSSL_CTX_use_PrivateKey_file;
    //}
    alias SSL_alert_desc_string_long = wolfSSL_alert_desc_string_long;
    alias SSL_state_string_long = wolfSSL_state_string_long;
    alias ERR_error_string_n = wolfSSL_ERR_error_string_n;
    extern (C) 
    {
        import tagion.crypto.aes.openssl_aes.aes;
        void AES_cbc_encrypt(const char* inputdata, char* outdata, size_t count, AES_KEY* keydata, char* iv, int enc)
        {
            return wolfSSL_AES_cbc_encrypt(inputdata, outdata, count, keydata, iv, enc);
        }

        int AES_set_encrypt_key(const ubyte* userKey, const int bits, AES_KEY* key)
        {
            return wolfSSL_AES_set_encrypt_key(userKey, bits, key);
        }

        int AES_set_decrypt_key(const ubyte* userKey, const int bits, AES_KEY* key) 
        {
            return wolfSSL_AES_set_decrypt_key(userKey, bits, key);
        }

        void SSL_set_info_callback(void* a, void* b)
        {
            auto ctx_ssl = wolfSSL_get_SSL_CTX(cast(WOLFSSL*)a);
            //io.writeln("<>", ctx_ssl == SSLSocket.server_ctx, ctx_ssl == SSLSocket.client_ctx);
            wolfSSL_CTX_set_info_callback(ctx_ssl, b);
        }
        char* strerror(int errnum) @trusted;

        int SSL_get_state(const WOLFSSL* ssl) @trusted
        {
            return wolfSSL_state(ssl);
        }
    }
}
else
{
    extern (C)
    {
        enum SSL_VERIFY_NONE = 0;
        enum SSL_FILETYPE_PEM = 1;

        struct SSL;
        struct SSL_CTX;
        struct SSL_METHOD;

        @trusted
        protected
        {
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
            int SSL_get_state(const SSL* ssl);

            void ERR_clear_error();
            void ERR_print_errors_fp(FILE* file);
            ulong ERR_get_error();
            void ERR_error_string_n(ulong e, char* buf, size_t len);
            char* strerror(int errnum);
            //        void ERR_error_string(ulong e, char* buf);
            void SSL_set_info_callback(SSL* ssl, void*);
            char* SSL_alert_type_string(int);
            char* SSL_alert_type_string_long(int);
            char* SSL_alert_desc_string_long(int);
            char* SSL_state_string_long(const SSL*);
        }
    }

    enum SSLErrorCodes
    {
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
}

/++
 Socket for OpenSSL
+/
@safe
class SSLSocket : Socket
{
    protected
    {
        debug
        {
            pragma(msg, "DEBUG: SSLSocket compiled in debug mode");
            enum in_debugging_mode = true;

            import std.stdio : writeln;

            static void printDebugInformation(string msg)
            {
                int i;
                writeln(msg);
            }
        }
        else
        {
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
    protected void init(bool verifyPeer, EndpointType et)
    {
        checkContext(et);
        _ssl = SSL_new(_ctx);

        if (et is EndpointType.Client)
        {
            SSL_set_fd(_ssl, this.handle);
            if (!verifyPeer)
            {
                SSL_set_verify(_ssl, SSL_VERIFY_NONE, null);
            }
        }
    }

    protected void checkContext(EndpointType et)
    out
    {
        assert(_ctx);
    }
    do
    {
        synchronized
        {

            //Maybe implement more versions....
            if (et is EndpointType.Client)
            {
                if (client_ctx is null)
                {
                    client_ctx = SSL_CTX_new(TLS_client_method());
                }
                _ctx = client_ctx;
            }
            else if (et is EndpointType.Server)
            {
                if (server_ctx is null)
                {
                    server_ctx = SSL_CTX_new(TLS_server_method());
                }
                _ctx = server_ctx;
            }
        }

    }

    /++
     Configure the certificate for the SSL
     +/
    @trusted
    void configureContext(string certificate_filename, string prvkey_filename)
    in
    {
        auto empty_cfn = certificate_filename.length == 0;
        auto empty_pvk_fn = prvkey_filename.length == 0;
        if (empty_cfn || empty_pvk_fn)
            throw new SSLSocketException("Empty file paths inputs");
    }
    do
    {
        if (SSL_CTX_use_certificate_file(_ctx, certificate_filename.toStringz, SSL_FILETYPE_PEM) <= 0)
        {
            ERR_print_errors_fp(stderr);
            static if (in_debugging_mode)
            {
                printDebugInformation("Error in setting certificate");
            }
            throw new SSLSocketException("ssl ctx certificate");
        }

        if (SSL_CTX_use_PrivateKey_file(_ctx, prvkey_filename.toStringz, SSL_FILETYPE_PEM) <= 0)
        {
            ERR_print_errors_fp(stderr);
            static if (in_debugging_mode)
            {
                printDebugInformation("Error in setting prvkey");
            }

            throw new SSLSocketException("ssl ctx private key");
        }
        if (!SSL_CTX_check_private_key(_ctx))
        {
            static if (in_debugging_mode)
            {
                printDebugInformation("Error private key not set correctly");
            }
            throw new SSLSocketException("Private key not set correctly");
        }
    }

    /++
     Cleans the SSL error que
     +/
    void clearError()
    {
        ERR_clear_error();
    }

    /++
     Connect to an address
     +/
    override void connect(Address to)
    {
        super.connect(to);
        io.writeln("before", cast(SSL_CB_POINTS)SSL_get_state(_ssl));
        const res = SSL_connect(_ssl);
        io.writeln("after", cast(SSL_CB_POINTS)SSL_get_state(_ssl));
        check_error(res, true);
    }

    /++
     Send a buffer to the socket using the socket result
     +/
    @trusted
    override ptrdiff_t send(const(void)[] buf, SocketFlags flags)
    {
        auto res_val = SSL_write(_ssl, buf.ptr, cast(int) buf.length);
        const ssl_error = cast(SSLErrorCodes) SSL_get_error(_ssl, res_val);
        check_error(res_val);
        return res_val;
    }

    /++
     Send a buffer to the socket with no result
     +/
    override ptrdiff_t send(const(void)[] buf)
    {
        return send(buf, SocketFlags.NONE);
    }

    version(WOLFSSL)
    {
        static void check_wolfssl_error(ref SSLErrorCodes error)
        {
            io.writeln("<"~str_error(error)~'>');
            with (wolfSSL_ErrorCodes) switch (cast(wolfSSL_ErrorCodes)error)
            {
                case SOCKET_ERROR_E:
                    error = SSLErrorCodes.SSL_ERROR_SYSCALL;
                    return;
                default:
                    return;
            }
        }
    }

    /++
     Check the return result for a SSL system function
     +/
    void check_error(const int res, const bool check_read_write = false) const
    {
        auto ssl_error = cast(SSLErrorCodes) SSL_get_error(_ssl, res);
        version(WOLFSSL)
        {
            enum WOLFSSL_ERROR_MARKER = -299;
            if (ssl_error < WOLFSSL_ERROR_MARKER)
            {
                this.check_wolfssl_error(ssl_error);              
            }
        }
        with (SSLErrorCodes) final switch (ssl_error)
        {
        case SSL_ERROR_NONE:
            // Ignore
            break;
        case SSL_ERROR_WANT_WRITE,
        SSL_ERROR_WANT_READ:
            if (check_read_write)
            {
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
    uint pending()
    {
        const result = SSL_pending(_ssl);
        return cast(uint) result;
    }

    /++
     Receive a buffer from the socket using the flags
     +/
    @trusted
    override ptrdiff_t receive(void[] buf, SocketFlags flags)
    {
        const res_val = SSL_read(_ssl, buf.ptr, cast(uint) buf.length);
        check_error(res_val);
        return res_val;
    }

    /++
     Receive a buffer from the socket with not flags
     +/
    override ptrdiff_t receive(void[] buf)
    {
        return receive(buf, SocketFlags.NONE);
    }

    version (none)
    {
        @trusted
        int receiveNonBlocking(void[] buf, ref int pending_in_buffer)
        in
        {
            assert(!this.blocking);
        }
        do
        {
            int res = SSL_read(_ssl, buf.ptr, cast(int) buf.length);

            check_error(res);
            pending_in_buffer = SSL_pending(_ssl);

            return res;
        }
    }

    version (none) static string errorMessage(const SSLErrorCodes ssl_error)
    {
        return format("SSL Error: %s. SSL error code: %d", ssl_error, ssl_error);
    }

    /++
     Returns:
     the SSL system error message
     +/
    @trusted
    static string str_error(const int errornum)
    {
        const str = strerror(errornum);
        import std.string : fromStringz;
        const auto error_text = fromStringz(str).idup;
        enum WOLFSSL_ERROR_MARKER = -299;
        if (SSLSocket.isKnownError(error_text))
        {
            return error_text;
        }
        else if (errornum < WOLFSSL_ERROR_MARKER)
        {
            enum description_size = 200;
            char[description_size] new_description;
            ERR_error_string_n(errornum, new_description.ptr, description_size);
            return fromStringz(new_description).idup;
        }
        return "No data";
    }

    version (none) @trusted
    static string err_string()
    {
        enum ERROR_LENGTH = 0x100;
        const error_code = ERR_get_error;
        scope char[ERROR_LENGTH] err_text;
        ERR_error_string_n(ERR_get_error, err_text.ptr, ERROR_LENGTH);
        import std.string : fromStringz;

        return fromStringz(err_text.ptr).idup;
    }

    static bool isKnownError(ref const string error_descr)
    {
        import std.algorithm;
        return error_descr.startsWith("Unknown error ") == 0;
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
    bool acceptSSL(ref SSLSocket ssl_client, Socket client)
    {
        if (ssl_client is null)
        {
            static if (in_debugging_mode)
            {
                printDebugInformation("Accepting new client");
            }
            // Socket client = super.accept();
            if (!client.isAlive)
            {
                client.close;
                throw new SSLSocketException("Socket could not connect to client. Socket closed.");
            }
            client.blocking = false;
            ssl_client = new SSLSocket(client.handle, EndpointType.Server, client.addressFamily);
            const fd_res = SSL_set_fd(ssl_client.getSSL, client.handle);
            if (!fd_res)
            {
                return false;
            }
        }

        auto c_ssl = ssl_client.getSSL;

        const res = SSL_accept(c_ssl);
        bool accepted;
        const int_error = SSL_get_error(c_ssl, res);
        const ssl_error = cast(SSLErrorCodes) int_error;

        version(WOLFSSL)
        {
            enum WOLFSSL_ERROR_MARKER = -299;
            if (int_error < WOLFSSL_ERROR_MARKER)
            {
                this.processingWolfSSLError(ssl_error);
            }
        }

        with (SSLErrorCodes) switch (ssl_error)
        {
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
            io.writeln("<<"~str_error(ssl_error)~">>");
            throw new SSLSocketException(format("SSL Error. SSL error code: %d.", ssl_error), SSL_ERROR_SSL);
            break;
        }
        return !SSL_pending(c_ssl) && accepted;
    }

    version(WOLFSSL)
    {
        static void processingWolfSSLError(wolfSSL_ErrorCodes _error)
        {
            switch(_error)
            {
                case wolfSSL_ErrorCodes.SOCKET_ERROR_E:
                case wolfSSL_ErrorCodes.SIDE_ERROR:
                    throw new SSLSocketException(str_error(_error), SSLErrorCodes.SSL_ERROR_SSL);
                default:
                    return;
            }
        }
    }

    /++
       Reject a client connect and close the socket
     +/
    void rejectClient()
    {
        auto client = super.accept();
        client.close();
    }

    /++
     Disconnect the socket
     +/
    void disconnect()
    {
        static if (in_debugging_mode)
        {
            printDebugInformation("Disconnet client. Closing client and clean up SSL.");
        }
        try
        {
            if (_ssl !is null)
            {
                SSL_free(_ssl);
            }

            if ((client_ctx !is null || server_ctx !is null) &&
                client_ctx != _ctx && server_ctx != _ctx && _ctx !is null)
            {

                SSL_CTX_free(_ctx);
            }
        }
        catch (Exception ex)
        {
            static if (in_debugging_mode)
            {
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
    SSL* getSSL()
    {
        return this._ssl;
    }

    /++
     Constructs a new socket
     +/
    this(AddressFamily af, EndpointType et,
        SocketType type = SocketType.STREAM, bool verifyPeer = true)
    {
        super(af, type);
        init(verifyPeer, et);
    }

    /// ditto
    this(socket_t sock, EndpointType et, AddressFamily af)
    {
        super(sock, af);
        init(true, et);
    }

    static private void reset()
    {
        if (server_ctx !is null)
        {
            SSL_CTX_free(server_ctx);
            server_ctx = null;
        }
        if (client_ctx !is null)
        {
            SSL_CTX_free(client_ctx);
            client_ctx = null;
        }
    }

    static ~this()
    {
        reset();
    }

    unittest
    {
        import std.array;
        import std.string;
        import std.file;
        import tagion.basic.Basic : fileId;

        static void optionGenKeyFiles(ref string out_cert_path, ref string out_key_path)
        {
            import tagion.network.SSLOptions;
            import std.algorithm.iteration : each;
            import std.process;
            import std.path;

            string cert_path = fileId!SSLSocket("pem").fullpath;
            string key_path = fileId!SSLSocket("key.pem").fullpath;
            if (!exists(cert_path) || !exists(key_path))
            {
                string stab = "stab";
                OpenSSL temp = OpenSSL();
                temp.days = 1000;
                temp.key_size = 1024;
                temp.private_key = key_path;
                temp.certificate = cert_path;
                auto process = pipeProcess(temp.command.array);
                scope (exit)
                {
                    wait(process.pid);
                }
                temp.city = stab;
                temp.state = stab;
                temp.country = "UA";
                temp.organisation = stab;
                temp.email = stab;
                temp.name = stab;
                temp.config.each!(a => process.stdin.writeln(a));
                process.stdin.writeln(".");
                process.stdin.flush;
            }
            out_cert_path = cert_path;
            out_key_path = key_path;
        }

        //! [client creation circle]
        {
            // io.writeln("LAUNCH UNIT TEST SSL_Socket");

            SSLSocket testItem_client = new SSLSocket(AddressFamily.UNIX, EndpointType.Client);
            assert(testItem_client._ctx !is null);
            assert(SSLSocket.server_ctx is null);
            assert(SSLSocket.client_ctx !is null);
            assert(SSLSocket.client_ctx == testItem_client._ctx);
            SSLSocket.reset();
        }

        //! [server creation circle]
        {
            // io.writeln("LAUNCH SERVER CREATION CIRCLE");

            SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
            assert(testItem_server._ctx !is null);
            assert(SSLSocket.server_ctx !is null);
            assert(SSLSocket.client_ctx is null);
            assert(SSLSocket.server_ctx == testItem_server._ctx);
            SSLSocket.reset();
        }

        //! [Waiting for first acception]
        {
            //io.writeln("LAUNCH ACCEPTION");

            SSLSocket item = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
            SSLSocket ssl_client = new SSLSocket(AddressFamily.UNIX, EndpointType.Client);
            Socket client = new Socket(AddressFamily.UNIX, SocketType.STREAM);
            bool result = false;
            try
            {
                result = item.acceptSSL(ssl_client, client);
            }
            catch (SSLSocketException exception)
            {
                //io.writeln("EXEPTION ACCEPTION CORRECT "~exception.msg~"  "~lastSocketError);
                assert(exception.error_code == SSLErrorCodes.SSL_ERROR_SSL);
            }
            assert(result == false);
            SSLSocket.reset();
        }

        //! [File reading - incorrect certificate]
        {
            SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
            bool result = false;
            try
            {
                testItem_server.configureContext("_", "_");
            }
            catch (SSLSocketException _exception)
            {
                // io.writeln(_exception.msg);
                result = _exception.msg == "ssl ctx certificate (SSL_ERROR_NONE)";
            }
            assert(result);
            SSLSocket.reset();
        }

        //! [File reading - empty path]
        {
            //io.writeln("Empty filepaths checking");

            SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
            string empty_path = "";
            bool result = false;
            try
            {
                testItem_server.configureContext(empty_path, empty_path);
            }
            catch (SSLSocketException _exception)
            {
                result = _exception.msg == "Empty file paths inputs (SSL_ERROR_NONE)";
            }
            assert(result);
            SSLSocket.reset();
        }

        //! [file loading correct]
        {
            // io.writeln("Load certificate/key files");

            string cert_path;
            string key_path;
            optionGenKeyFiles(cert_path, key_path);
            SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
            try
            {
                testItem_server.configureContext(cert_path, key_path);
            }
            catch (SSLSocketException exception)
            {
                assert(false);
            }
            SSLSocket.reset();
        }

        //! [file loading key incorrect]
        {
            // writeln("Load false key files");
            string cert_path, stub;
            optionGenKeyFiles(cert_path, stub);
            auto false_key_path = cert_path;
            SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
            bool result = false;
            try
            {
                testItem_server.configureContext(cert_path, false_key_path);
            }
            catch (SSLSocketException exception)
            {
                result = exception.msg == "ssl ctx private key (SSL_ERROR_NONE)";
            }
            assert(result);
            SSLSocket.reset();
        }

        //! [correct acception]
        {
            // writeln("PROTO SOCKET ACCEPTION START");

            SSLSocket empty_socket = null;
            SSLSocket ssl_client = new SSLSocket(AddressFamily.UNIX, EndpointType.Client);
            Socket socket = new Socket(AddressFamily.UNIX, SocketType.STREAM);
            bool result = false;
            try
            {
                result = ssl_client.acceptSSL(empty_socket, socket);
            }
            catch (SSLSocketException exception)
            {
                version(WOLFSSL)
                {
                    result = exception.msg == "error state on socket (SSL_ERROR_SSL)";
                }
                else
                {
                    result = exception.msg == "Input/output error (SSL_ERROR_SYSCALL)";
                }
            }
            assert(result);
            SSLSocket.reset();
        }

        //! [checking -1 error code]
        {
            static if (SSLErrorCodes.SSL_ERROR_WANT_ASYNC == 9)
            {
                bool result = false;
                const invalid_error_code = -1;
                SSLSocket socket = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
                try
                {
                    socket.check_error(invalid_error_code, true);
                }
                catch (SSLSocketException except)
                {
                    result = except.msg == "Input/output error (SSL_ERROR_SYSCALL)";
                }
                assert(result);
            }
        }

        //! [checking 0 error code]
        {
            static if (SSLErrorCodes.SSL_ERROR_WANT_ASYNC == 9)
            {
                bool result = false;
                const invalid_error_code = 0;
                SSLSocket socket = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
                try
                {
                    socket.check_error(invalid_error_code, true);
                }
                catch (SSLSocketException except)
                {
                    // io.writeln(except.msg);
                    result = except.msg == "Input/output error (SSL_ERROR_SYSCALL)";
                }
                assert(result);
            }
        }

        //! [checking valid responce]
        {
            bool result = true;
            const initial_responce_code = 1;
            const final_responce_code = 3;
            SSLSocket socket = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
            foreach (responce; initial_responce_code .. final_responce_code)
            {
                try
                {
                    socket.check_error(responce, true);
                }
                catch (SSLSocketException except)
                {
                    result = false;
                }
            }
            assert(result);
        }

        /**
        * @brief test working but has problems with environment (problems with socket acception for example)
        * possible test infinite circle (wait socket acception)
        */
        //! [encrypt/decrypt message exchange test]
        version (none) // @NOTE: remove that for launch circle
        {
            import core.thread;

            import tagion.basic.Basic : TrustedConcurrency;

            mixin TrustedConcurrency;

            static const ubyte[] send_test_data = [8, 7, 6, 5, 4];
            static const string ut_adress = "127.0.0.1";
            static const int port = 4433;
            static const AddressFamily protocol = AddressFamily.INET;
            static bool[] finish_flags = [0, 0];

            static void loadcerts_(ref SSLSocket socket, string descript)
            {
                if (socket !is null)
                {
                    string cert_path;
                    string key_path;
                    optionGenKeyFiles(cert_path, key_path);
                    try
                    {
                        socket.configureContext(cert_path, key_path);
                    }
                    catch (SSLSocketException exeption)
                    {
                        io.writeln(descript ~ " Loading keys failed");
                    }
                }
            }

            static void client_()
            {
                import std.string;

                static void ssl_callback_client(const SSL* ssl, int a, int b)
                {
                    SSL_CB_POINTS point = cast(SSL_CB_POINTS) a;
                    io.writeln("Client ", point);
                    io.writeln("CLIENT RET ", b);
                    auto str = SSL_alert_desc_string_long(b);
                    if (str != null)
                        io.writeln("CLNT " ~ fromStringz(str));
                    assert((a & SSL_CB_POINTS.CB_ALERT) == 0);
                }

                auto connect_adress = new InternetAddress(ut_adress, port);
                SSLSocket client = new SSLSocket(protocol, EndpointType.Client);
                SSL_set_info_callback(client.getSSL, &ssl_callback_client);
                loadcerts_(client, "client");
                io.writeln("Begin client connecting");
                client.connect(connect_adress);
                io.writeln("Sending client data");
                auto result = client.send(send_test_data);
                io.writeln("Send result! ", result);
                finish_flags[0] = true;
            }

            static void server_()
            {
                static void ssl_callback_server(const SSL* ssl, int a, int b)
                {
                    import std.string;

                    SSL_CB_POINTS point = cast(SSL_CB_POINTS) a;
                    io.writeln("Callback here ", point);
                    io.writeln("SRV RET ", b);
                    auto str = SSL_alert_desc_string_long(b);
                    if (str != null)
                        io.writeln("SRVR " ~ fromStringz(str));
                    static if (SSLErrorCodes.SSL_ERROR_WANT_ASYNC == 9)
                    {
                        io.writeln("<SRVR> " ~ fromStringz(SSL_state_string_long(ssl)));
                    }
                    assert((a & SSL_CB_POINTS.CB_ALERT) == 0);
                }

                auto server_adress = new InternetAddress(ut_adress, port);
                SSLSocket server = new SSLSocket(protocol, EndpointType.Server);
                io.writeln("Socket is alive : ", int(server.isAlive));
                loadcerts_(server, "server");
                server.blocking = false;
                SSL_set_info_callback(server.getSSL, &ssl_callback_server);
                try
                {
                    server.bind(server_adress);
                }
                catch (SocketOSException except)
                {
                    io.writeln("BINDING FAILED " ~ except.msg);
                }
                io.writeln("Listening launch");
                try
                {
                    server.listen(100);
                }
                catch (SocketOSException except)
                {
                    io.writeln("LISTEN FAILED");
                }
                io.writeln("Try to accept!!!");
                SSLSocket waiter_socket = null;
                int result = -3;
                Socket acc_socket = null;
                while (acc_socket is null)
                {
                    try
                    {
                        acc_socket = server.accept;
                    }
                    catch (SocketOSException exception)
                    {
                        io.writeln("Accepting failed ~ " ~ exception.msg);
                    }
                }
                scope (exit)
                {
                    acc_socket.shutdown(SocketShutdown.BOTH);
                }
                io.writeln("Server accepting with SSL - ", int(acc_socket !is null));
                try
                {
                    while (result < 1)
                    {
                        result = acc_socket ? server.acceptSSL(waiter_socket, acc_socket) : false;
                        if (waiter_socket !is null)
                            SSL_set_info_callback(waiter_socket.getSSL, &ssl_callback_server);
                    }
                }
                catch (SSLSocketException exception)
                {
                    io.writeln("Accept exception ", exception.msg);
                }
                io.writeln("Server unit start " ~ ((result == 1) ? "Complete" : "Fail"));
                assert(result == 1);
                Thread.sleep(dur!("seconds")(2));
                ubyte[10] readplc;
                auto offset = waiter_socket.receive(readplc);
                assert(readplc[0 .. offset] == send_test_data);
                finish_flags[1] = true;
                io.writeln("SSL server function DONE");
            }

            spawn(&server_);
            spawn(&client_);
            while (!finish_flags[1] || !finish_flags[0])
            {
            }
            SSLSocket.reset();
            io.writeln("Circle encrypt/decrypt complete");
        }
    }
}
