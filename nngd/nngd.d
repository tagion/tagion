
module nngd.nngd;

import core.memory;
import core.time;
import core.stdc.string;
import core.stdc.stdlib;
import std.conv;
import std.string;
import std.typecons;
import std.algorithm;
import std.datetime.systime;
import std.traits;
import std.json;
import std.file;
import std.path;
import std.exception;
import std.array;
import std.utf;

private import libnng;

import std.stdio;

@safe
T* ptr(T)(T[] arr, size_t off = 0) pure nothrow { 
    return arr.length == 0 ? null : &arr[off]; 
}

alias nng_errno = libnng.nng_errno;
alias nng_errstr = libnng.nng_errstr;
alias toString = nng_errstr;

@safe
void nng_sleep(Duration val) nothrow {
    nng_msleep(cast(nng_duration) val.total!"msecs");
}



string toString(nng_sockaddr a) {
    string s = "<ADDR:UNKNOWN>";
    switch(a.s_family) {
        case nng_sockaddr_family.NNG_AF_NONE: 
            s = format("<ADDR:NONE>");
            break;
        case nng_sockaddr_family.NNG_AF_UNSPEC: 
            s = format("<ADDR:UNSPEC>");
            break;
        case nng_sockaddr_family.NNG_AF_INPROC: 
            s = format("<ADDR:INPROC name: %s >", a.s_inproc.sa_name);
            break;
        case nng_sockaddr_family.NNG_AF_IPC: 
            s = format("<ADDR:IPC path: %s >", a.s_ipc.sa_path);
            break;
        case nng_sockaddr_family.NNG_AF_INET: 
            s = format("<ADDR:INET addr: %u port: %u >", a.s_in.sa_addr, a.s_in.sa_port);
            break;
        case nng_sockaddr_family.NNG_AF_INET6: 
            s = format("<ADDR:INET6 scope: %u addr: %s port: %u >", a.s_in6.sa_scope, a.s_in6.sa_addr, a.s_in6.sa_port);
            break;
        case nng_sockaddr_family.NNG_AF_ZT:  
            s = format("<ADDR:ZT nwid: %u nodeid: %u port: %u >", a.s_zt.sa_nwid, a.s_zt.sa_nodeid, a.s_zt.sa_port);
            break;
        case nng_sockaddr_family.NNG_AF_ABSTRACT: 
            s = format("<ADDR:ABSTRACT name: %s >", cast(string)a.s_abstract.sa_name[0..a.s_abstract.sa_len]);
            break;
        default:
            break;
    }
    return s;
}

enum infiniteDuration = Duration.max;

enum nng_socket_type {
     NNG_SOCKET_BUS        
    ,NNG_SOCKET_PAIR       
    ,NNG_SOCKET_PULL       
    ,NNG_SOCKET_PUSH       
    ,NNG_SOCKET_PUB        
    ,NNG_SOCKET_SUB        
    ,NNG_SOCKET_REQ        
    ,NNG_SOCKET_REP        
    ,NNG_SOCKET_SURVEYOR   
    ,NNG_SOCKET_RESPONDENT 
};

enum nng_socket_state {
     NNG_STATE_NONE         = 0
    ,NNG_STATE_CREATED      = 1
    ,NNG_STATE_PREPARED     = 2
    ,NNG_STATE_CONNECTED    = 4
    ,NNG_STATE_ERROR        = 16
}

enum nng_property_base {
     NNG_BASE_SOCKET
    ,NNG_BASE_DIALER
    ,NNG_BASE_LISTENER
}
        

struct NNGMessage {
    nng_msg *msg;

    @disable this();

    this(ref return scope NNGMessage src) {
        auto rc = nng_msg_dup(&msg, src.pointer);
        enforce(rc == 0);
    }   
    
    this(nng_msg * msgref) {
        if(msgref is null) {
            auto rc = nng_msg_alloc(&msg, 0);
            enforce(rc == 0);
        } else {            
            msg = msgref;
        }            
    }   

    this( size_t size ) {
        auto rc = nng_msg_alloc(&msg, size);
        enforce(rc == 0);
    } 
    
    ~this() {
        nng_msg_free(msg);
    }

    @nogc @safe
    @property nng_msg* pointer() nothrow {
        return msg;
    }

    @nogc  
    @property void pointer(nng_msg* p) nothrow {
        if(p !is null) { 
            msg = p;
        } else {
            nng_msg_clear(msg);
        }            
    }
    
    @nogc @safe
    @property void* bodyptr() nothrow {
        return nng_msg_body(msg);
    }
    
    @nogc @safe
    @property void* headerptr() nothrow {
        return nng_msg_header(msg);
    }

    @property size_t length() { return nng_msg_len(msg); }
    @property void length( size_t sz ) { auto rc = nng_msg_realloc(msg, sz); enforce(rc == 0); }
    @property size_t header_length() { return nng_msg_header_len(msg); }
    
    void clear() { nng_msg_clear(msg); }

