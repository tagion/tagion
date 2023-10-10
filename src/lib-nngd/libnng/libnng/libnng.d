module libnng.libnng;

import std.meta : Alias;
import core.stdc.config;
import std.traits;
import core.stdc.stdio: printf;

@nogc nothrow extern (C)
{


enum NNG_MAJOR_VERSION = 1;
enum NNG_MINOR_VERSION = 6;
enum NNG_PATCH_VERSION = 0;

const int NNG_MAXADDRLEN = 128;

int NNG_PROTOCOL_NUMBER (int maj, int min) { return maj *16 + min; }

enum nng_errno : int {
        @("Ok!") NNG_OK = 0,
        @("Interrupted system call") NNG_EINTR = 1,
        @("Insufficient free memory exists.") NNG_ENOMEM = 2,
        @("An invalid URL or other data was supplied.") NNG_EINVAL = 3,
        @("Server instance is running.") NNG_EBUSY = 4,
        @("The operation timed out.") NNG_ETIMEDOUT = 5,
        @("The remote peer refused the connection.") NNG_ECONNREFUSED = 6,
        @("At least one of the sockets is not open.") NNG_ECLOSED = 7,
        @("Resource temporarily unavailable") NNG_EAGAIN = 8,
        @("The option or protocol is not supported.") NNG_ENOTSUP = 9,
        @("The address is already in use.") NNG_EADDRINUSE = 10,
        @("The context/dialer/listener cannot do what your want state.") NNG_ESTATE = 11,
        @("Handler is not registered with server.") NNG_ENOENT = 12,
        @("A protocol error occurred.") NNG_EPROTO = 13,
        @("The remote address is not reachable.") NNG_EUNREACHABLE = 14,
        @("The address is invalid or unavailable.") NNG_EADDRINVAL = 15,
        @("No permission to read the file.") NNG_EPERM = 16,
        @("The message is too large.") NNG_EMSGSIZE = 17,
        @("Software caused connection abort") NNG_ECONNABORTED = 18,
        @("The connection was reset by the peer.") NNG_ECONNRESET = 19,
        @("The operation was aborted.") NNG_ECANCELED = 20,
        @("") NNG_ENOFILES = 21,
        @("No space left on device") NNG_ENOSPC = 22,
        @("") NNG_EEXIST = 23,
        @("The option may not be modified.") NNG_EREADONLY = 24,
        @("The option may not read.") NNG_EWRITEONLY = 25,
        @("") NNG_ECRYPTO = 26,
        @("Authentication or authorization failure.") NNG_EPEERAUTH = 27,
        @("Option requires an argument: but one is not present.") NNG_ENOARG = 28,
        @("Parsed option matches more than one specification.") NNG_EAMBIGUOUS = 29,
        @("Incorrect type for option.") NNG_EBADTYPE = 30,
        @("Remote peer shutdown after sending data.") NNG_ECONNSHUT = 31,
        @("") NNG_EINTERNAL = 1000,
        @("") NNG_ESYSERR = 0x1000_0000,
        @("") NNG_ETRANERR = 0x2000_0000,
}

string nng_errstr(nng_errno errno) {
    switch(errno) { 
        static foreach(E; EnumMembers!nng_errno) {
            case E:
                enum error_text = getUDAs!(E, string)[0];
                return (error_text.length) ? error_text : E.stringof;
        }
    default:
        return null;
    }
    assert(0);
}

string nng_errstr( int errno ){
    return nng_errstr(cast(nng_errno)errno);
}

enum nng_flag {
     NNG_FLAG_ALLOC = 1 
    ,NNG_FLAG_NONBLOCK = 2
}

@safe:
T* ptr(T)(T[] arr) { return arr.length == 0 ? null : &arr[0]; }


// ------------------------------------- typedefs

struct nng_ctx {
    uint id;
};
struct nng_dialer {
    uint id;
};
struct nng_listener {
    uint id;
};
struct nng_pipe {
    uint id;
};
struct nng_socket {
    uint id;
};

alias nng_duration = int;

struct nng_msg {};
struct nng_stat {};
struct nng_aio {};

alias NNG_PIPE_INITIALIZER = Alias!(nng_pipe(0));
alias NNG_SOCKET_INITIALIZER = Alias!(nng_socket(0));
alias NNG_DIALER_INITIALIZER = Alias!(nng_socket(0));
alias NNG_LISTENER_INITIALIZER = Alias!(nng_socket(0));
alias NNG_CTX_INITIALIZER = Alias!(nng_socket(0));

alias NNG_DURATION_INFINITE = Alias!(nng_duration(-1));
alias NNG_DURATION_DEFAULT = Alias!(nng_duration(-2));
alias NNG_DURATION_ZERO = Alias!(nng_duration(0));

struct nng_sockaddr_inproc {
    ushort   sa_family;
    char[NNG_MAXADDRLEN] sa_name;
};

struct nng_sockaddr_path {
    ushort  sa_family;
    char[NNG_MAXADDRLEN] sa_path;
};

alias nng_sockaddr_ipc = nng_sockaddr_path;

struct nng_sockaddr_in6 {
    ushort sa_family;
    ushort sa_port;
    ubyte[16]  sa_addr;
    uint sa_scope;
};

struct nng_sockaddr_in {
    ushort sa_family;
    ushort sa_port;
    uint sa_addr;
};

struct nng_sockaddr_zt {
    ushort sa_family;
    ulong sa_nwid;
    ulong sa_nodeid;
    uint sa_port;
};

struct nng_sockaddr_abstract {
    ushort sa_family;
    ushort sa_len;       // will be 0 - 107 max.
    ubyte[107]  sa_name; // 108 linux/windows, without leading NUL
};

struct nng_sockaddr_storage {
    ushort sa_family;
    ulong[16] sa_pad;
};

union nng_sockaddr {
    ushort                s_family;
    nng_sockaddr_ipc      s_ipc;
    nng_sockaddr_inproc   s_inproc;
    nng_sockaddr_in6      s_in6;
    nng_sockaddr_in       s_in;
    nng_sockaddr_zt       s_zt;
    nng_sockaddr_abstract s_abstract;
    nng_sockaddr_storage  s_storage;
};
enum nng_sockaddr_family {
    NNG_AF_NONE     = 65535,
    NNG_AF_UNSPEC   = 0,
    NNG_AF_INPROC   = 1,
    NNG_AF_IPC      = 2,
    NNG_AF_INET     = 3,
    NNG_AF_INET6    = 4,
    NNG_AF_ZT       = 5, // ZeroTier
    NNG_AF_ABSTRACT = 6
};

struct nng_iov {
    void * iov_buf;
    size_t iov_len;
};


// ------------------------------------- common functions

void nng_fini();
void *nng_alloc(size_t);
void nng_free(void *, size_t);
char *nng_strdup(const char *);
char *nng_strerror(int);
void nng_strfree(char *);
char *nng_version() pure;

// ------------------------------------- system functions

alias nng_time = ulong;
struct nng_thread {};
struct nng_mtx {};
struct nng_cv {};

nng_time nng_clock();
void nng_msleep(nng_duration);
int nng_thread_create(nng_thread **, void function(void *), void *);
void nng_thread_set_name(nng_thread *, const char *);
void nng_thread_destroy(nng_thread *);
int nng_mtx_alloc(nng_mtx **);
void nng_mtx_free(nng_mtx *);
void nng_mtx_lock(nng_mtx *);
void nng_mtx_unlock(nng_mtx *);
int nng_cv_alloc(nng_cv **, nng_mtx *);
void nng_cv_free(nng_cv *);
void nng_cv_wait(nng_cv *);
int nng_cv_until(nng_cv *, nng_time);
void nng_cv_wake(nng_cv *);
void nng_cv_wake1(nng_cv *);
uint nng_random();

// ------------------------------------- opt functions

const string NNG_OPT_SOCKNAME                   = "socket-name";                // string 
const string NNG_OPT_RAW                        = "raw";                        // bool
const string NNG_OPT_PROTO                      = "protocol";                   // int:enum:NNG_*_(SELF|PEER)
const string NNG_OPT_PROTONAME                  = "protocol-name";              // string
const string NNG_OPT_PEER                       = "peer";                       // int:enum:NNG_*_(SELF|PEER)_NAME
const string NNG_OPT_PEERNAME                   = "peer-name";                  // string
const string NNG_OPT_RECVBUF                    = "recv-buffer";                // int
const string NNG_OPT_SENDBUF                    = "send-buffer";                // int
const string NNG_OPT_RECVFD                     = "recv-fd";                    // int:fd:(ro)
const string NNG_OPT_SENDFD                     = "send-fd";                    // int:fd:(ro)
const string NNG_OPT_RECVTIMEO                  = "recv-timeout";               // int:ms 
const string NNG_OPT_SENDTIMEO                  = "send-timeout";               // int:ms
const string NNG_OPT_LOCADDR                    = "local-address";              // for:nng_*_get_addr:nng_sockaddr/listener
const string NNG_OPT_REMADDR                    = "remote-address";             // for:nng_*_get_addr:nng_sockaddr/listener
const string NNG_OPT_URL                        = "url";                        // for:nng_*_get_string:string/listener
const string NNG_OPT_MAXTTL                     = "ttl-max";                    // int:ms
const string NNG_OPT_RECVMAXSZ                  = "recv-size-max";              // int
const string NNG_OPT_RECONNMINT                 = "reconnect-time-min";         // int:ms
const string NNG_OPT_RECONNMAXT                 = "reconnect-time-max";         // int:ms
const string NNG_OPT_TLS_CONFIG                 = "tls-config";                 // TODO:
const string NNG_OPT_TLS_AUTH_MODE              = "tls-authmode";               // TODO:
const string NNG_OPT_TLS_CERT_KEY_FILE          = "tls-cert-key-file";          // TODO:
const string NNG_OPT_TLS_CA_FILE                = "tls-ca-file";                // TODO:
const string NNG_OPT_TLS_SERVER_NAME            = "tls-server-name";            // TODO:
const string NNG_OPT_TLS_VERIFIED               = "tls-verified";               // TODO:
const string NNG_OPT_TLS_PEER_CN                = "tls-peer-cn";                // TODO:
const string NNG_OPT_TLS_PEER_ALT_NAMES         = "tls-peer-alt-names";         // TODO:
const string NNG_OPT_TCP_NODELAY                = "tcp-nodelay";                // bool
const string NNG_OPT_TCP_KEEPALIVE              = "tcp-keepalive";              // bool, int???
const string NNG_OPT_TCP_BOUND_PORT             = "tcp-bound-port";             // int:(ro)
const string NNG_OPT_IPC_SECURITY_DESCRIPTOR    = "ipc:security-descriptor";    // for:nng_stream_listener:ptr
const string NNG_OPT_IPC_PERMISSIONS            = "ipc:permissions";            // int:(ro)
const string NNG_OPT_IPC_PEER_UID               = "ipc:peer-uid";               // int:(ro) 
const string NNG_OPT_IPC_PEER_GID               = "ipc:peer-gid";               // int:(ro)
const string NNG_OPT_IPC_PEER_PID               = "ipc:peer-pid";               // int:(ro)
const string NNG_OPT_IPC_PEER_ZONEID            = "ipc:peer-zoneid";            // int:(ro)
const string NNG_OPT_WS_REQUEST_HEADERS         = "ws:request-headers";         // TODO:
const string NNG_OPT_WS_RESPONSE_HEADERS        = "ws:response-headers";        // TODO:
const string NNG_OPT_WS_RESPONSE_HEADER         = "ws:response-header:";        // TODO:
const string NNG_OPT_WS_REQUEST_HEADER          = "ws:request-header:";         // TODO:
const string NNG_OPT_WS_REQUEST_URI             = "ws:request-uri";             // TODO:
const string NNG_OPT_WS_SENDMAXFRAME            = "ws:txframe-max";             // TODO:
const string NNG_OPT_WS_RECVMAXFRAME            = "ws:rxframe-max";             // TODO:
const string NNG_OPT_WS_PROTOCOL                = "ws:protocol";                // TODO:
const string NNG_OPT_WS_SEND_TEXT               = "ws:send-text";               // TODO:
const string NNG_OPT_WS_RECV_TEXT               = "ws:recv-text";               // TODO:

struct nng_optspec {
    const char *o_name;  // Long style name (may be NULL for short only)
    int         o_short; // Short option (no clustering!)
    int         o_val;   // Value stored on a good parse (>0)
    bool        o_arg;   // Option takes an argument if true
};

int nng_opts_parse(int argc, const char **argv,
    const nng_optspec *opts, int *val, char **optarg, int *optidx);

// ------------------------------------- aio functions:

int nng_aio_alloc(nng_aio **, void function(void *), void *);
void nng_aio_free(nng_aio *);
void nng_aio_reap(nng_aio *);
void nng_aio_stop(nng_aio *);
int nng_aio_result(nng_aio *);
size_t nng_aio_count(nng_aio *);
void nng_aio_cancel(nng_aio *);
void nng_aio_abort(nng_aio *, int);
void nng_aio_wait(nng_aio *);
bool nng_aio_busy(nng_aio *);
void nng_aio_set_msg(nng_aio *, nng_msg *);
nng_msg *nng_aio_get_msg(nng_aio *);
int nng_aio_set_input(nng_aio *, uint, void *);
void *nng_aio_get_input(nng_aio *, uint);
int nng_aio_set_output(nng_aio *, uint, void *);
void *nng_aio_get_output(nng_aio *, uint);
void nng_aio_set_timeout(nng_aio *, nng_duration);
int nng_aio_set_iov(nng_aio *, uint, const nng_iov *);
bool nng_aio_begin(nng_aio *);
void nng_aio_finish(nng_aio *, int);
void nng_aio_defer(nng_aio *, void function(nng_aio *, void *, int), void *);
void nng_sleep_aio(nng_duration, nng_aio *);


// ------------------------------------- context functions

int nng_ctx_open(nng_ctx *, nng_socket);
int nng_ctx_close(nng_ctx);
int nng_ctx_id(nng_ctx);
int nng_ctx_recvmsg(nng_ctx, nng_msg **, int);
int nng_ctx_sendmsg(nng_ctx, nng_msg *, int);

int nng_ctx_get(nng_ctx, const char *, void *, size_t *);
int nng_ctx_get_bool(nng_ctx, const char *, bool *);
int nng_ctx_get_int(nng_ctx, const char *, int *);
int nng_ctx_get_size(nng_ctx, const char *, size_t *);
int nng_ctx_get_uint64(nng_ctx, const char *, ulong *);
int nng_ctx_get_string(nng_ctx, const char *, char **);
int nng_ctx_get_ptr(nng_ctx, const char *, void **);
int nng_ctx_get_ms(nng_ctx, const char *, nng_duration *);
int nng_ctx_get_addr(nng_ctx, const char *, nng_sockaddr *);

int nng_ctx_set(nng_ctx, const char *, const void *, size_t);
int nng_ctx_set_bool(nng_ctx, const char *, bool);
int nng_ctx_set_int(nng_ctx, const char *, int);
int nng_ctx_set_size(nng_ctx, const char *, size_t);
int nng_ctx_set_uint64(nng_ctx, const char *, ulong);
int nng_ctx_set_string(nng_ctx, const char *, const char *);
int nng_ctx_set_ptr(nng_ctx, const char *, void *);
int nng_ctx_set_ms(nng_ctx, const char *, nng_duration);
int nng_ctx_set_addr(nng_ctx, const char *, const nng_sockaddr *);
void nng_ctx_recv(nng_ctx, nng_aio *);
void nng_ctx_send(nng_ctx, nng_aio *);

// ------------------------------------- device functions 
int nng_device(nng_socket, nng_socket);
void nng_device_aio(nng_aio *, nng_socket, nng_socket);


// ------------------------------------- statistics functions TODO:


// ------------------------------------- socket functions

int nng_close(nng_socket);
int nng_socket_id(nng_socket);

int nng_socket_set(nng_socket, const char *, const void *, size_t);
int nng_socket_set_bool(nng_socket, const char *, bool);
int nng_socket_set_int(nng_socket, const char *, int);
int nng_socket_set_size(nng_socket, const char *, size_t);
int nng_socket_set_uint64(nng_socket, const char *, ulong);
int nng_socket_set_string(nng_socket, const char *, const char *);
int nng_socket_set_ptr(nng_socket, const char *, void *);
int nng_socket_set_ms(nng_socket, const char *, nng_duration);
int nng_socket_set_addr(nng_socket, const char *, const nng_sockaddr *);

int nng_socket_get(nng_socket, const char *, void *, size_t *);
int nng_socket_get_bool(nng_socket, const char *, bool *);
int nng_socket_get_int(nng_socket, const char *, int *);
int nng_socket_get_size(nng_socket, const char *, size_t *);
int nng_socket_get_uint64(nng_socket, const char *, ulong *);
int nng_socket_get_string(nng_socket, const char *, char **);
int nng_socket_get_ptr(nng_socket, const char *, void **);
int nng_socket_get_ms(nng_socket, const char *, nng_duration *);
int nng_socket_get_addr(nng_socket, const char *, nng_sockaddr *);

enum nng_pipe_ev {
    NNG_PIPE_EV_ADD_PRE,  // Called just before pipe added to socket
    NNG_PIPE_EV_ADD_POST, // Called just after pipe added to socket
    NNG_PIPE_EV_REM_POST, // Called just after pipe removed from socket
    NNG_PIPE_EV_NUM,      // Used internally, must be last.
}
int nng_pipe_notify(nng_socket, nng_pipe_ev, void function(nng_pipe, nng_pipe_ev, void *) nothrow, void *);

int nng_dial(nng_socket, const char *, nng_dialer *, int);
int nng_dialer_create(nng_dialer *, nng_socket, const char *);
int nng_dialer_start(nng_dialer, int);
int nng_dialer_close(nng_dialer);
int nng_dialer_id(nng_dialer);

int nng_dialer_set(nng_dialer, const char *, const void *, size_t);
int nng_dialer_set_bool(nng_dialer, const char *, bool);
int nng_dialer_set_int(nng_dialer, const char *, int);
int nng_dialer_set_size(nng_dialer, const char *, size_t);
int nng_dialer_set_uint64(nng_dialer, const char *, ulong);
int nng_dialer_set_string(nng_dialer, const char *, const char *);
int nng_dialer_set_ptr(nng_dialer, const char *, void *);
int nng_dialer_set_ms(nng_dialer, const char *, nng_duration);
int nng_dialer_set_addr(nng_dialer, const char *, const nng_sockaddr *);

int nng_dialer_get(nng_dialer, const char *, void *, size_t *);
int nng_dialer_get_bool(nng_dialer, const char *, bool *);
int nng_dialer_get_int(nng_dialer, const char *, int *);
int nng_dialer_get_size(nng_dialer, const char *, size_t *);
int nng_dialer_get_uint64(nng_dialer, const char *, ulong *);
int nng_dialer_get_string(nng_dialer, const char *, char **);
int nng_dialer_get_ptr(nng_dialer, const char *, void **);
int nng_dialer_get_ms(nng_dialer, const char *, nng_duration *);
int nng_dialer_get_addr(nng_dialer, const char *, nng_sockaddr *);

int nng_listen(nng_socket, const char *, nng_listener *, int);
int nng_listener_create(nng_listener *, nng_socket, const char *);
int nng_listener_start(nng_listener, int);
int nng_listener_close(nng_listener);
int nng_listener_id(nng_listener);

int nng_listener_set(nng_listener, const char *, const void *, size_t);
int nng_listener_set_bool(nng_listener, const char *, bool);
int nng_listener_set_int(nng_listener, const char *, int);
int nng_listener_set_size(nng_listener, const char *, size_t);
int nng_listener_set_uint64(nng_listener, const char *, ulong);
int nng_listener_set_string(nng_listener, const char *, const char *);
int nng_listener_set_ptr(nng_listener, const char *, void *);
int nng_listener_set_ms(nng_listener, const char *, nng_duration);
int nng_listener_set_addr(nng_listener, const char *, const nng_sockaddr *);

int nng_listener_get(nng_listener, const char *, void *, size_t *);
int nng_listener_get_bool(nng_listener, const char *, bool *);
int nng_listener_get_int(nng_listener, const char *, int *);
int nng_listener_get_size(nng_listener, const char *, size_t *);
int nng_listener_get_uint64(nng_listener, const char *, ulong *);
int nng_listener_get_string(nng_listener, const char *, char **);
int nng_listener_get_ptr(nng_listener, const char *, void **);
int nng_listener_get_ms(nng_listener, const char *, nng_duration *);
int nng_listener_get_addr(nng_listener, const char *, nng_sockaddr *);

int nng_send(nng_socket, void *, size_t, int);
int nng_recv(nng_socket, void *, size_t *, int);
int nng_sendmsg(nng_socket, nng_msg *, int);
int nng_recvmsg(nng_socket, nng_msg **, int);
void nng_send_aio(nng_socket, nng_aio *);
void nng_recv_aio(nng_socket, nng_aio *);

// ------------------------------------- message functions

int      nng_msg_alloc(nng_msg **, size_t);
void     nng_msg_free(nng_msg *);
int      nng_msg_realloc(nng_msg *, size_t);
int      nng_msg_reserve(nng_msg *, size_t);
size_t   nng_msg_capacity(nng_msg *);
void *   nng_msg_header(nng_msg *);
size_t   nng_msg_header_len(const nng_msg *);
void *   nng_msg_body(nng_msg *);
size_t   nng_msg_len(const nng_msg *);
int      nng_msg_append(nng_msg *, const void *, size_t);
int      nng_msg_insert(nng_msg *, const void *, size_t);
int      nng_msg_trim(nng_msg *, size_t);
int      nng_msg_chop(nng_msg *, size_t);
int      nng_msg_header_append(nng_msg *, const void *, size_t);
int      nng_msg_header_insert(nng_msg *, const void *, size_t);
int      nng_msg_header_trim(nng_msg *, size_t);
int      nng_msg_header_chop(nng_msg *, size_t);
int      nng_msg_header_append_u16(nng_msg *, ushort);
int      nng_msg_header_append_u32(nng_msg *, uint);
int      nng_msg_header_append_u64(nng_msg *, ulong);
int      nng_msg_header_insert_u16(nng_msg *, ushort);
int      nng_msg_header_insert_u32(nng_msg *, uint);
int      nng_msg_header_insert_u64(nng_msg *, ulong);
int      nng_msg_header_chop_u16(nng_msg *, ushort *);
int      nng_msg_header_chop_u32(nng_msg *, uint *);
int      nng_msg_header_chop_u64(nng_msg *, ulong *);
int      nng_msg_header_trim_u16(nng_msg *, ushort *);
int      nng_msg_header_trim_u32(nng_msg *, uint *);
int      nng_msg_header_trim_u64(nng_msg *, ulong *);
int      nng_msg_append_u16(nng_msg *, ushort);
int      nng_msg_append_u32(nng_msg *, uint);
int      nng_msg_append_u64(nng_msg *, ulong);
int      nng_msg_insert_u16(nng_msg *, ushort);
int      nng_msg_insert_u32(nng_msg *, uint);
int      nng_msg_insert_u64(nng_msg *, ulong);
int      nng_msg_chop_u16(nng_msg *, ushort *);
int      nng_msg_chop_u32(nng_msg *, uint *);
int      nng_msg_chop_u64(nng_msg *, ulong *);
int      nng_msg_trim_u16(nng_msg *, ushort *);
int      nng_msg_trim_u32(nng_msg *, uint *);
int      nng_msg_trim_u64(nng_msg *, ulong *);
int      nng_msg_dup(nng_msg **, const nng_msg *);
void     nng_msg_clear(nng_msg *);
void     nng_msg_header_clear(nng_msg *);
void     nng_msg_set_pipe(nng_msg *, nng_pipe);
nng_pipe nng_msg_get_pipe(const nng_msg *);

// ------------------------------------- pipe functions

int         nng_pipe_get(nng_pipe, const char *, void *, size_t *);
int         nng_pipe_get_bool(nng_pipe, const char *, bool *);
int         nng_pipe_get_int(nng_pipe, const char *, int *);
int         nng_pipe_get_ms(nng_pipe, const char *, nng_duration *);
int         nng_pipe_get_size(nng_pipe, const char *, size_t *);
int         nng_pipe_get_uint64(nng_pipe, const char *, ulong *);
int         nng_pipe_get_string(nng_pipe, const char *, char **);
int         nng_pipe_get_ptr(nng_pipe, const char *, void **);
int         nng_pipe_get_addr(nng_pipe, const char *, nng_sockaddr *);

int          nng_pipe_close(nng_pipe);
int          nng_pipe_id(nng_pipe);
nng_socket   nng_pipe_socket(nng_pipe);
nng_dialer   nng_pipe_dialer(nng_pipe);
nng_listener nng_pipe_listener(nng_pipe);


// ------------------------------------- stream functions TODO:



// ------------------------------------- protocol functions

int nng_bus0_open(nng_socket *);
int nng_bus0_open_raw(nng_socket *);
alias nng_bus_open = nng_bus0_open;
alias nng_bus_open_raw = nng_bus0_open_raw;

int nng_pair0_open(nng_socket *);
int nng_pair0_open_raw(nng_socket *);
int nng_pair1_open(nng_socket *);
int nng_pair1_open_raw(nng_socket *);
int nng_pair1_open_poly(nng_socket *);
alias nng_pair_open = nng_pair0_open;
alias nng_pair_open_raw = nng_pair0_open_raw;

int nng_pull0_open(nng_socket *);
int nng_pull0_open_raw(nng_socket *);
alias nng_pull_open = nng_pull0_open;
alias nng_pull_open_raw = nng_pull0_open_raw;

int nng_push0_open(nng_socket *);
int nng_push0_open_raw(nng_socket *);
alias nng_push_open = nng_push0_open;
alias nng_push_open_raw = nng_push0_open_raw;

int nng_pub0_open(nng_socket *);
int nng_pub0_open_raw(nng_socket *);
alias nng_pub_open = nng_pub0_open;
alias nng_pub_open_raw = nng_pub0_open_raw;

int nng_sub0_open(nng_socket *);
int nng_sub0_open_raw(nng_socket *);
alias nng_sub_open = nng_sub0_open;
alias nng_sub_open_raw = nng_sub0_open_raw;

const string NNG_OPT_SUB_SUBSCRIBE = "sub:subscribe";
const string NNG_OPT_SUB_UNSUBSCRIBE = "sub:unsubscribe";
const string NNG_OPT_SUB_PREFNEW = "sub:prefnew";

int nng_req0_open(nng_socket *);
int nng_req0_open_raw(nng_socket *);
alias nng_req_open = nng_req0_open;
alias nng_req_open_raw = nng_req0_open_raw;

const string NNG_OPT_REQ_RESENDTIME = "req:resend-time";

int nng_rep0_open(nng_socket *);
int nng_rep0_open_raw(nng_socket *);
alias nng_rep_open = nng_rep0_open;
alias nng_rep_open_raw = nng_rep0_open_raw;

int nng_surveyor0_open(nng_socket *);
int nng_surveyor0_open_raw(nng_socket *);
alias nng_surveyor_open = nng_surveyor0_open;
alias nng_surveyor_open_raw = nng_surveyor0_open_raw;

const string NNG_OPT_SURVEYOR_SURVEYTIME = "surveyor:survey-time";

int nng_respondent0_open(nng_socket *);
int nng_respondent0_open_raw(nng_socket *);
alias nng_respondent_open = nng_respondent0_open;
alias nng_respondent_open_raw = nng_respondent0_open_raw;

// ------------------------------------- HTTP functions

enum nng_http_status {
    NNG_HTTP_STATUS_CONTINUE                 = 100,
    NNG_HTTP_STATUS_SWITCHING                = 101,
    NNG_HTTP_STATUS_PROCESSING               = 102,
    NNG_HTTP_STATUS_OK                       = 200,
    NNG_HTTP_STATUS_CREATED                  = 201,
    NNG_HTTP_STATUS_ACCEPTED                 = 202,
    NNG_HTTP_STATUS_NOT_AUTHORITATIVE        = 203,
    NNG_HTTP_STATUS_NO_CONTENT               = 204,
    NNG_HTTP_STATUS_RESET_CONTENT            = 205,
    NNG_HTTP_STATUS_PARTIAL_CONTENT          = 206,
    NNG_HTTP_STATUS_MULTI_STATUS             = 207,
    NNG_HTTP_STATUS_ALREADY_REPORTED         = 208,
    NNG_HTTP_STATUS_IM_USED                  = 226,
    NNG_HTTP_STATUS_MULTIPLE_CHOICES         = 300,
    NNG_HTTP_STATUS_STATUS_MOVED_PERMANENTLY = 301,
    NNG_HTTP_STATUS_FOUND                    = 302,
    NNG_HTTP_STATUS_SEE_OTHER                = 303,
    NNG_HTTP_STATUS_NOT_MODIFIED             = 304,
    NNG_HTTP_STATUS_USE_PROXY                = 305,
    NNG_HTTP_STATUS_TEMPORARY_REDIRECT       = 307,
    NNG_HTTP_STATUS_PERMANENT_REDIRECT       = 308,
    NNG_HTTP_STATUS_BAD_REQUEST              = 400,
    NNG_HTTP_STATUS_UNAUTHORIZED             = 401,
    NNG_HTTP_STATUS_PAYMENT_REQUIRED         = 402,
    NNG_HTTP_STATUS_FORBIDDEN                = 403,
    NNG_HTTP_STATUS_NOT_FOUND                = 404,
    NNG_HTTP_STATUS_METHOD_NOT_ALLOWED       = 405,
    NNG_HTTP_STATUS_NOT_ACCEPTABLE           = 406,
    NNG_HTTP_STATUS_PROXY_AUTH_REQUIRED      = 407,
    NNG_HTTP_STATUS_REQUEST_TIMEOUT          = 408,
    NNG_HTTP_STATUS_CONFLICT                 = 409,
    NNG_HTTP_STATUS_GONE                     = 410,
    NNG_HTTP_STATUS_LENGTH_REQUIRED          = 411,
    NNG_HTTP_STATUS_PRECONDITION_FAILED      = 412,
    NNG_HTTP_STATUS_PAYLOAD_TOO_LARGE        = 413,
    NNG_HTTP_STATUS_ENTITY_TOO_LONG          = 414,
    NNG_HTTP_STATUS_UNSUPPORTED_MEDIA_TYPE   = 415,
    NNG_HTTP_STATUS_RANGE_NOT_SATISFIABLE    = 416,
    NNG_HTTP_STATUS_EXPECTATION_FAILED       = 417,
    NNG_HTTP_STATUS_TEAPOT                   = 418,
    NNG_HTTP_STATUS_UNPROCESSABLE_ENTITY     = 422,
    NNG_HTTP_STATUS_LOCKED                   = 423,
    NNG_HTTP_STATUS_FAILED_DEPENDENCY        = 424,
    NNG_HTTP_STATUS_UPGRADE_REQUIRED         = 426,
    NNG_HTTP_STATUS_PRECONDITION_REQUIRED    = 428,
    NNG_HTTP_STATUS_TOO_MANY_REQUESTS        = 429,
    NNG_HTTP_STATUS_HEADERS_TOO_LARGE        = 431,
    NNG_HTTP_STATUS_UNAVAIL_LEGAL_REASONS    = 451,
    NNG_HTTP_STATUS_INTERNAL_SERVER_ERROR    = 500,
    NNG_HTTP_STATUS_NOT_IMPLEMENTED          = 501,
    NNG_HTTP_STATUS_BAD_GATEWAY              = 502,
    NNG_HTTP_STATUS_SERVICE_UNAVAILABLE      = 503,
    NNG_HTTP_STATUS_GATEWAY_TIMEOUT          = 504,
    NNG_HTTP_STATUS_HTTP_VERSION_NOT_SUPP    = 505,
    NNG_HTTP_STATUS_VARIANT_ALSO_NEGOTIATES  = 506,
    NNG_HTTP_STATUS_INSUFFICIENT_STORAGE     = 507,
    NNG_HTTP_STATUS_LOOP_DETECTED            = 508,
    NNG_HTTP_STATUS_NOT_EXTENDED             = 510,
    NNG_HTTP_STATUS_NETWORK_AUTH_REQUIRED    = 511,
};
enum nng_tls_mode {
    NNG_TLS_MODE_CLIENT = 0,
    NNG_TLS_MODE_SERVER = 1,
};
enum nng_tls_auth_mode {
    NNG_TLS_AUTH_MODE_NONE     = 0,
    NNG_TLS_AUTH_MODE_OPTIONAL = 1,
    NNG_TLS_AUTH_MODE_REQUIRED = 2,
};
enum nng_tls_version {
    NNG_TLS_1_0 = 0x301,
    NNG_TLS_1_1 = 0x302,
    NNG_TLS_1_2 = 0x303,
    NNG_TLS_1_3 = 0x304
};

// http structures
struct nng_http_req {};
struct nng_http_res {};
struct nng_http_conn {};
struct nng_http_handler {};
struct nng_http_client {};
struct nng_http_server {};
struct nng_tls_config {};

struct nng_url {
    char *u_rawurl;   // never NULL
    char *u_scheme;   // never NULL
    char *u_userinfo; // will be NULL if not specified
    char *u_host;     // including colon and port
    char *u_hostname; // name only, will be "" if not specified
    char *u_port;     // port, will be "" if not specified
    char *u_path;     // path, will be "" if not specified
    char *u_query;    // without '?', will be NULL if not specified
    char *u_fragment; // without '#', will be NULL if not specified
    char *u_requri;   // includes query and fragment, "" if not specified
};

// http url api
int nng_url_parse(nng_url **, const char *);
void nng_url_free(nng_url *);
int nng_url_clone(nng_url **, const nng_url *);

// http tls api
int nng_tls_config_alloc(nng_tls_config **, nng_tls_mode);
void nng_tls_config_hold(nng_tls_config *);
void nng_tls_config_free(nng_tls_config *);
int nng_tls_config_server_name(nng_tls_config *, const char *);
int nng_tls_config_ca_chain(nng_tls_config *, const char *, const char *);
int nng_tls_config_own_cert(nng_tls_config *, const char *, const char *, const char *);
int nng_tls_config_key(nng_tls_config *, const ubyte *, size_t);
int nng_tls_config_pass(nng_tls_config *, const char *);
int nng_tls_config_auth_mode(nng_tls_config *, nng_tls_auth_mode);
int nng_tls_config_ca_file(nng_tls_config *, const char *);
int nng_tls_config_cert_key_file(nng_tls_config *, const char *, const char *);
int nng_tls_config_version(nng_tls_config *, nng_tls_version, nng_tls_version);
char* nng_tls_engine_name();
char* nng_tls_engine_description();
bool nng_tls_engine_fips_mode();


// http request api
int nng_http_req_alloc(nng_http_req **, const nng_url *);
void nng_http_req_free(nng_http_req *);
char* nng_http_req_get_method(nng_http_req *);
char* nng_http_req_get_version(nng_http_req *);
char* nng_http_req_get_uri(nng_http_req *);
int nng_http_req_set_header(nng_http_req *, const char *, const char *);
int nng_http_req_add_header(nng_http_req *, const char *, const char *);
int nng_http_req_del_header(nng_http_req *, const char *);
char* nng_http_req_get_header(nng_http_req *, const char *);
int nng_http_req_set_method(nng_http_req *, const char *);
int nng_http_req_set_version(nng_http_req *, const char *);
int nng_http_req_set_uri(nng_http_req *, const char *);
int nng_http_req_set_data(nng_http_req *, const void *, size_t);
int nng_http_req_copy_data(nng_http_req *, const void *, size_t);
void nng_http_req_get_data(nng_http_req *, void **, size_t *);
void nng_http_req_reset(nng_http_req *);

// http reply api
int nng_http_res_alloc(nng_http_res **);
int nng_http_res_alloc_error(nng_http_res **, ushort);
void nng_http_res_free(nng_http_res *);
ushort nng_http_res_get_status(nng_http_res *);
int nng_http_res_set_status(nng_http_res *, ushort);
char* nng_http_res_get_reason(nng_http_res *);
int nng_http_res_set_reason(nng_http_res *, const char *);
int nng_http_res_set_header(nng_http_res *, const char *, const char *);
int nng_http_res_add_header(nng_http_res *, const char *, const char *);
int nng_http_res_del_header(nng_http_res *, const char *);
char* nng_http_res_get_header(nng_http_res *, const char *);
int nng_http_res_set_version(nng_http_res *, const char *);
char* nng_http_res_get_version(nng_http_res *);
void nng_http_res_get_data(nng_http_res *, void **, size_t *);
int nng_http_res_set_data(nng_http_res *, const void *, size_t);
int nng_http_res_copy_data(nng_http_res *, const void *, size_t);
void nng_http_res_reset(nng_http_res *);

// http connection api
void nng_http_conn_close(nng_http_conn *);
void nng_http_conn_read(nng_http_conn *, nng_aio *);
void nng_http_conn_read_all(nng_http_conn *, nng_aio *);
void nng_http_conn_write(nng_http_conn *, nng_aio *);
void nng_http_conn_write_all(nng_http_conn *, nng_aio *);
void nng_http_conn_write_req(nng_http_conn *, nng_http_req *, nng_aio *);
void nng_http_conn_write_res(nng_http_conn *, nng_http_res *, nng_aio *);
void nng_http_conn_read_req(nng_http_conn *, nng_http_req *, nng_aio *);
void nng_http_conn_read_res(nng_http_conn *, nng_http_res *, nng_aio *);
void nng_http_conn_transact(nng_http_conn *, nng_http_req *, nng_http_res *, nng_aio *);

// http handler api
int nng_http_handler_alloc(nng_http_handler **, const char *, void function (nng_aio *));
int nng_http_handler_alloc(nng_http_handler **, const char *, void delegate (nng_aio *));
int nng_http_handler_alloc_file(nng_http_handler **, const char *, const char *);
int nng_http_handler_alloc_static(nng_http_handler **, const char *, const void *, size_t, const char *);
int nng_http_handler_alloc_redirect(nng_http_handler **, const char *, ushort, const char *);
int nng_http_handler_alloc_directory(nng_http_handler **, const char *, const char *);
void nng_http_handler_free(nng_http_handler *);
int nng_http_handler_set_method(nng_http_handler *, const char *);
int nng_http_handler_set_host(nng_http_handler *, const char *);
int nng_http_handler_collect_body(nng_http_handler *, bool, size_t);
int nng_http_handler_set_tree(nng_http_handler *);
int nng_http_handler_set_tree_exclusive(nng_http_handler *);
int nng_http_handler_set_data(nng_http_handler *, void *, void function (void *));
void *nng_http_handler_get_data(nng_http_handler *);

// http server api
int nng_http_server_hold(nng_http_server **, const nng_url *);
void nng_http_server_release(nng_http_server *);
int nng_http_server_start(nng_http_server *);
void nng_http_server_stop(nng_http_server *);
int nng_http_server_add_handler(nng_http_server *, nng_http_handler *);
int nng_http_server_del_handler(nng_http_server *, nng_http_handler *);
int nng_http_server_set_tls(nng_http_server *, nng_tls_config *);
int nng_http_server_get_tls(nng_http_server *, nng_tls_config **);
int nng_http_server_get_addr(nng_http_server *, nng_sockaddr *);
int nng_http_server_set_error_page(nng_http_server *, ushort, const char *);
int nng_http_server_set_error_file(nng_http_server *, ushort, const char *);
int nng_http_server_res_error(nng_http_server *, nng_http_res *);

int nng_http_hijack(nng_http_conn *);

// http client api
int nng_http_client_alloc(nng_http_client **, const nng_url *);
void nng_http_client_free(nng_http_client *);
int nng_http_client_set_tls(nng_http_client *, nng_tls_config *);
int nng_http_client_get_tls(nng_http_client *, nng_tls_config **);
void nng_http_client_connect(nng_http_client *, nng_aio *);
void nng_http_client_transact(nng_http_client *, nng_http_req *, nng_http_res *, nng_aio *);


}
