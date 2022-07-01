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
            string file = __FILE__, size_t line = __LINE__) pure nothrow {
        this.error_code = error_code;
        import std.exception : assumeWontThrow;
        immutable _msg=assumeWontThrow(format("%s (%s)", msg, error_code));
        super(_msg, file, line);
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
        char* strerror(int errnum);
        //        void ERR_error_string(ulong e, char* buf);
        void SSL_set_info_callback(SSL* ssl, void*);
        char *SSL_alert_type_string(int);
        char *SSL_alert_type_string_long(int);
        char *SSL_alert_desc_string_long(int);
        char* SSL_state_string_long(const SSL*);
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

enum SSL_CB_POINTS : int 
{
    CB_LOOP = 1,
    CB_EXIT = 2,
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
        synchronized {

        //Maybe implement more versions....
        if (et is EndpointType.Client) {
            if (client_ctx is null) {
                client_ctx = SSL_CTX_new(TLS_client_method());
            }
            _ctx = client_ctx;
        }
        else if (et is EndpointType.Server) {
            if (server_ctx is null) {
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
    in {
        auto empty_cfn = certificate_filename.length == 0;
        auto empty_pvk_fn = prvkey_filename.length == 0;
        if (empty_cfn || empty_pvk_fn)
            throw new SSLSocketException("Empty file paths inputs");
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
            ssl_client = new SSLSocket(client.handle, EndpointType.Server, client.addressFamily);
            const fd_res = SSL_set_fd(ssl_client.getSSL, client.handle);
            if (!fd_res) {
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

    static private void reset() {
        if (server_ctx !is null) {
            SSL_CTX_free(server_ctx);
            server_ctx = null;
        }
        if (client_ctx !is null) {
            SSL_CTX_free(client_ctx);
            client_ctx = null;
        }
    }

    static ~this() {
        reset();
    }    
        
    //! [client creation circle]
    unittest
    {      
           import std.stdio;           
           writeln("LAUNCH UNIT TEST SSL_Socket");
           SSLSocket testItem_client = new SSLSocket(AddressFamily.UNIX, EndpointType.Client);
           assert(testItem_client._ctx !is null);
           assert(SSLSocket.server_ctx is null);
           assert(SSLSocket.client_ctx !is null);
           assert(SSLSocket.client_ctx == testItem_client._ctx);
           SSLSocket.reset();
    }

    //! [server creation circle]
    unittest
    {
           import std.stdio;
           writeln("LAUNCH SERVER CREATION CIRCLE");     
           SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
           assert(testItem_server._ctx !is null);
           assert(SSLSocket.server_ctx !is null);
           assert(SSLSocket.client_ctx is null);
           assert(SSLSocket.server_ctx == testItem_server._ctx);
           SSLSocket.reset();
    }

    //! [Acception] 
    unittest
    {
        import std.stdio;
        import std.array;
        writeln("LAUNCH ACCEPTION");  
        SSLSocket item = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
        SSLSocket ssl_client = new SSLSocket(AddressFamily.UNIX, EndpointType.Client);
        Socket client = new Socket(AddressFamily.UNIX, SocketType.STREAM);
        bool result = false;
        try {
            result = item.acceptSSL(ssl_client, client);
        }
        catch(SSLSocketException exception)
        {
            writeln("EXEPTION ACCEPTION CORRECT "~exception.msg~"  "~lastSocketError);
            assert(exception.error_code == SSLErrorCodes.SSL_ERROR_SSL);
        }
        assert(result == false);
        SSLSocket.reset();
    }

    //! [File reading - incorrect]
    unittest
    {
        import std.stdio;
        SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
        bool result = false;
        try {
            testItem_server.configureContext("_", "_");
        }
        catch(SSLSocketException _exception)
        {
            writeln("Exception load file "~_exception.msg);
            result = true;
        }
        assert(result);
        SSLSocket.reset();
    }

    //! [File reading - empty path]
    unittest
    {
        import std.stdio;
        SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
        string empty_path = "";
        bool flag = false;
        writeln("Empty filepaths checking");
        try {
            testItem_server.configureContext(empty_path, empty_path);
        }
        catch(SSLSocketException _exception)
        {
            flag = _exception.msg == "Empty file paths inputs (SSL_ERROR_NONE)";
        }
        assert(flag);
        SSLSocket.reset();
    }

    //! [file loading correct]
    unittest
    { 
        import std.stdio;
        import std.string;
        import std.process;
        import std.file;
        writeln("Load certificate/key files");
        string test_bench_path = environment.get("TESTBENCH");
        if (test_bench_path.length)
            test_bench_path = test_bench_path~"//";        
        string cert_path = test_bench_path~"../../../pem_files/domain.pem";       
        string key_path = test_bench_path~"../../../pem_files/domain.key.pem";
        if (!exists(cert_path) || !exists(key_path))
            return; //@TODO need UT utility for resolving paths and launching UT. Temporary solution - skip tests with path problem
        SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
        try {
            testItem_server.configureContext(cert_path, key_path);
        }
        catch(SSLSocketException exception)
        {
            writeln("TEST FAILED: check files/paths");
            assert(false);
        }
        SSLSocket.reset();
    }

    //! [file loading key incorrect]
    unittest
    {
        import std.stdio;
        import std.process;
        import std.file;
        writeln("Load false key files");
        string test_bench_path = environment.get("TESTBENCH");
        if (test_bench_path.length)
            test_bench_path = test_bench_path~"//";
        string cert_path = test_bench_path~"../../../pem_files/domain.pem";
        auto false_key_path = cert_path;
         if (!exists(cert_path))
            return; //@TODO need UT utility for resolving paths and launching UT. Temporary solution - skip tests with path problem
        SSLSocket testItem_server = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
        bool flag = false;
        try {
            testItem_server.configureContext(cert_path, false_key_path);
        }
        catch(SSLSocketException exception)
        {
            flag = exception.msg == "ssl ctx private key (SSL_ERROR_NONE)";
            writeln("TEST Complete: test throw exception "~exception.msg);
        }
        assert(flag);
        SSLSocket.reset();
    }

    //! [correct acception]
    unittest 
    {        
        import std.stdio;
        import std.string;
        writeln("PROTO SOCKET ACCEPTION START");
        SSLSocket empty_socket = null;
        SSLSocket ssl_client = new SSLSocket(AddressFamily.UNIX, EndpointType.Client);
        Socket socket = new Socket(AddressFamily.UNIX, SocketType.STREAM);
        bool flag = false;
        try {
            flag = ssl_client.acceptSSL(empty_socket, socket);
        }
        catch(SSLSocketException exception)
        {            
            writeln("PROTO SOCKET ACCEPTION"~exception.msg~"___"~lastSocketError);
        } //*/
        writeln("PROTO SOCKET ACCEPTION FINISH "~(flag? "TRUE":"FALSE")~((empty_socket is null)? " NO CHANGED" : " is NULL"));
        //assert(flag);
        SSLSocket.reset();
    }

     //! [error checking]
    unittest 
    {
        enum SSL_TEST_ERRORS_DIAPASONE : int {
            FIRST_ERROR_CODE = -1,
            LAST_CODE = 2
        }
        SSLSocket socket = new SSLSocket(AddressFamily.UNIX, EndpointType.Server);
        int expection_count = 0;
        const int expecting_error_count = 2;
        foreach (int k; SSL_TEST_ERRORS_DIAPASONE.FIRST_ERROR_CODE .. SSL_TEST_ERRORS_DIAPASONE.LAST_CODE)
        {
            try {            
                socket.check_error(k, true);
            }
            catch(SSLSocketException except)
            {
                if (k < (SSL_TEST_ERRORS_DIAPASONE.LAST_CODE - 1))
                    expection_count++;
            }
        }
        assert(expection_count == expecting_error_count);
    }

    unittest 
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
                import std.process;
                import std.file;
                string test_bench_path = environment.get("TESTBENCH");
                if (test_bench_path.length)
                    test_bench_path = test_bench_path~"//";        
                string cert_path = test_bench_path~"../../../pem_files/domain.pem";       
                string key_path = test_bench_path~"../../../pem_files/domain.key.pem";
		        try
		        {
			        socket.configureContext(cert_path, key_path);
		        }
		        catch(SSLSocketException exeption)
		        {
			        writeln(descript~" Loading keys failed");
		        }
	        }
        }

        static void client_()
        {
            import std.string;
            static void ssl_callback_client(const SSL *ssl, int a, int b)
            {
	            SSL_CB_POINTS point = cast(SSL_CB_POINTS)a;
	            writeln("Client ", point);
	            writeln("CLIENT RET ", b);
	            auto str = SSL_alert_desc_string_long(b);
	            if (str != null)
	                writeln("CLNT "~fromStringz(str));
                assert((a & SSL_CB_POINTS.CB_ALERT) == 0);
            }
		    auto connect_adress = new InternetAddress(ut_adress, port);
		    SSLSocket client = new SSLSocket(protocol, EndpointType.Client);
		    SSL_set_info_callback(client.getSSL, &ssl_callback_client);
		    loadcerts_(client, "client");
		    writeln("Begin client connecting");
		    client.connect(connect_adress);
		    writeln("Sending client data");		
		    auto result = client.send(send_test_data);
		    writeln("Send result! ", result);
		    finish_flags[0] = true;
        }

        static void server_()
        {
            static void ssl_callback_server(const SSL *ssl, int a, int b)
            {
                import std.string;
                SSL_CB_POINTS point = cast(SSL_CB_POINTS)a;
                writeln("Callback here ", point);
                writeln("SRV RET ", b);
                auto str = SSL_alert_desc_string_long(b);
                if (str != null)
                    writeln("SRVR "~fromStringz(str));
                writeln("<SRVR> "~fromStringz(SSL_state_string_long(ssl)));
                assert((a & SSL_CB_POINTS.CB_ALERT) == 0);
            }
            auto server_adress = new InternetAddress(ut_adress, port);
            SSLSocket server = new SSLSocket(protocol, EndpointType.Server);
            writeln("Socket is alive : ", int(server.isAlive));
            loadcerts_(server, "server");
            server.blocking = false;
            SSL_set_info_callback(server.getSSL, &ssl_callback_server);
            try
            {
                server.bind(server_adress);
            }
            catch(SocketOSException except)
            {
                writeln("BINDING FAILED "~except.msg);
            }
            writeln("Listening launch");
            try
            {
                server.listen(100);
            }
            catch(SocketOSException except)
            {
                writeln("LISTEN FAILED");
            }
            writeln("Try to accept!!!");
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
	                writeln("Accepting failed ~ "~exception.msg);
	            }
	        }
	        writeln("Server accepting with SSL - ", int(acc_socket !is null));
	        try
	        {
	            while(result < 1)
	            {
	                result = acc_socket ? server.acceptSSL(waiter_socket, acc_socket) : false;
                    if(waiter_socket !is null)
                         SSL_set_info_callback(waiter_socket.getSSL, &ssl_callback_server);
                }
		    }
		    catch(SSLSocketException exception)
		    {
		        writeln("Accept exception ", exception.msg);
		    } //*/
		    writeln("Server unit start "~((result == 1)?"Complete" : "Fail"));
            assert(result == 1);
		    Thread.sleep(dur!("seconds")(2));
		    ubyte[10] readplc;
		    auto offset = waiter_socket.receive(readplc);
            assert(readplc[0 .. offset] == send_test_data);
            finish_flags[1] = true;
            writeln("SSL server function DONE");
        }

        spawn(&server_);
        spawn(&client_);
        while(!finish_flags[1] || !finish_flags[0]) {}
        SSLSocket.reset();
        writeln("Circle encrypt/decrypt complete");
    }
}