    int body_append (T) ( const(T) data ) if(isArray!T || isUnsigned!T) {
        static if (isArray!T) {
            static assert((ForeachType!T).sizeof == 1, "None byte size array element are not supported");
            auto rc = nng_msg_append(msg, ptr(data), data.length );
            enforce(rc == 0);
            return 0;
        }else{            
            static if (T.sizeof == 1) {
                T tmp = data;
                auto rc = nng_msg_append(msg, cast(void*)&tmp, 1);
                enforce(rc == 0);
            }                    
            static if (T.sizeof == 2) {
                auto rc = nng_msg_append_u16(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4) {
                auto rc = nng_msg_append_u32(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8) {
                auto rc = nng_msg_append_u64(msg, data);
                enforce(rc == 0);
            }
            return 0;
        }
    }

    int body_prepend (T) ( const(T) data ) if(isArray!T || isUnsigned!T) {
        static if (isArray!T) {
            static assert((ForeachType!T).sizeof == 1, "None byte size array element are not supported");
            auto rc = nng_msg_insert(msg, ptr(data), data.length );
            enforce(rc == 0);
            return 0;
        } else {
            static if (T.sizeof == 1) {
                T tmp = data;
                auto rc = nng_msg_insert(msg, cast(void*)&tmp, 1);
                enforce(rc == 0);
            }
            static if (T.sizeof == 2) {
                auto rc = nng_msg_insert_u16(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4) {
                auto rc = nng_msg_insert_u32(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8) {
                auto rc = nng_msg_insert_u64(msg, data);
                enforce(rc == 0);
            }
            return 0;
        }            
    }
    
    
    T body_chop (T) (size_t size = 0) if(isArray!T || isUnsigned!T) {
        static if (isArray!T) {
            if(size == 0) size = length;
            if(size == 0) return [];
            T data = cast(T) (bodyptr + (length - size)) [0..size];
            auto rc = nng_msg_chop(msg, size);
            enforce(rc == 0);
            return data;
        } else {
            T tmp;
            static if (T.sizeof == 1) { 
                tmp = cast(T)*(bodyptr + (length - 1));
                auto rc = nng_msg_chop(msg, 1);
                enforce(rc == 0);
            }
            static if (T.sizeof == 2) {
                auto rc = nng_msg_chop_u16(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4) {
                auto rc = nng_msg_chop_u32(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8) {
                auto rc = nng_msg_chop_u64(msg, &tmp);
                enforce(rc == 0);
            }
            return tmp;
        }            
    }            

    
    T body_trim (T) (size_t size = 0) if(isArray!T || isUnsigned!T) {
        static if (isArray!T) {
            if(size == 0) size = length;
            if(size == 0) return [];
            T data = cast(T) (bodyptr) [0..size];
            auto rc = nng_msg_trim(msg, size);
            enforce(rc == 0);
            return data;
        } else {
            T tmp;
            static if (T.sizeof == 1) {
                tmp = cast(T)*(bodyptr);
                auto rc = nng_msg_trim(msg, 1);
                enforce(rc == 0);
            }
            static if (T.sizeof == 2) {
                auto rc = nng_msg_trim_u16(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4) {
                auto rc = nng_msg_trim_u32(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8) {
                auto rc = nng_msg_trim_u64(msg, &tmp);
                enforce(rc == 0);
            }
            return tmp;
        }            
    }            
    
    // TODO: body structure map


    int header_append (T) ( const(T) data ) if(isArray!T || isUnsigned!T) {
        static if (isArray!T) {
            static assert((ForeachType!T).sizeof == 1, "None byte size array element are not supported");
            auto rc = nng_msg_header_append(msg, ptr(data), data.length );
            return 0;
        }else{            
            static if (T.sizeof == 1) {
                T tmp = data;
                auto rc = nng_msg_header_append(msg, cast(void*)&tmp, 1);
                enforce(rc == 0);
            }                    
            static if (T.sizeof == 2) {
                auto rc = nng_msg_header_append_u16(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4) {
                auto rc = nng_msg_header_append_u32(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8) {
                auto rc = nng_msg_header_append_u64(msg, data);
                enforce(rc == 0);
            }
            return 0;
        }
    }

    int header_prepend (T) ( const(T) data ) if(isArray!T || isUnsigned!T) {
        static if (isArray!T) {
            static assert((ForeachType!T).sizeof == 1, "None byte size array element are not supported");
            auto rc = nng_msg_header_insert(msg, ptr(data), data.length );
            enforce(rc == 0);
            return 0;
        } else {
            static if (T.sizeof == 1) {
                T tmp = data;
                auto rc = nng_msg_header_insert(msg, cast(void*)&tmp, 1);
                enforce(rc == 0);
            }
            static if (T.sizeof == 2) {
                auto rc = nng_msg_header_insert_u16(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4) {
                auto rc = nng_msg_header_insert_u32(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8) {
                auto rc = nng_msg_header_insert_u64(msg, data);
                enforce(rc == 0);
            }
            return 0;
        }            
    }
    
    
    T header_chop (T) (size_t size = 0) if(isArray!T || isUnsigned!T) {
        static if (isArray!T) {
            if(size == 0) size = header_length;
            if(size == 0) return [];
            T data = cast(T) (headerptr + (header_length - size)) [0..size];
            auto rc = nng_msg_header_chop(msg, size);
            enforce(rc == 0);
            return data;
        } else {
            T tmp;
            static if (T.sizeof == 1) { 
                tmp = cast(T)*(bodyptr + (length - 1));
                auto rc = nng_msg_header_chop(msg, 1);
                enforce(rc == 0);
            }
            static if (T.sizeof == 2) {
                auto rc = nng_msg_header_chop_u16(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4) {
                auto rc = nng_msg_header_chop_u32(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8) {
                auto rc = nng_msg_header_chop_u64(msg, &tmp);
                enforce(rc == 0);
            }
            return tmp;
        }            
    }            

    
    T header_trim (T) (size_t size = 0) if(isArray!T || isUnsigned!T) {
        static if (isArray!T) {
            if(size == 0) size = header_length;
            if(size == 0) return [];
            T data = cast(T) (headerptr) [0..size];
            auto rc = nng_msg_header_trim(msg, size);
            enforce(rc == 0);
            return data;
        } else {
            T tmp;
            static if (T.sizeof == 1) {
                tmp = cast(T)*(bodyptr);
                auto rc = nng_msg_header_trim(msg, 1);
                enforce(rc == 0);
            }
            static if (T.sizeof == 2) {
                auto rc = nng_msg_header_trim_u16(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4) {
                auto rc = nng_msg_header_trim_u32(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8) {
                auto rc = nng_msg_header_trim_u64(msg, &tmp);
                enforce(rc == 0);
            }
            return tmp;
        }            
    }            
} // struct NNGMessage

alias nng_aio_cb = void function (void *);

struct NNGAio {
    nng_aio* aio;

    @disable this();

    this( nng_aio_cb cb, void* arg ) {
        auto rc = nng_aio_alloc( &aio,  cb, arg );
        enforce(rc == 0);
    }
    
    this( nng_aio* src ) {
        enforce(src !is null);
        pointer(src);
    }

    ~this() {
        nng_aio_free(aio);
    }

    void realloc( nng_aio_cb cb, void* arg ) {
        nng_aio_free(aio);
        auto rc = nng_aio_alloc( &aio,  cb, arg );            
        enforce(rc == 0);
    }
    
    // ---------- pointer prop
    
    @nogc @safe
    @property nng_aio* pointer() { return aio; }

    @nogc 
    @property void pointer( nng_aio* p ) {
        if(p !is null) {
            nng_aio_free(aio);
            aio = p;
        }else{
            nng_aio_free(aio);
            nng_aio_alloc( &aio,  null, null );
        }
    }

    // ---------- status prop
    
    @nogc @safe
    @property size_t count () nothrow {
        return nng_aio_count(aio);
    }
    
    @nogc @safe
    @property nng_errno result () nothrow {
        return cast(nng_errno) nng_aio_result(aio);
    }

    @nogc @safe
    @property void timeout ( Duration val ) nothrow {
        nng_aio_set_timeout(aio, cast(nng_duration)val.total!"msecs");
    }        

    // ---------- controls

    bool begin () {
        return nng_aio_begin(aio);
    }

    void wait() {
        nng_aio_wait(aio);
    }
    
    void sleep ( Duration val ) {
        nng_sleep_aio(cast(nng_duration)val.total!"msecs", aio);
    }


    /*
        = no callback
    */
    void abort ( nng_errno err ) {
        nng_aio_abort(aio, cast(int) err);
    }
    
    /*
        = callback
    */
    void finish ( nng_errno err ) {
        nng_aio_finish(aio, cast(int) err);
    }

    alias nng_aio_ccb = void function (nng_aio *, void*, int);
    void defer ( nng_aio_ccb cancelcb, void *arg ) {
        nng_aio_defer ( aio, cancelcb, arg );
    }

    /*
        = abort(NNG_CANCELLED)
        = no callback
        = no wait for abort and callback complete
    */
    void cancel () {
        nng_aio_cancel(aio);
    }
    
    /*
        = abort(NNG_CANCELLED)
        = no callback
        = wait for abort and callback complete
    */
    void stop () {
        nng_aio_stop(aio);
    }

    // ---------- messages

    nng_errno get_msg( ref NNGMessage msg ) {
        auto err = this.result();
        if( err != nng_errno.NNG_OK )
            return err;
        nng_msg *m = nng_aio_get_msg(aio);
        if(m is null) {
            return nng_errno.NNG_EINTERNAL;
        }else{    
            msg.pointer(m);
            return nng_errno.NNG_OK;
        }    
    }
    
    void set_msg( ref NNGMessage msg ) {
        nng_aio_set_msg(aio, msg.pointer);
    }

    void clear_msg () {
        nng_aio_set_msg(aio, null);
    }


    // TODO: IOV and context input-output parameters
} // struct NNGAio

struct NNGSocket {
    nng_socket_type m_type;
    nng_socket_state m_state;
    nng_socket m_socket;
    nng_ctx[] m_ctx;
    string[] m_subscriptions;
    string m_name;
    nng_errno m_errno;

    bool m_raw;
    bool m_may_send, m_may_recv;

    nng_listener m_listener;
    nng_dialer m_dialer;

    @disable this();
    
    this(nng_socket_type itype, bool iraw = false) nothrow {
        int rc;
        m_type = itype;
        m_raw = iraw;
        m_state = nng_socket_state.NNG_STATE_NONE;
        with(nng_socket_type) {
        final switch(itype) {
            case NNG_SOCKET_BUS:
                rc = (!raw) ? nng_bus_open(&m_socket) : nng_bus_open_raw(&m_socket);
                m_may_send = true;
                m_may_recv = true;
                break;
            case NNG_SOCKET_PAIR:       
                rc = (!raw) ? nng_pair_open(&m_socket) : nng_pair_open_raw(&m_socket);
                m_may_send = true;
                m_may_recv = true;
                break;
            case NNG_SOCKET_PULL:       
                rc = (!raw) ? nng_pull_open(&m_socket) : nng_pull_open_raw(&m_socket);
                m_may_send = false;
                m_may_recv = true;
                break;
            case NNG_SOCKET_PUSH:       
                rc = (!raw) ? nng_push_open(&m_socket) : nng_push_open_raw(&m_socket);
                m_may_send = true;
                m_may_recv = false;
                break;
            case NNG_SOCKET_PUB:        
                rc = (!raw) ? nng_pub_open(&m_socket) : nng_pub_open_raw(&m_socket);
                m_may_send = true;
                m_may_recv = false;
                break;
            case NNG_SOCKET_SUB:        
                rc = (!raw) ? nng_sub_open(&m_socket) : nng_sub_open_raw(&m_socket);
                m_may_send = false;
                m_may_recv = true;
                break;
            case NNG_SOCKET_REQ:        
                rc = (!raw) ? nng_req_open(&m_socket) : nng_req_open_raw(&m_socket);
                m_may_send = true;
                m_may_recv = true;
                break;
            case NNG_SOCKET_REP:        
                rc = (!raw) ? nng_rep_open(&m_socket) : nng_rep_open_raw(&m_socket);
                m_may_send = true;
                m_may_recv = true;
                break;
            case NNG_SOCKET_SURVEYOR:   
                rc = (!raw) ? nng_surveyor_open(&m_socket) : nng_surveyor_open_raw(&m_socket);
                m_may_send = true;
                m_may_recv = true;
                break;
            case NNG_SOCKET_RESPONDENT: 
                rc = (!raw) ? nng_respondent_open(&m_socket) : nng_respondent_open_raw(&m_socket);
                m_may_send = true;
                m_may_recv = true;
                break;
           }
        }
        if(rc != 0) {
            m_state = nng_socket_state.NNG_STATE_ERROR;
            m_errno = cast(nng_errno)rc;
        }else{
            m_state = nng_socket_state.NNG_STATE_CREATED;
            m_errno = cast(nng_errno)0;
        }

    } // this

    int close() nothrow {
        int rc;
        m_errno = cast(nng_errno)0;
        foreach(ctx; m_ctx) {
            rc = nng_ctx_close(ctx);
            if(rc != 0) {
                m_errno = cast(nng_errno)rc;
                return rc;
            }                
        }
        rc = nng_close(m_socket);
        if(rc == 0) {
            m_state = nng_socket_state.NNG_STATE_NONE;
        } else {
            m_errno = cast(nng_errno)rc;
        }    
        return rc;
    }

    // setup listener

    int listener_create(const(string) url) {
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_CREATED) {
            auto rc = nng_listener_create( &m_listener, m_socket, toStringz(url) );
            if( rc != 0) {
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            m_state = nng_socket_state.NNG_STATE_PREPARED;
            return 0;
        }else{
            return -1;
        }
    }        

    int listener_start( const bool nonblock = false ) {
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_PREPARED) {
            auto rc =  nng_listener_start(m_listener, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 );
            if( rc != 0) {
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            m_state = nng_socket_state.NNG_STATE_CONNECTED;
            return 0;
        } else { 
            return -1;
        }
    }

    int listen ( const(string) url, const bool nonblock = false ) nothrow {
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_CREATED) {
            auto rc = nng_listen(m_socket, toStringz(url), &m_listener, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 );
            if( rc != 0) {
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            m_state = nng_socket_state.NNG_STATE_CONNECTED;
            return 0;
        }else{
            return -1;
        }
    }

    // setup subscriber

    int subscribe ( string tag ) nothrow {
        if(m_subscriptions.canFind(tag))
            return 0;
        setopt_buf(NNG_OPT_SUB_SUBSCRIBE, cast(ubyte[])(tag.dup));
        if(m_errno == 0)
            m_subscriptions ~= tag;
        return m_errno;    
    }

    int unsubscribe ( string tag ) nothrow {
        long i = m_subscriptions.countUntil(tag);
        if(i < 0)
            return 0;
        setopt_buf(NNG_OPT_SUB_UNSUBSCRIBE, cast(ubyte[])(tag.dup));                
        if(m_errno == 0)
            m_subscriptions = m_subscriptions[0..i]~m_subscriptions[i+1..$];
        return m_errno;    
    }

    int clearsubscribe () nothrow {
        long i;
        foreach(tag; m_subscriptions) {
            i = m_subscriptions.countUntil(tag);
            if(i < 0) continue;
            setopt_buf(NNG_OPT_SUB_UNSUBSCRIBE, cast(ubyte[])(tag.dup));
            if(m_errno != 0)
                return m_errno;
            m_subscriptions = m_subscriptions[0..i]~m_subscriptions[i+1..$];
        }
        return 0;
    }

    string[] subscriptions() nothrow {
        return m_subscriptions;
    }

    // setup dialer
    
    int dialer_create(const(string) url) nothrow {
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_CREATED) {
            auto rc = nng_dialer_create( &m_dialer, m_socket, toStringz(url) );
            if( rc != 0) {
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            m_state = nng_socket_state.NNG_STATE_PREPARED;
            return 0;
        }else{
            return -1;
        }
    }        

    int dialer_start( const bool nonblock = false ) nothrow {
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_PREPARED) {
            auto rc =  nng_dialer_start(m_dialer, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 );
            if( rc != 0) {
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            m_state = nng_socket_state.NNG_STATE_CONNECTED;
            return 0;
        } else { 
            return -1;
        }
    }

    int dial ( const(string) url, const bool nonblock = false ) nothrow {
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_CREATED) {
            auto rc = nng_dial(m_socket, toStringz(url), &m_dialer, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 );
            if( rc != 0) {
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            m_state = nng_socket_state.NNG_STATE_CONNECTED;
            return 0;
        }else{
            return -1;
        }
    }

    // send & receive TODO: Serialization for objects and structures - see protobuf or hibon?
    

    int sendmsg ( ref NNGMessage msg, bool nonblock = false ) {
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED) {
            m_errno = (() @trusted => cast(nng_errno) nng_sendmsg( m_socket, msg.pointer, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0))();
            if (m_errno !is nng_errno.init) {
                return -1;
            }
            return 0;
        }
        return -1;
    }

    int send (T)( const(T) data , bool nonblock = false ) if(isArray!T) {
        alias U=ForeachType!T;
        static assert(U.sizeof == 1, "None byte size array element are not supported");
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED) {
            auto rc = nng_send(m_socket, ptr(cast(ubyte[])data), data.length, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0);
            if( rc != 0) {
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            return 0;
        }
        return -1;
    }
    
    int sendaio ( ref NNGAio aio ) {
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED) {
            if(aio.pointer) {
                nng_send_aio(m_socket, aio.pointer);
                return 0;
            }
            return 1;
        }
        return -1;
    }
    

    /*
        Receives a data buffer of the max size data.length 
        Params:
            data = preallocated buffer
            nonblock = set the non blocking mode
            sz = if sz != the this sz is used as max size
        Returns:
            number of actually received bytes or -1
    */
    @nogc @safe
    size_t receivebuf ( ubyte[] data, size_t sz = 0,  bool nonblock = false ) nothrow 
        in(data.length>=sz)
        in(data.length)
    do {
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED) {
            sz =(sz==0)?data.length:sz;
            m_errno = (() @trusted => cast(nng_errno)nng_recv(m_socket, ptr(data), &sz, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 ))();
            if (m_errno !is nng_errno.init) {    
                return size_t.max;
            }
            return sz;
        }
        return size_t.max;
    }

    /*
        Receives NNGMessage 
        Params:
            nonblock = set the non blocking mode
    */
    @nogc @safe
    int receivemsg ( NNGMessage* msg, bool nonblock = false ) nothrow
    {
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED) {
            m_errno = (() @trusted => cast(nng_errno) nng_recvmsg( m_socket, &(msg.msg), nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0))();
            if (m_errno !is nng_errno.init) {
                return -1;
            }
            return 0;
        }
        return -1;
    }

    /*
        Receives a data type (castable to byte array) as postallocated buffer
        Params:
            nonblock = set the non blocking mode
    */
    T receive(T)( bool nonblock = false ) if (isArray!T) {
        m_errno = nng_errno.init;
        alias U=ForeachType!T;
        static assert(U.sizeof == 1, "None byte size array element are not supported");
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED) {
            void* buf;
            size_t sz;
            auto rc = nng_recv(m_socket, &buf, &sz, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 + nng_flag.NNG_FLAG_ALLOC );
            if (rc != 0) { 
                m_errno = cast(nng_errno)rc;
                return T.init;
            }
            GC.addRange(buf, sz);
            return (cast(U*)buf)[0..sz];
        }
        return T.init;
    }
    
    int receiveaio ( ref NNGAio aio ) {
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED) {
            if(aio.pointer) {
                nng_recv_aio(m_socket, aio.pointer);
                return 0;
            }
            return 1;
        }
        return -1;
    }
    

    // properties Note @propery is not need anymore
    @nogc nothrow pure  {
        @property int state() const { return m_state; }
        @property int errno() const { return m_errno; }
        @property nng_socket_type type() const { return m_type; }
        @property string versionstring() {
            import core.stdc.string : strlen;
            return nng_version[0..strlen(nng_version)]; 
        }

        string name() const { return m_name; }
        
        /* You don't need to dup the string because is immutable 
            Only if you are planing to change the content in the string
    @property void name(string val) { m_name = val.dup; }
            Ex:
            The function can be @nogc if you don't duplicate
    */    
        void name(string val) { m_name = val; }

        @property bool raw() const { return m_raw; }

    } // nogc nothrow pure

    nothrow {
        @property int proto() { return getopt_int(NNG_OPT_PROTO); }
        @property string protoname() { return getopt_string(NNG_OPT_PROTONAME); }
        
        @property int peer() { return getopt_int(NNG_OPT_PEER); }
        @property string peername() { return getopt_string(NNG_OPT_PEERNAME); } 
        
        @property int recvbuf() { return getopt_int(NNG_OPT_RECVBUF); }
        @property void recvbuf(int val) { setopt_int(NNG_OPT_RECVBUF, val); }

        @property int sendbuf() { return getopt_int(NNG_OPT_SENDBUF); } 
        @property void sendbuf(int val) { setopt_int(NNG_OPT_SENDBUF, val); }

        @property int recvfd() { return (m_may_recv) ? getopt_int(NNG_OPT_RECVFD) : -1; } 
        @property int sendfd() { return (m_may_send) ? getopt_int(NNG_OPT_SENDFD) : -1; } 

        @property Duration recvtimeout() { return getopt_duration(NNG_OPT_RECVTIMEO); } 
        @property void recvtimeout(Duration val) { setopt_duration(NNG_OPT_RECVTIMEO, val); }

        @property Duration sendtimeout() { return getopt_duration(NNG_OPT_SENDTIMEO); } 
        @property void sendtimeout(Duration val) { setopt_duration(NNG_OPT_SENDTIMEO, val); }

        @property nng_sockaddr locaddr() { return (m_may_send) ? getopt_addr(NNG_OPT_LOCADDR, nng_property_base.NNG_BASE_DIALER) : getopt_addr(NNG_OPT_LOCADDR, nng_property_base.NNG_BASE_LISTENER); } 
        @property nng_sockaddr remaddr() { return (m_may_send) ? getopt_addr(NNG_OPT_REMADDR, nng_property_base.NNG_BASE_DIALER) : nng_sockaddr(nng_sockaddr_family.NNG_AF_NONE); } 
    } // nothrow
    
    @property string url() { 
        if(m_may_send)
            return getopt_string(NNG_OPT_URL, nng_property_base.NNG_BASE_DIALER); 
        else if(m_may_recv)    
            return getopt_string(NNG_OPT_URL, nng_property_base.NNG_BASE_LISTENER); 
        else            
            return getopt_string(NNG_OPT_URL, nng_property_base.NNG_BASE_SOCKET); 
    }

    @property int maxttl() { return getopt_int(NNG_OPT_MAXTTL); } 
    /// MAXTTL a value between 0 and 255, inclusive. Where 0 is infinite
    @property void maxttl(uint val)
    in (val <= 255, "MAXTTL, hops cannot be greater than 255")
    do { 
        setopt_int(NNG_OPT_MAXTTL, val);
    }
    
    @property int recvmaxsz() { return getopt_int(NNG_OPT_RECVMAXSZ); } 
    @property void recvmaxsz(int val) { return setopt_int(NNG_OPT_RECVMAXSZ, val); } 

    @property Duration reconnmint() { return getopt_duration(NNG_OPT_RECONNMINT); } 
    @property void reconnmint(Duration val) { setopt_duration(NNG_OPT_RECONNMINT, val); }

    @property Duration reconnmaxt() { return getopt_duration(NNG_OPT_RECONNMAXT); } 
    @property void reconnmaxt(Duration val) { setopt_duration(NNG_OPT_RECONNMAXT, val); }

    // TODO: NNG_OPT_IPC_*, NNG_OPT_TLS_*, NNG_OPT_WS_*  
private:
    nothrow {
        void setopt_int(string opt, int val) {
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_int(m_socket, toStringz(opt), val);
            if(rc == 0) { return; }else{ m_errno = cast(nng_errno)rc; } 
        }

        int getopt_int(string opt) {
            m_errno = cast(nng_errno)0;
            int p;
            auto rc = nng_socket_get_int(m_socket, toStringz(opt), &p);
            if(rc == 0) { return p; }else{ m_errno = cast(nng_errno)rc; return -1; }    
        }
        
        void setopt_ulong(string opt, ulong val) {
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_uint64(m_socket, toStringz(opt), val);
            if(rc == 0) { return; }else{ m_errno = cast(nng_errno)rc; } 
        }

        ulong getopt_ulong(string opt) {
            m_errno = cast(nng_errno)0;
            ulong p;
            auto rc = nng_socket_get_uint64(m_socket, toStringz(opt), &p);
            if(rc == 0) { return p; }else{ m_errno = cast(nng_errno)rc; return -1; }    
        }
        
        void setopt_size(string opt, size_t val) {
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_size(m_socket, toStringz(opt), val);
            if(rc == 0) { return; }else{ m_errno = cast(nng_errno)rc; } 
        }
        
        size_t getopt_size(string opt) {
            m_errno = cast(nng_errno)0;
            size_t p;
            auto rc = nng_socket_get_size(m_socket, toStringz(opt), &p);
            if(rc == 0) { return p; }else{ m_errno = cast(nng_errno)rc; return -1; }    
        }
        
        string getopt_string(string opt, nng_property_base base = nng_property_base.NNG_BASE_SOCKET ) { 
            m_errno = cast(nng_errno)0;
            char *ptr;
            int rc;
            switch(base) {
                case nng_property_base.NNG_BASE_DIALER:
                    rc = nng_dialer_get_string(m_dialer, cast(const char*)toStringz(opt), &ptr); 
                break;
                case nng_property_base.NNG_BASE_LISTENER:
                    rc = nng_listener_get_string(m_listener, cast(const char*)toStringz(opt), &ptr); 
                break;
                default:
                    rc = nng_socket_get_string(m_socket, cast(const char*)toStringz(opt), &ptr); 
                break;
            }    
            if(rc == 0) { return to!string(ptr); }else{ m_errno = cast(nng_errno)rc; return "<none>"; }            
        }

        void setopt_string(string opt, string val) {
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_string(m_socket, toStringz(opt), toStringz(val));
            if(rc == 0) { return; }else{ m_errno = cast(nng_errno)rc; }                
        }
        
        void setopt_buf(string opt, ubyte[] val) {
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set(m_socket, toStringz(opt), ptr(val), val.length);
            if(rc == 0) { return; }else{ m_errno = cast(nng_errno)rc; }                
        }

        Duration getopt_duration(string opt) {
            m_errno = cast(nng_errno)0;
            nng_duration p;
            auto rc = nng_socket_get_ms(m_socket, toStringz(opt), &p);
            if(rc == 0) {
                return msecs(p);
            }else{
                m_errno = cast(nng_errno)rc;
                return infiniteDuration;
            }
        }
        
        void setopt_duration(string opt, Duration val) {
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_ms(m_socket, cast(const char*)toStringz(opt), cast(int)val.total!"msecs"); 
            if(rc == 0) { return; }else{ m_errno = cast(nng_errno)rc; } 
        }

        nng_sockaddr getopt_addr(string opt, nng_property_base base = nng_property_base.NNG_BASE_SOCKET ) {
            m_errno = cast(nng_errno)0;
            nng_sockaddr addr;
            int rc;
            switch(base) {
                case nng_property_base.NNG_BASE_DIALER:
                    rc = nng_dialer_get_addr(m_dialer, toStringz(opt), &addr);
                    break;
                case nng_property_base.NNG_BASE_LISTENER:
                    rc = nng_listener_get_addr(m_listener, toStringz(opt), &addr);
                    break;
                default:
                    rc = nng_socket_get_addr(m_socket, toStringz(opt), &addr);
                    break;
            }                
            if(rc == 0) { return addr; } else { m_errno = cast(nng_errno)rc; addr.s_family = nng_sockaddr_family.NNG_AF_NONE; return addr; }
        }
        
        void setopt_addr(string opt, nng_sockaddr val) {
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_addr(m_socket, cast(const char*)toStringz(opt), &val);
            if(rc == 0) { return; }else{ m_errno = cast(nng_errno)rc; }
        }
    } // nothrow
}   // struct Socket

struct NNGURL {
    string rawurl;
    string scheme;
    string userinfo;
    string host;
    string hostname;
    string port;
    string path;
    string query;
    string fragment;
    string requri;

    @disable this(this);

    protected nng_url* _nng_url;
    this(const(char)[] url_str) @trusted {
        _nng_url = new nng_url;

        int rc = nng_url_parse(&_nng_url, toStringz(url_str));
        if(rc != nng_errno.NNG_OK) {
            throw new Exception(nng_errstr(rc));
        }

        rawurl = cast(immutable)fromStringz(_nng_url.u_rawurl);
        scheme = cast(immutable)fromStringz(_nng_url.u_scheme);
        userinfo = cast(immutable)fromStringz(_nng_url.u_userinfo);
        host = cast(immutable)fromStringz(_nng_url.u_host);
        hostname = cast(immutable)fromStringz(_nng_url.u_hostname);
        port = cast(immutable)fromStringz(_nng_url.u_port);
        path = cast(immutable)fromStringz(_nng_url.u_path);
        query = cast(immutable)fromStringz(_nng_url.u_query);
        fragment = cast(immutable)fromStringz(_nng_url.u_fragment);
        requri = cast(immutable)fromStringz(_nng_url.u_requri);
    }

    ~this() {
        if(_nng_url !is null) {
            nng_url_free(_nng_url);
        }
    }
} // struct NNGURL

unittest {
    import std.exception;
    string f1(ref NNGURL url) {
    return url.hostname;
    }
    string f2(NNGURL url) {
    return url.hostname;
    }
    auto nn = NNGURL("tcp://0.0.0.0:473");
    assert(nn.scheme == "tcp");
    assert(nn.hostname == "0.0.0.0", nn.hostname);
    assert(nn.port == "473");
    assertThrown(NNGURL("blbalablbadurl"));

    f1(nn);
    static assert(!__traits(compiles, f2(nn)));
}

alias nng_pool_callback = void function ( NNGMessage*, void* );

enum nng_worker_state { 
    EXIT = -1,
    NONE = 0, 
    RECV = 1, 
    WAIT = 2, 
    SEND = 4 
}

struct NNGPoolWorker {
    int id;
    nng_worker_state state;
    NNGMessage msg;
    NNGAio aio;    
    Duration delay;
    nng_mtx *mtx;
    nng_ctx ctx;
    void *context;
    File *logfile;
    nng_pool_callback cb;
    this(int iid, void *icontext, File *ilog) {
        this.id = iid;
        this.context = icontext;
        this.logfile = ilog;
        this.state = nng_worker_state.NONE;
        this.msg = NNGMessage(0);
        this.aio = NNGAio(null, null);
        this.delay = msecs(0);
        this.cb = null;
        auto rc = nng_mtx_alloc(&this.mtx);
        enforce(rc==0, "PW: init");
    }
    void lock() {
        nng_mtx_lock(mtx);
    }
    void unlock() {
        nng_mtx_unlock(mtx);
    }
    void wait() {
        this.aio.wait();            
    }
    void shutdown() {
        this.state = nng_worker_state.EXIT;
        this.aio.stop();
    }
} // struct NNGPoolWorker


extern (C) void nng_pool_stateful ( void* p ) {
    if(p is null) return;
    NNGPoolWorker *w = cast(NNGPoolWorker*)p;
    w.lock();
    nng_errno rc;
    switch(w.state) {
        case nng_worker_state.EXIT:
            w.unlock();
            return;
        case nng_worker_state.NONE:
            w.state = nng_worker_state.RECV;
            nng_ctx_recv(w.ctx, w.aio.aio);
            break;
        case nng_worker_state.RECV:
            if(w.aio.result != nng_errno.NNG_OK) {
                nng_ctx_recv(w.ctx, w.aio.aio);
                break;
            }
            rc = w.aio.get_msg( w.msg );
            if(rc != nng_errno.NNG_OK) {
                nng_ctx_recv(w.ctx, w.aio.aio);
                break;
            }
            w.state = nng_worker_state.WAIT;
            w.aio.sleep(w.delay);
            break;
        case nng_worker_state.WAIT:
            try{
                w.cb(&w.msg, w.context);
            } catch ( Exception e ) {
                if(w.logfile !is null) {
                    auto f = *(w.logfile);
                    f.write(format("Error in pool callback: [%d:%s] %s\n", e.line, e.file, e.msg));
                    f.flush();
                }
                w.msg.clear();
            }finally{
                w.aio.set_msg(w.msg);
                w.state = nng_worker_state.SEND;
                nng_ctx_send(w.ctx, w.aio.aio);                
            }    
            break;
        case nng_worker_state.SEND:
            rc = w.aio.result;
            if(rc != nng_errno.NNG_OK) {
                return;
            }
            w.state = nng_worker_state.RECV;
            nng_ctx_recv(w.ctx, w.aio.aio);
            break;
        default:
            w.unlock();
            enforce(false, "Bad pool worker state");
            break;
    }
    w.unlock();
}

struct NNGPool {
    NNGSocket *sock;
    void *context;
    File  _logfile;
    File* logfile;
    size_t nworkers;

    NNGPoolWorker*[] workers;

    @disable this();

    this(NNGSocket *isock, nng_pool_callback cb, size_t n, void* icontext, int logfd = -1  ) {
        enforce(isock.state == nng_socket_state.NNG_STATE_CREATED || isock.state == nng_socket_state.NNG_STATE_CONNECTED);
        enforce(isock.type == nng_socket_type.NNG_SOCKET_REP); // TODO: extend to surveyou
        enforce(cb != null);
        sock = isock;
        context = icontext;
        if(logfd == -1) {
            logfile = null;
        }else{
            _logfile = File("/dev/null", "wt");
            _logfile.fdopen(logfd, "wt");
            logfile = &_logfile;
        }            
        nworkers = n;
        for(auto i=0; i<n; i++) {
            NNGPoolWorker* w = new NNGPoolWorker(i, context, logfile);
            w.aio.realloc(cast(nng_aio_cb)(&nng_pool_stateful), cast(void*)w);
            w.cb = cb;
            auto rc = nng_ctx_open(&w.ctx, sock.m_socket);
            enforce(rc == 0);
            workers ~= w;
        }
    }    

    void init () {
        enforce(nworkers > 0);
        for(auto i=0; i<nworkers; i++) {
            nng_pool_stateful(workers[i]);
        }
    }

    void shutdown() {
        enforce(nworkers > 0);
        for(auto i=0; i<nworkers; i++) {
            workers[i].shutdown();
        }    
        for(auto i=0; i<nworkers; i++) {
            workers[i].wait();
        }    
    }
} // struct NNGPool


// ------------------ WebApp classes

alias nng_http_status = libnng.nng_http_status;
alias http_status = nng_http_status;

alias nng_mime_type = libnng.nng_mime_type;
alias mime_type = nng_mime_type;

alias nng_http_req = libnng.nng_http_req;
alias nng_http_res = libnng.nng_http_res;

version(withtls) {
    
    alias nng_tls_mode = libnng.nng_tls_mode;
    alias nng_tls_auth_mode = libnng.nng_tls_auth_mode;
    alias nng_tls_version = libnng.nng_tls_version;

    struct WebTLS {
        nng_tls_config* tls;
        
        @disable this();
        
        this(ref return scope WebTLS rhs) {}
        
        this( nng_tls_mode imode  ) {
            int rc;
            rc = nng_tls_config_alloc(&tls, imode);
            enforce(rc == 0, "TLS config init");
            nng_tls_config_hold(tls);
        }
        

        ~this() {
            nng_tls_config_free(tls);
        }

        void set_server_name ( string iname ) {
            auto rc = nng_tls_config_server_name(tls, iname.toStringz());
            enforce(rc == 0);
        }
        
        void set_ca_chain ( string pem, string crl = "" ) {
            auto rc = nng_tls_config_ca_chain(tls, pem.toStringz(), crl.toStringz());
            enforce(rc == 0);
        }

        void set_own_cert ( string pem, string key, string pwd = "" ) {
            auto rc = nng_tls_config_own_cert(tls, pem.toStringz(), key.toStringz(), pwd.toStringz());
            enforce(rc == 0);
        }

    // TODO: check why this two excluded from the lib
    /*
        void set_pass ( string ipass ) {
            auto rc = nng_tls_config_pass(tls, ipass.toStringz());
            enforce(rc == 0);
        }
        
        void set_key ( ubyte[] ipass ) {
            auto rc = nng_tls_config_key(tls, ipass.ptr, ipass.length);
            enforce(rc == 0);
        }
    */

        void set_auth_mode ( nng_tls_auth_mode imode ) {
            auto rc = nng_tls_config_auth_mode(tls, imode);
            enforce(rc == 0);
        }
        
        void set_ca_file ( string ica ) {
            auto rc = nng_tls_config_ca_file(tls, ica.toStringz());
            enforce(rc == 0);
        }

        void set_cert_key_file ( string ipem , string ikey ) {
            auto rc = nng_tls_config_cert_key_file(tls, ipem.toStringz(), ikey.toStringz());
            writeln("TDEBUG: ", nng_errstr(rc));
            enforce(rc == 0);
        }

        void set_version( nng_tls_version iminversion, nng_tls_version imaxversion ) {
            auto rc = nng_tls_config_version(tls, iminversion, imaxversion);
            enforce(rc == 0);
        }

        string engine_name() {
            char* buf = nng_tls_engine_name();
            return to!string(buf);
        }

        string engine_description() {
            char* buf = nng_tls_engine_description();
            return to!string(buf);
        }

        bool fips_mode() {
            return nng_tls_engine_fips_mode();
        }
    }

}


struct WebAppConfig {
    string root_path = "";
    string static_path = "";
    string static_url = "";
    string template_path = "";
    string prefix_url = "";
    this(ref return scope WebAppConfig rhs) {}
};

struct WebData {
    string route = null;
    string rawuri = null;
    string uri = null;
    string[] path = null;
    string[string] param = null;
    string[string] headers = null;
    string type = "text/html";
    size_t length = 0;
    string method = null;
    ubyte[] rawdata = null;
    string text = null;
    JSONValue json = null;
    http_status status = http_status.NNG_HTTP_STATUS_NOT_IMPLEMENTED;
    string msg = null;

    void clear() {
        route = "";   
        rawuri = "";   
        uri = "";     
        status = http_status.NNG_HTTP_STATUS_NOT_IMPLEMENTED;   
        msg = "";     
        path = [];    
        param = null;   
        headers = null; 
        type = "text/html";    
        length = 0;  
        method = "";  
        rawdata = [];
        text = "";
        json = null;
    }

    string toString() nothrow {
        try{
        return format(`
        <Webdata>
            route:      %s    
            rawuri:     %s
            uri:        %s
            status:     %s
            msg:        %s
            path:       %s
            param:      %s
            headers:    %s
            type:       %s
            length:     %d
            method:     %s
            len(data):  %s
            text:       %s 
            json:       %s
        </WebData>
        `,
        route    
        , rawuri   
        , uri      
        , status   
        , msg      
        , path     
        , param    
        , headers  
        , type     
        , length   
        , method   
        , rawdata.length
        , to!string(text)     
        , json.toString()     
        );
        }catch(Exception e) {
            perror("WD: toString error");
            return null;
        }
    }

    void parse_req ( nng_http_req *req ) {
        enforce(req != null);
    }

    // TODO: find the way to list all headers

    void parse_res ( nng_http_res *res ) {
        enforce(res != null);
        clear();
        status = cast(http_status)nng_http_res_get_status(res);
        msg = to!string(nng_http_res_get_reason(res));
        type = to!string(nng_http_res_get_header(res, toStringz("Content-type")));
        ubyte *buf;
        size_t len;
        nng_http_res_get_data(res, cast(void**)(&buf), &len);
        if(len > 0) {
            rawdata ~= buf[0..len];
        }
        if(type.startsWith("application/json")) {
            json = parseJSON(cast(string)(rawdata[0..len]));
        }else if(type.startsWith("text")) {
            text = cast(string)(rawdata[0..len]);
        }
        length = len;
        auto hlength = to!long(to!string(nng_http_res_get_header(res, toStringz("Content-length"))));
        enforce(hlength == length);
    }

    nng_http_req* export_req() {
        nng_http_req* req;
        nng_url *url;
        int rc;
        rc = nng_url_parse(&url, ((rawuri.length > 0) ? rawuri : "http://<unknown>"~uri).toStringz());
        rc = nng_http_req_alloc( &req, url );
        enforce(rc == 0);
        rc = nng_http_req_set_method(req, method.toStringz());
        enforce(rc == 0);
        rc = nng_http_req_set_header(req, "Content-type", type.toStringz());
        foreach(k; headers.keys) {            
            rc = nng_http_req_set_header(req, k.toStringz(), headers[k].toStringz());
        }
        if(type.startsWith("application/json")) {
            string buf = json.toString();
            rc = nng_http_req_copy_data(req, buf.toStringz(), buf.length);
            length = buf.length;
            enforce(rc==0, "webdata: copy json rep");
        }
        else if(type.startsWith("text")) {
            rc = nng_http_req_copy_data(req, text.toStringz(), text.length);
            length = text.length;
            enforce(rc==0, "webdata: copy text rep");
        }else{
            rc = nng_http_req_copy_data(req, rawdata.ptr, rawdata.length);
            length = rawdata.length;
            enforce(rc==0, "webdata: copy data rep");
        }
        rc = nng_http_req_set_header(req, "Content-length", to!string(length).toStringz());
        return req;    
    }

    nng_http_res* export_res() {
        char *buf = cast(char*)alloca(512);
        nng_http_res *res;
        int rc;
        rc = nng_http_res_alloc( &res );
        enforce(rc==0);
        rc = nng_http_res_set_status( res, cast(ushort)status );
        enforce(rc==0);
        if (status != nng_http_status.NNG_HTTP_STATUS_OK) {
            nng_http_res_reset(res);
            rc = nng_http_res_alloc_error( &res, cast(ushort)status );
            enforce(rc==0);
            rc = nng_http_res_set_reason(res, msg.toStringz);
            enforce(rc==0);
            if(text.length > 0) {
                rc = nng_http_res_copy_data(res, text.ptr, text.length);
                enforce(rc==0, "webdata: copy text rep");
            }    
            return res;
        }           
        {
            memcpy(buf, type.ptr, type.length); buf[type.length] = 0;
            rc = nng_http_res_set_header(res, "Content-type", buf);
            enforce(rc==0);
        }
        if(type.startsWith("application/json")) {
            scope string sbuf = json.toString();
            memcpy(buf, sbuf.ptr, sbuf.length);
            rc = nng_http_res_copy_data(res, buf, sbuf.length);
            length = sbuf.length;
            enforce(rc==0, "webdata: copy json rep");
        }
        else if(type.startsWith("text")) {
            rc = nng_http_res_copy_data(res, text.ptr, text.length);
            length = text.length;
            enforce(rc==0, "webdata: copy text rep");
        }else{
            if(rawdata.length > 0) {
                rc = nng_http_res_copy_data(res, rawdata.ptr, rawdata.length);
                length = rawdata.length;
                enforce(rc==0, "webdata: copy data rep");
            }    
        }

        return res;
    }
}   

alias webhandler = void function ( WebData*, WebData*, void* );


//----------------
void webrouter (nng_aio* aio) {

    int rc;
    nng_http_res *res;
    nng_http_req *req;
    nng_http_handler *h;
    
    void *reqbody;
    size_t reqbodylen;

    WebData sreq =  WebData.init;
    WebData srep =  WebData.init;
    WebApp  *app;

    char *sbuf = cast(char*)nng_alloc(4096);

    string errstr = "";
        
        const char* t1 = "NODATA";

    // TODO: invite something for proper default response for no handlers, maybe 100 or 204 ? To discuss.

    srep.type = "text/plain";
    srep.text = "No result";
    srep.status = nng_http_status.NNG_HTTP_STATUS_OK;
    
    
    req = cast(nng_http_req*)nng_aio_get_input(aio, 0);
    if(req is null) {
        errstr = "WR: get request";
        goto failure;
    }
    
    h = cast(nng_http_handler*)nng_aio_get_input(aio, 1);
    if(req is null) {
        errstr = "WR: get handler";
        goto failure;
    }
    
    app = cast(WebApp*)nng_http_handler_get_data(h);
    if(app is null) {
        errstr = "WR: get handler data";
        goto failure;
    }
    
    nng_http_req_get_data(req, &reqbody, &reqbodylen);

    sreq.method = cast(immutable)(fromStringz(nng_http_req_get_method(req)));
    
    sprintf(sbuf, "Content-type");
    sreq.type = cast(immutable)(fromStringz(nng_http_req_get_header(req, sbuf)));
    if(sreq.type.empty) 
        sreq.type = "text/plain";

    sreq.uri = cast(immutable)(fromStringz(nng_http_req_get_uri(req)));
    
    sreq.rawdata = cast(ubyte[])(reqbody[0..reqbodylen]);
    
    app.webprocess(&sreq, &srep);
    
    res = srep.export_res;

    
    nng_free(sbuf, 4096);
    nng_aio_set_output(aio, 0, res);
    nng_aio_finish(aio, 0);

    return;

failure:
    writeln("ERROR: "~errstr);
    nng_free(sbuf, 4096);
    nng_http_res_free(res);
    nng_aio_finish(aio, rc);
} // router handler



struct WebApp {
    string name;
    WebAppConfig config;
    nng_http_server *server;    
    nng_aio *aio;
    nng_url *url;
    webhandler[string] routes;
    void* context;
    
    @disable this();
    
    this( string iname, string iurl, WebAppConfig iconfig, void* icontext = null)
    {
        name = iname;
        context = icontext;
        auto rc = nng_url_parse(&url, iurl.toStringz());
        enforce(rc==0, "server url parse");
        config = iconfig;
        init();
    }
    this( string iname, string iurl, JSONValue iconfig, void* icontext = null)
    {
        name = iname;
        context = icontext;
        auto rc = nng_url_parse(&url, iurl.toStringz());
        enforce(rc==0, "server url parse");
        if("root_path" in iconfig )     config.root_path = iconfig["root_path"].str;
        if("static_path" in iconfig )   config.static_path = iconfig["static_path"].str;
        if("static_url" in iconfig )    config.static_url = iconfig["static_url"].str;
        if("template_path" in iconfig ) config.template_path = iconfig["template_path"].str;
        if("prefix_url" in iconfig )    config.prefix_url = iconfig["prefix_url"].str;
        init();
    }
    
    version(withtls) {
        void set_tls ( WebTLS tls ) {
            auto rc = nng_http_server_set_tls(server, tls.tls);
            enforce(rc==0, "server set tls");
        }
    }

    void route (string path, webhandler handler, string[] methods = ["GET"]) {
        int rc;
        bool wildcard = false;
        if(path.endsWith("/*")) {
            path = path[0..$-2];
            wildcard = true;
        }
        foreach(m; methods) {
            foreach(r; sort(routes.keys)) {
                enforce(m~":"~path != r, "router path already registered: " ~ m~":"~path);
            }
            routes[m~":"~path] = handler;
            nng_http_handler *hr;
            rc = nng_http_handler_alloc(&hr, toStringz(config.prefix_url~path), &webrouter);
            enforce(rc==0, "route handler alloc");
            rc = nng_http_handler_set_method(hr, m.toStringz());
            enforce(rc==0, "route handler set method");
            rc = nng_http_handler_set_data(hr, &this, null);
            enforce(rc==0, "route handler set context");
            if(wildcard) {
                rc = nng_http_handler_set_tree(hr);
                enforce(rc==0, "route handler tree");
            }            
            rc = nng_http_server_add_handler(server, hr);
            enforce(rc==0, "route handler add");
        }            
    }

    void start() {
        auto rc = nng_http_server_start(server);
        enforce(rc==0, "server start");
    }

    void stop() {
        nng_http_server_stop(server);
    }

    void webprocess( WebData *req, WebData *rep ) {
        int rc;
    
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        rep.type = "text/plain";
        rep.text = "Test result";

        nng_url *u;
        string ss = ("http://localhost"~req.uri~"\0");
        char[] buf = ss.dup;
        rc = nng_url_parse(&u, buf.ptr);
        enforce(rc == 0);
        req.route = cast(immutable)(fromStringz(u.u_path)).dup;
        req.path = req.route.split("/");
        if(req.path.length > 1 && req.path[0] == "")
            req.path = req.path[1..$];
        string query = cast(immutable)(fromStringz(u.u_query)).dup;
        foreach(p; query.split("&")) {
            auto a = p.split("=");
            if(a[0] != "")
                req.param[a[0]] = a[1];
        }
        nng_url_free(u);
        
        if(req.type.startsWith("application/json")) {
            try{
                req.json = parseJSON(cast(immutable)(fromStringz(cast(char*)req.rawdata)));
            }catch(JSONException e) {
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "Invalid json";
                return;
            }    
        }

        if(req.type.startsWith("text/")) {
            req.text = cast(immutable)(fromStringz(cast(char*)req.rawdata));
        }
        
        // TODO: implement full CEF parser for routes
        webhandler handler = null;   
        string rkey = req.method~":"~req.route;
        foreach(r; sort!("a > b")(routes.keys)) {
            if(rkey.startsWith(r)) {
                handler = routes[r];
                break;
            }                
        }
        if(handler == null)
            handler = &default_handler;

        handler(req, rep, context);

    }

    private:
    
    void init() {
        int rc;
        if(config.root_path == "")
            config.root_path = __FILE__.absolutePath.dirName;
        if(config.static_path == "")
            config.static_path = "/";
        if(config.static_url == "")
            config.static_url = config.static_path;
        rc = nng_http_server_hold(&server, url);
        enforce(rc==0, "server hold");
        
        nng_http_handler *hs;
        rc = nng_http_handler_alloc_directory(&hs, toStringz(config.prefix_url~"/"~config.static_path), buildPath(config.root_path, config.static_url).toStringz());
        enforce(rc==0, "static handler alloc");
        rc = nng_http_server_add_handler(server, hs);
        enforce(rc==0, "static handler add");
        
        rc = nng_aio_alloc(&aio, null, null);                    
        enforce(rc==0, "aio alloc");

    }

    static void default_handler ( WebData* req, WebData* rep, void* ctx ) {
        rep.type = "text/plain";
        rep.text = "Default reponse";
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
    }
} // struct WebApp

// for user defined result handlers
alias webclienthandler = void function ( WebData*, void* );

// for async client router
extern (C) struct WebClientAsync {
    char* uri;
    nng_http_req *req;
    nng_http_res *res;
    nng_aio *aio;
    void *context;
    webclienthandler commonhandler;
    webclienthandler errorhandler;
}

// common async client router
static void webclientrouter ( void* p ) {
    if(p == null) return;
    WebClientAsync *a = cast(WebClientAsync*)(p);
    WebData rep = WebData();
    rep.parse_res(a.res);
    rep.rawuri = to!string(a.uri);
    if(rep.status != nng_http_status.NNG_HTTP_STATUS_OK && a.errorhandler  != null)
        a.errorhandler(&rep, a.context);
    else    
        a.commonhandler(&rep, a.context);
    nng_http_req_free(a.req);
    nng_http_res_free(a.res);
    nng_aio_free(a.aio);
}

struct WebClient {

    nng_http_client *cli;
    nng_http_conn *conn;
    nng_http_req *req;
    nng_http_res *res;
    nng_url *url;
    bool connected;

    // constructor and connector are for future use woth streaming functions
    // for single transactions use static members (sync or async )

    this(string uri) {
        int rc; 
        connected = false;
        rc = nng_http_res_alloc(&res);
        enforce(rc == 0);
        rc = nng_http_req_alloc(&req, null);
        enforce(rc == 0);
        if(uri != null && uri != "") {
            rc = connect(uri);
            enforce(rc == 0);
        }    

    }

    int connect( string uri ) {
        int rc;
        nng_aio *aio;
        if(cli != null)
            nng_http_client_free(cli);
        rc = nng_aio_alloc(&aio, null, null);
        enforce(rc == 0);
        rc = nng_url_parse(&url, uri.toStringz());    
        enforce(rc == 0);
        rc = nng_http_client_alloc(&cli, url);
        enforce(rc == 0);
        nng_http_client_connect(cli, aio);
        nng_aio_wait(aio);
        rc = nng_aio_result(aio);
        enforce(rc == 0);
        conn = cast(nng_http_conn*)nng_aio_get_output(aio, 0);
        enforce(conn != null);
        connected = true;
        return 0;
    }

    ~this() {
        nng_http_client_free(cli);
        nng_url_free(url);
        nng_http_req_free(req);
        nng_http_res_free(res);
    }

    // static sync get
    static WebData get ( string uri, string[string] headers, Duration timeout = 30000.msecs ) {
        int rc;
        nng_http_client *cli;
        nng_url *url;
        nng_http_req *req;
        nng_http_res *res;
        nng_aio *aio;
        WebData wd = WebData();
        rc = nng_url_parse(&url, uri.toStringz());
        enforce(rc == 0);
        rc = nng_http_client_alloc(&cli, url);
        enforce(rc == 0);
        rc = nng_http_req_alloc(&req, url);
        enforce(rc == 0);
        rc = nng_http_res_alloc(&res);
        enforce(rc == 0);
        rc = nng_aio_alloc(&aio, null, null);
        enforce(rc == 0);
        nng_aio_set_timeout(aio, cast(nng_duration)timeout.total!"msecs");
        
        scope(exit) {
            nng_http_client_free(cli);
            nng_url_free(url);
            nng_aio_free(aio);
            nng_http_req_free(req);
            nng_http_res_free(res);
        }
        
        rc = nng_http_req_set_method(req, toStringz("GET"));
        enforce(rc == 0);
        foreach(k; headers.keys) {            
            rc = nng_http_req_set_header(req, k.toStringz(), headers[k].toStringz());
            enforce(rc == 0);
        }
        nng_http_client_transact(cli, req, res, aio);
        nng_aio_wait(aio);
        rc = nng_aio_result(aio);
        if(rc == 0) {
            wd.parse_res(res);
        }else{
            wd.status = nng_http_status.NNG_HTTP_STATUS_REQUEST_TIMEOUT;
            wd.msg = nng_errstr(rc);
        }
        return wd;
    }

    // static sync post
    static WebData post ( string uri, ubyte[] data, string[string] headers, Duration timeout = 30000.msecs ) {
        int rc;
        nng_http_client *cli;
        nng_url *url;
        nng_http_req *req;
        nng_http_res *res;
        nng_aio *aio;
        WebData wd = WebData();
        rc = nng_url_parse(&url, uri.toStringz());
        enforce(rc == 0);
        rc = nng_http_client_alloc(&cli, url);
        enforce(rc == 0);
        rc = nng_http_req_alloc(&req, url);
        enforce(rc == 0);
        rc = nng_http_res_alloc(&res);
        enforce(rc == 0);
        rc = nng_aio_alloc(&aio, null, null);
        enforce(rc == 0);
        nng_aio_set_timeout(aio, cast(nng_duration)timeout.total!"msecs");
        scope(exit) {
            nng_http_client_free(cli);
            nng_url_free(url);
            nng_aio_free(aio);
            nng_http_req_free(req);
            nng_http_res_free(res);
        }
        rc = nng_http_req_set_method(req, toStringz("POST"));
        enforce(rc == 0);
        foreach(k; headers.keys) {            
            rc = nng_http_req_set_header(req, k.toStringz(), headers[k].toStringz());
            enforce(rc == 0);
        }
        rc = nng_http_req_copy_data(req, data.ptr, data.length);
        enforce(rc == 0);
        nng_http_client_transact(cli, req, res, aio);
        nng_aio_wait(aio);
        rc = nng_aio_result(aio);
        if(rc == 0) {
            wd.parse_res(res);
        }else{
            wd.status = nng_http_status.NNG_HTTP_STATUS_REQUEST_TIMEOUT;
            wd.msg = nng_errstr(rc);
        }
        return wd;

    }

    // static async get
    static NNGAio get_async ( string uri, string[string] headers, webclienthandler handler, Duration timeout = 30000.msecs, void *context = null ) {
        int rc;
        nng_aio *aio;
        nng_http_client *cli;
        nng_http_req *req;
        nng_http_res *res;
        nng_url *url;
        rc = nng_url_parse(&url, uri.toStringz());
        enforce(rc == 0);
        rc = nng_http_client_alloc(&cli, url);
        enforce(rc == 0);
        rc = nng_http_req_alloc(&req, url);
        enforce(rc == 0);
        rc = nng_http_res_alloc(&res);
        enforce(rc == 0);
        rc = nng_aio_alloc(&aio, null, null);
        enforce(rc == 0);
        nng_aio_set_timeout(aio, cast(nng_duration)timeout.total!"msecs");
        WebClientAsync *a = new WebClientAsync();
        a.uri = cast(char*)uri.dup.toStringz();
        a.commonhandler = handler;
        a.context = context;
        a.req = req;
        a.res = res;
        a.aio = aio;
        rc = nng_aio_alloc(&aio, &webclientrouter, a);
        enforce(rc == 0);
        rc = nng_http_req_set_method(req, toStringz("GET"));
        enforce(rc == 0);
        foreach(k; headers.keys) {            
            rc = nng_http_req_set_header(req, k.toStringz(), headers[k].toStringz());
            enforce(rc == 0);
        }
        nng_http_client_transact(cli, req, res, aio);
        return NNGAio(aio);
    }

    // static async post
    static NNGAio post_async ( string uri, ubyte[] data, string[string] headers, webclienthandler handler, Duration timeout = 30000.msecs, void *context = null ) {
        int rc;
        nng_aio *aio;
        nng_http_client *cli;
        nng_http_req *req;
        nng_http_res *res;
        nng_url *url;
        rc = nng_url_parse(&url, uri.toStringz());
        enforce(rc == 0);
        rc = nng_http_client_alloc(&cli, url);
        enforce(rc == 0);
        rc = nng_http_req_alloc(&req, url);
        enforce(rc == 0);
        rc = nng_http_res_alloc(&res);
        enforce(rc == 0);
        rc = nng_aio_alloc(&aio, null, null);
        enforce(rc == 0);
        nng_aio_set_timeout(aio, cast(nng_duration)timeout.total!"msecs");
        WebClientAsync *a = new WebClientAsync();
        a.uri = cast(char*)uri.dup.toStringz();
        a.commonhandler = handler;
        a.context = context;
        a.req = req;
        a.res = res;
        a.aio = aio;
        rc = nng_aio_alloc(&aio, &webclientrouter, a);
        enforce(rc == 0);
        rc = nng_http_req_set_method(req, toStringz("POST"));
        enforce(rc == 0);
        foreach(k; headers.keys) {            
            rc = nng_http_req_set_header(req, k.toStringz(), headers[k].toStringz());
            enforce(rc == 0);
        }
        rc = nng_http_req_copy_data(req, data.ptr, data.length);
        enforce(rc == 0);
        nng_http_client_transact(cli, req, res, aio);
        return NNGAio(aio);
    }

    // common static method for any request methods and error handler ( inspired by ajax )
    // if text is not null data is ignored
    // for methods except POST, PUT, PATCH both text and data are ignored
    static NNGAio request ( 
        string method,
        string uri, 
        string[string] headers, 
        string text,
        ubyte[] data, 
        webclienthandler onsuccess,
        webclienthandler onerror,
        Duration timeout = 30000.msecs, 
        void *context = null ) 
    {
        int rc;
        nng_aio *aio;
        nng_http_client *cli;
        nng_http_req *req;
        nng_http_res *res;
        nng_url *url;
        rc = nng_url_parse(&url, uri.toStringz());
        enforce(rc == 0);
        rc = nng_http_client_alloc(&cli, url);
        enforce(rc == 0);
        rc = nng_http_req_alloc(&req, url);
        enforce(rc == 0);
        rc = nng_http_res_alloc(&res);
        enforce(rc == 0);
        rc = nng_aio_alloc(&aio, null, null);
        enforce(rc == 0);
        nng_aio_set_timeout(aio, cast(nng_duration)timeout.total!"msecs");
        WebClientAsync *a = new WebClientAsync();
        a.uri = cast(char*)uri.dup.toStringz();
        a.commonhandler = onsuccess;
        a.errorhandler = onerror;
        a.context = context;
        a.req = req;
        a.res = res;
        a.aio = aio;
        rc = nng_aio_alloc(&aio, &webclientrouter, a);
        enforce(rc == 0);
        rc = nng_http_req_set_method(req, toStringz(method));
        enforce(rc == 0);
        foreach(k; headers.keys) {            
            rc = nng_http_req_set_header(req, k.toStringz(), headers[k].toStringz());
            enforce(rc == 0);
        }
        if( method == "POST" || method == "PUT" || method == "PATCH" ) {
            if(text == null) {
                rc = nng_http_req_copy_data(req, data.ptr, data.length);
            }else{
                rc = nng_http_req_copy_data(req, text.toStringz(), text.length);
            }
            enforce(rc == 0);
        }    
        nng_http_client_transact(cli, req, res, aio);
        return NNGAio(aio);
    }

}

// WebSocket tools

alias nng_ws_onconnect = void function ( WebSocket*, void* );
alias nng_ws_onmessage = void function ( WebSocket*, ubyte[], void* );


struct WebSocket {
    
    WebSocketApp *app;
    void* context;
    nng_aio *rxaio;
    nng_aio *txaio;
    nng_stream *s;
    nng_ws_onmessage onmessage;
    nng_iov rxiov;
    nng_iov txiov;
    ubyte[] rxbuf;
    ubyte[] txbuf;
    
    @disable this();

    this( 
        WebSocketApp *_app, 
        nng_stream *_s, 
        nng_ws_onmessage _onmessage, 
        void* _context,
        size_t _bufsize = 4096 )
    {
        int rc;
        app = _app;
        s = _s;
        onmessage = _onmessage;
        context = _context;
        void delegate(void*) d1 = &(this.nng_ws_rxcb);
        rc = nng_aio_alloc(&rxaio, d1.funcptr, self());
        enforce(rc == 0, "Conn aio init0");
        void delegate(void*) d2 = &(this.nng_ws_txcb);
        rc = nng_aio_alloc(&txaio, d2.funcptr, self());
        enforce(rc == 0, "Conn aio init1");
        rxbuf = new ubyte[](_bufsize);
        txbuf = new ubyte[](_bufsize);
        rxiov.iov_buf = rxbuf.ptr;
        rxiov.iov_len = _bufsize;
        txiov.iov_buf = txbuf.ptr;
        txiov.iov_len = _bufsize;
        rc = nng_aio_set_iov(rxaio, 1, &rxiov);
        enforce(rc == 0, "Invalid rx iov");
        rc = nng_aio_set_iov(txaio, 1, &txiov);
        enforce(rc == 0, "Invalid tx iov");
        nng_stream_recv(s, rxaio);
    }
    
    void* self () {
        return cast(void*)&this;
    }


    void nng_ws_rxcb( void *ptr ){
        int rc;
        rc = nng_aio_result(rxaio);
        if(rc == 0){
            auto sz = nng_aio_count(rxaio);
            if(sz > 0){
                if(onmessage != null){
                    onmessage(cast(WebSocket*)self(), cast(ubyte[])(rxbuf[0..sz].dup), context);
                }                
            }
        }
        rc = nng_aio_set_iov(rxaio, 1, &rxiov);
        enforce(rc == 0, "Invalid rx iov1");
        nng_stream_recv(s, rxaio);
    }

    void nng_ws_txcb(void *ptr){
        int rc;
        rc = nng_aio_result(txaio);
        //TBD:
    }

    void send(ubyte[] data){
        int rc;
        txbuf[0..data.length] = data[0..data.length];
        txiov.iov_len = data.length;
        rc = nng_aio_set_iov(txaio, 1, &txiov);
        enforce(rc == 0, "Invalid tx iov");
        nng_stream_send(s, txaio);
        nng_aio_wait(txaio);
    }

}

struct WebSocketApp {
    @disable this();

    this( 
        string iuri, 
        nng_ws_onconnect ionconnect,
        nng_ws_onmessage ionmessage,
        void* icontext
    )
    {
        int rc;
        enforce(iuri.startsWith("ws://"),"URI should be ws://*");
        uri = iuri;
        starts = 0;
        s = null;
        onconnect = ionconnect;
        onmessage = ionmessage;
        context = icontext;
        rc = nng_mtx_alloc(&mtx);
        enforce(rc==0,"Listener init0");
        rc = nng_stream_listener_alloc(&sl, uri.toStringz());            
        enforce(rc==0,"Listener init1");
        rc = nng_stream_listener_set_bool(sl, toStringz(NNG_OPT_WS_RECV_TEXT), true);
        enforce(rc==0,"Listener init2");
        rc = nng_stream_listener_set_bool(sl, toStringz(NNG_OPT_WS_SEND_TEXT), true);
        enforce(rc==0,"Listener init3");
        void delegate(void*) d = &(this.accb);
        rc = nng_aio_alloc( &accio, d.funcptr, self() );
        enforce(rc==0,"Accept aio init");
        
    }

    void start()
    {
        int rc;
        nng_mtx_lock(mtx);
        if(starts == 0){
            rc = nng_stream_listener_listen(sl);
            enforce(rc==0,"Listener start");
            nng_stream_listener_accept(sl, accio);
        }
        starts++;
        nng_mtx_unlock(mtx);        
    }

    void* self () {
        return cast(void*)&this;
    }

    private:
        nng_mtx *mtx;
        int starts;
        string uri;
        void* context;
        nng_stream_listener *sl;
        nng_aio *accio;
        nng_stream *s;
        nng_iov rxiov;
        nng_ws_onconnect onconnect;
        nng_ws_onmessage onmessage;
        WebSocket*[] conns;

        void accb ( void* ptr ){
            int rv;
            WebSocket *c;
            nng_mtx_lock(mtx);
            rv = nng_aio_result(accio);    
            if(rv != 0){
                nng_stream_listener_accept(sl, accio);
                return;
            }
            s = cast(nng_stream*)nng_aio_get_output(accio, 0);
            enforce(s != null, "Invalid stream pointer");
            c = new WebSocket(cast(WebSocketApp*)self(), s, onmessage, context, 8192);
            enforce(c != null, "Invalid conn pointer");
            conns ~= c;
            onconnect(c, context);   
            nng_stream_listener_accept(sl, accio);
            nng_mtx_unlock(mtx);
        }
}
