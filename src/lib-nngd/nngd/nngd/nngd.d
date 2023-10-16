
module nngd.nngd;

import core.memory;
import core.time;
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

private import libnng;

import std.stdio;


@safe
T* ptr(T)(T[] arr, size_t off = 0) pure nothrow { return arr.length == 0 ? null : &arr[off]; }

alias nng_errno = libnng.nng_errno;
alias nng_errstr = libnng.nng_errstr;
alias toString=nng_errstr;

@safe
void nng_sleep(Duration val) nothrow {
    nng_msleep(cast(nng_duration)val.total!"msecs");
}

string toString(nng_sockaddr a){
    string s = "<ADDR:UNKNOWN>";
    switch(a.s_family){
        case nng_sockaddr_family.NNG_AF_NONE    : 
            s = format("<ADDR:NONE>");
            break;
        case nng_sockaddr_family.NNG_AF_UNSPEC  : 
            s = format("<ADDR:UNSPEC>");
            break;
        case nng_sockaddr_family.NNG_AF_INPROC  : 
            s = format("<ADDR:INPROC name: %s >", a.s_inproc.sa_name);
            break;
        case nng_sockaddr_family.NNG_AF_IPC     : 
            s = format("<ADDR:IPC path: %s >",a.s_ipc.sa_path);
            break;
        case nng_sockaddr_family.NNG_AF_INET    : 
            s = format("<ADDR:INET addr: %u port: %u >",a.s_in.sa_addr,a.s_in.sa_port);
            break;
        case nng_sockaddr_family.NNG_AF_INET6   : 
            s = format("<ADDR:INET6 scope: %u addr: %s port: %u >",a.s_in6.sa_scope,a.s_in6.sa_addr,a.s_in6.sa_port);
            break;
        case nng_sockaddr_family.NNG_AF_ZT      :  
            s = format("<ADDR:ZT nwid: %u nodeid: %u port: %u >",a.s_zt.sa_nwid,a.s_zt.sa_nodeid,a.s_zt.sa_port);
            break;
        case nng_sockaddr_family.NNG_AF_ABSTRACT: 
            s = format("<ADDR:ABSTRACT name: %s >",cast(string)a.s_abstract.sa_name[0..a.s_abstract.sa_len]);
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

    this(ref return scope NNGMessage src){
        auto rc = nng_msg_dup(&msg, src.pointer);
        enforce(rc == 0);
    }   
    
    this(nng_msg * msgref){
        enforce(msgref != null);
        msg = msgref;
    }   

    this( size_t size ){
        auto rc = nng_msg_alloc(&msg, size);
        enforce(rc == 0);
    } 
    
    ~this() {
        if(msg != null)
            nng_msg_free(msg);
    }

    @nogc @safe
    @property nng_msg* pointer() nothrow {
        return msg;
    }

    @nogc @safe 
    @property void pointer(nng_msg* p) nothrow {
        if(p) 
            msg = p;
        else {
            if(msg) nng_msg_free(msg);
            msg = null;
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
        static if (isArray!T){
            static assert((ForeachType!T).sizeof == 1, "None byte size array element are not supported");
            auto rc = nng_msg_append(msg, ptr(data), data.length );
            enforce(rc == 0);
            return 0;
        }else{            
            static if (T.sizeof == 1){
                T tmp = data;
                auto rc = nng_msg_append(msg, cast(void*)&tmp, 1);
                enforce(rc == 0);
            }                    
            static if (T.sizeof == 2){
                auto rc = nng_msg_append_u16(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4){
                auto rc = nng_msg_append_u32(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8){
                auto rc = nng_msg_append_u64(msg, data);
                enforce(rc == 0);
            }
            return 0;
        }
    }

    int body_prepend (T) ( const(T) data ) if(isArray!T || isUnsigned!T){
        static if (isArray!T){
            static assert((ForeachType!T).sizeof == 1, "None byte size array element are not supported");
            auto rc = nng_msg_insert(msg, ptr(data), data.length );
            enforce(rc == 0);
            return 0;
        } else {
            static if (T.sizeof == 1){
                T tmp = data;
                auto rc = nng_msg_insert(msg, cast(void*)&tmp, 1);
                enforce(rc == 0);
            }
            static if (T.sizeof == 2){
                auto rc = nng_msg_insert_u16(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4){
                auto rc = nng_msg_insert_u32(msg, data);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8){
                auto rc = nng_msg_insert_u64(msg, data);
                enforce(rc == 0);
            }
            return 0;
        }            
    }
    
    
    T body_chop (T) (size_t size = 0) if(isArray!T || isUnsigned!T){
        static if (isArray!T){
            if(size == 0) size = length;
            T data = cast(T) (bodyptr + (length - size)) [0..size];
            auto rc = nng_msg_chop(msg, size);
            enforce(rc == 0);
            return data;
        } else {
            T tmp;
            static if (T.sizeof == 1){ 
                tmp = cast(T)*(bodyptr + (length - 1));
                auto rc = nng_msg_chop(msg, 1);
                enforce(rc == 0);
            }
            static if (T.sizeof == 2){
                auto rc = nng_msg_chop_u16(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4){
                auto rc = nng_msg_chop_u32(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8){
                auto rc = nng_msg_chop_u64(msg, &tmp);
                enforce(rc == 0);
            }
            return tmp;
        }            
    }            

    
    T body_trim (T) (size_t size = 0) if(isArray!T || isUnsigned!T) {
        static if (isArray!T){
            if(size == 0) size = length;
            T data = cast(T) (bodyptr) [0..size];
            auto rc = nng_msg_trim(msg, size);
            enforce(rc == 0);
            return data;
        } else {
            T tmp;
            static if (T.sizeof == 1){
                tmp = cast(T)*(bodyptr);
                auto rc = nng_msg_trim(msg, 1);
                enforce(rc == 0);
            }
            static if (T.sizeof == 2){
                auto rc = nng_msg_trim_u16(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 4){
                auto rc = nng_msg_trim_u32(msg, &tmp);
                enforce(rc == 0);
            }
            static if (T.sizeof == 8){
                auto rc = nng_msg_trim_u64(msg, &tmp);
                enforce(rc == 0);
            }
            return tmp;
        }            
    }            
    
    // TODO: body structure map
    // TODO: header modification msg_header_* ( will be required for some protocols in raw mode only )
} // struct NNGMessage

extern (C) alias nng_aio_cb = void function (void *);

struct NNGAio {
    nng_aio* aio;

    @disable this();

    this( nng_aio_cb cb, void* arg ){
        auto rc = nng_aio_alloc( &aio,  cb, arg );
        enforce(rc == 0);
    }

    ~this() {
        if(aio)
            nng_aio_free(aio);
    }

    void realloc( nng_aio_cb cb, void* arg ){
        if(aio)
            nng_aio_free(aio);
        auto rc = nng_aio_alloc( &aio,  cb, arg );            
        enforce(rc == 0);
    }
    
    // ---------- pointer prop
    
    @nogc @safe
    @property nng_aio* pointer() { return aio; }

    @nogc @safe
    @property void pointer( nng_aio* p ) {
        if(p){
            if(aio) nng_aio_free(aio);
            aio = p;
        } else { 
            if(aio){
                nng_aio_free(aio);
                aio = null;
            }
        }
    }

    // ---------- status prop
    
    @nogc @safe
    @property size_t count () nothrow {
        return (aio) ? nng_aio_count(aio) : 0;
    }
    
    @nogc @safe
    @property nng_errno result () nothrow {
        return (aio) ? cast(nng_errno) nng_aio_result(aio) : nng_errno.NNG_ENOENT;
    }

    @nogc @safe
    @property void timeout ( Duration val ) nothrow {
        if(aio)
            nng_aio_set_timeout(aio, cast(nng_duration)val.total!"msecs");
    }        

    // ---------- controls

    bool begin () {
        return (aio) ? nng_aio_begin(aio) : false;
    }

    void wait() {
        if(aio) 
            nng_aio_wait(aio);
    }
    
    void sleep ( Duration val ) {
        if(aio)
            nng_sleep_aio(cast(nng_duration)val.total!"msecs", aio);
    }


    /*
        = no callback
    */
    void abort ( nng_errno err ) {
        if(aio)
            nng_aio_abort(aio, cast(int) err);
    }
    
    /*
        = callback
    */
    void finish ( nng_errno err ) {
        if(aio)
            nng_aio_finish(aio, cast(int) err);
    }

    extern (C) alias nng_aio_ccb = void function (nng_aio *, void*, int);
    void defer ( nng_aio_ccb cancelcb, void *arg ){
        if(aio)
            nng_aio_defer ( aio, cancelcb, arg );
    }

    /*
        = abort(NNG_CANCELLED)
        = no callback
        = no wait for abort and callback complete
    */
    void cancel () {
        if(aio)
            nng_aio_cancel(aio);
    }
    
    /*
        = abort(NNG_CANCELLED)
        = no callback
        = wait for abort and callback complete
    */
    void stop () {
        if(aio)
            nng_aio_stop(aio);
    }

    // ---------- messages

    int get_msg ( NNGMessage *msg ) {
        if(aio){
            nng_msg* p = nng_aio_get_msg(aio);
            if(p){
                msg.pointer(null);
                msg.pointer(p);
                return 0;
            }
            return -1;
        }    
        return -1;
    }
    
    void set_msg ( ref NNGMessage msg ) {
        if(aio)
            nng_aio_set_msg(aio, msg.pointer);
    }

    void clear_msg () {
        if(aio)
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
    
    this(nng_socket_type itype, bool iraw = false){
        int rc;
        m_type = itype;
        m_raw = iraw;
        m_state = nng_socket_state.NNG_STATE_NONE;
        with(nng_socket_type) {
        final switch(itype){
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
        if(rc != 0){
            m_state = nng_socket_state.NNG_STATE_ERROR;
            m_errno = cast(nng_errno)rc;
        }else{
            m_state = nng_socket_state.NNG_STATE_CREATED;
            m_errno = cast(nng_errno)0;
        }

    } // this

    int close(){
        int rc;
        m_errno = cast(nng_errno)0;
        foreach(ctx; m_ctx){
            rc = nng_ctx_close(ctx);
            if(rc != 0){
                m_errno = cast(nng_errno)rc;
                return rc;
            }                
        }
        rc = nng_close(m_socket);
        if(rc == 0){
            m_state = nng_socket_state.NNG_STATE_NONE;
        } else {
            m_errno = cast(nng_errno)rc;
        }    
        return rc;
    }

    // setup listener

    int listener_create(const(string) url){
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_CREATED){
            auto rc = nng_listener_create( &m_listener, m_socket, toStringz(url) );
            if( rc != 0){
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            m_state = nng_socket_state.NNG_STATE_PREPARED;
            return 0;
        }else{
            return -1;
        }
    }        

    int listener_start( const bool nonblock = false ){
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_PREPARED){
            auto rc =  nng_listener_start(m_listener, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 );
            if( rc != 0){
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
        if(m_state == nng_socket_state.NNG_STATE_CREATED){
            auto rc = nng_listen(m_socket, toStringz(url), &m_listener, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 );
            if( rc != 0){
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

    int subscribe ( string tag ){
        if(m_subscriptions.canFind(tag))
            return 0;
        setopt_buf(NNG_OPT_SUB_SUBSCRIBE,cast(ubyte[])(tag.dup));
        if(m_errno == 0)
            m_subscriptions ~= tag;
        return m_errno;    
    }

    int unsubscribe ( string tag ) {
        size_t i = m_subscriptions.countUntil(tag);
        if(i < 0)
            return 0;
        setopt_buf(NNG_OPT_SUB_UNSUBSCRIBE,cast(ubyte[])(tag.dup));                
        if(m_errno == 0)
            m_subscriptions = m_subscriptions[0..i]~m_subscriptions[i+1..$];
        return m_errno;    
    }

    int clearsubscribe (){
        size_t i;
        foreach(tag; m_subscriptions){
            i = m_subscriptions.countUntil(tag);
            if(i < 0) continue;
            setopt_buf(NNG_OPT_SUB_UNSUBSCRIBE,cast(ubyte[])(tag.dup));
            if(m_errno != 0)
                return m_errno;
            m_subscriptions = m_subscriptions[0..i]~m_subscriptions[i+1..$];
        }
        return 0;
    }

    string[] subscriptions(){
        return m_subscriptions;
    }

    // setup dialer
    
    int dialer_create(const(string) url) nothrow {
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_CREATED){
            auto rc = nng_dialer_create( &m_dialer, m_socket, toStringz(url) );
            if( rc != 0){
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
        if(m_state == nng_socket_state.NNG_STATE_PREPARED){
            auto rc =  nng_dialer_start(m_dialer, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 );
            if( rc != 0){
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
        if(m_state == nng_socket_state.NNG_STATE_CREATED){
            auto rc = nng_dial(m_socket, toStringz(url), &m_dialer, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 );
            if( rc != 0){
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
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            m_errno = (() @trusted => cast(nng_errno) nng_sendmsg( m_socket, msg.pointer, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0))();
            if (m_errno !is nng_errno.init) {
                return -1;
            }
            return 0;
        }
        return -1;
    }

    int send (T)( const(T) data , bool nonblock = false ) if(isArray!T){
        alias U=ForeachType!T;
        static assert(U.sizeof == 1, "None byte size array element are not supported");
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            auto rc = nng_send(m_socket, ptr(cast(ubyte[])data), data.length, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0);
            if( rc != 0){
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            return 0;
        }
        return -1;
    }
    
    int sendaio ( ref NNGAio aio ) {
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            if(aio.pointer){
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
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            sz =(sz==0)?data.length:sz;
            m_errno = (() @trusted => cast(nng_errno)nng_recv(m_socket, ptr(data), &sz, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 ))();
            if (m_errno !is nng_errno.init) {    
                return -1;
            }
            return sz;
        }
        return -1;
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
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
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
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            void* buf;
            size_t sz;
            auto rc = nng_recv(m_socket, &buf, &sz, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 + nng_flag.NNG_FLAG_ALLOC );
            if (rc != 0) { 
                m_errno = cast(nng_errno)rc;
                return T.init;
            }
            GC.addRange(buf,sz);
            return (cast(U*)buf)[0..sz];
        }
        return T.init;
    }
    
    int receiveaio ( ref NNGAio aio ) {
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            if(aio.pointer){
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
        @property void recvbuf(int val){ setopt_int(NNG_OPT_RECVBUF,val); }

        @property int sendbuf() { return getopt_int(NNG_OPT_SENDBUF); } 
        @property void sendbuf(int val){ setopt_int(NNG_OPT_SENDBUF,val); }

        @property int recvfd() { return (m_may_recv) ? getopt_int(NNG_OPT_RECVFD) : -1; } 
        @property int sendfd() { return (m_may_send) ? getopt_int(NNG_OPT_SENDFD) : -1; } 

        @property Duration recvtimeout() { return getopt_duration(NNG_OPT_RECVTIMEO); } 
        @property void recvtimeout(Duration val){ setopt_duration(NNG_OPT_RECVTIMEO,val); }

        @property Duration sendtimeout() { return getopt_duration(NNG_OPT_SENDTIMEO); } 
        @property void sendtimeout(Duration val){ setopt_duration(NNG_OPT_SENDTIMEO,val); }

        @property nng_sockaddr locaddr() { return (m_may_send) ? getopt_addr(NNG_OPT_LOCADDR,nng_property_base.NNG_BASE_DIALER) : getopt_addr(NNG_OPT_LOCADDR,nng_property_base.NNG_BASE_LISTENER); } 
        @property nng_sockaddr remaddr() { return (m_may_send) ? getopt_addr(NNG_OPT_REMADDR,nng_property_base.NNG_BASE_DIALER) : nng_sockaddr(nng_sockaddr_family.NNG_AF_NONE); } 
    } // nothrow
    
    @property string url() { 
        if(m_may_send)
            return getopt_string(NNG_OPT_URL,nng_property_base.NNG_BASE_DIALER); 
        else if(m_may_recv)    
            return getopt_string(NNG_OPT_URL,nng_property_base.NNG_BASE_LISTENER); 
        else            
            return getopt_string(NNG_OPT_URL,nng_property_base.NNG_BASE_SOCKET); 
    }

    @property int maxttl() { return getopt_int(NNG_OPT_MAXTTL); } 
    /// MAXTTL a value between 0 and 255, inclusive. Where 0 is infinite
    @property void maxttl(uint val)
    in (val <= 255, "MAXTTL, hops cannot be greater than 255")
    do { 
        setopt_int(NNG_OPT_MAXTTL,val);
    }
    
    @property int recvmaxsz() { return getopt_int(NNG_OPT_RECVMAXSZ); } 
    @property void recvmaxsz(int val) { return setopt_int(NNG_OPT_RECVMAXSZ,val); } 

    @property Duration reconnmint() { return getopt_duration(NNG_OPT_RECONNMINT); } 
    @property void reconnmint(Duration val){ setopt_duration(NNG_OPT_RECONNMINT,val); }

    @property Duration reconnmaxt() { return getopt_duration(NNG_OPT_RECONNMAXT); } 
    @property void reconnmaxt(Duration val){ setopt_duration(NNG_OPT_RECONNMAXT,val); }

    // TODO: NNG_OPT_IPC_*, NNG_OPT_TLS_*, NNG_OPT_WS_*  
private:
    nothrow {
        void setopt_int(string opt, int val) {
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_int(m_socket,toStringz(opt),val);
            if(rc == 0){ return; }else{ m_errno = cast(nng_errno)rc; } 
        }

        int getopt_int(string opt) {
            m_errno = cast(nng_errno)0;
            int p;
            auto rc = nng_socket_get_int(m_socket,toStringz(opt),&p);
            if(rc == 0){ return p; }else{ m_errno = cast(nng_errno)rc; return -1; }    
        }
        
        void setopt_ulong(string opt, ulong val){
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_uint64(m_socket,toStringz(opt),val);
            if(rc == 0){ return; }else{ m_errno = cast(nng_errno)rc; } 
        }

        ulong getopt_ulong(string opt) {
            m_errno = cast(nng_errno)0;
            ulong p;
            auto rc = nng_socket_get_uint64(m_socket,toStringz(opt),&p);
            if(rc == 0){ return p; }else{ m_errno = cast(nng_errno)rc; return -1; }    
        }
        
        void setopt_size(string opt, size_t val){
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_size(m_socket,toStringz(opt),val);
            if(rc == 0){ return; }else{ m_errno = cast(nng_errno)rc; } 
        }
        
        size_t getopt_size(string opt) {
            m_errno = cast(nng_errno)0;
            size_t p;
            auto rc = nng_socket_get_size(m_socket,toStringz(opt),&p);
            if(rc == 0){ return p; }else{ m_errno = cast(nng_errno)rc; return -1; }    
        }
        
        string getopt_string(string opt, nng_property_base base = nng_property_base.NNG_BASE_SOCKET ) { 
            m_errno = cast(nng_errno)0;
            char *ptr;
            int rc;
            switch(base){
                case nng_property_base.NNG_BASE_DIALER:
                    rc = nng_dialer_get_string(m_dialer,cast(const char*)toStringz(opt),&ptr); 
                break;
                case nng_property_base.NNG_BASE_LISTENER:
                    rc = nng_listener_get_string(m_listener,cast(const char*)toStringz(opt),&ptr); 
                break;
                default:
                    rc = nng_socket_get_string(m_socket,cast(const char*)toStringz(opt),&ptr); 
                break;
            }    
            if(rc == 0){ return to!string(ptr); }else{ m_errno = cast(nng_errno)rc; return "<none>"; }            
        }

        void setopt_string(string opt, string val){
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_string(m_socket,toStringz(opt),toStringz(val));
            if(rc == 0){ return; }else{ m_errno = cast(nng_errno)rc; }                
        }
        
        void setopt_buf(string opt, ubyte[] val){
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set(m_socket,toStringz(opt),ptr(val),val.length);
            if(rc == 0){ return; }else{ m_errno = cast(nng_errno)rc; }                
        }

        Duration getopt_duration(string opt){
            m_errno = cast(nng_errno)0;
            nng_duration p;
            auto rc = nng_socket_get_ms(m_socket,toStringz(opt),&p);
            if(rc == 0){
                return msecs(p);
            }else{
                m_errno = cast(nng_errno)rc;
                return infiniteDuration;
            }
        }
        
        void setopt_duration(string opt, Duration val) {
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_ms(m_socket,cast(const char*)toStringz(opt),cast(int)val.total!"msecs"); 
            if(rc == 0){ return; }else{ m_errno = cast(nng_errno)rc; } 
        }

        nng_sockaddr getopt_addr(string opt, nng_property_base base = nng_property_base.NNG_BASE_SOCKET ){
            m_errno = cast(nng_errno)0;
            nng_sockaddr addr;
            int rc;
            switch(base){
                case nng_property_base.NNG_BASE_DIALER:
                    rc = nng_dialer_get_addr(m_dialer,toStringz(opt),&addr);
                    break;
                case nng_property_base.NNG_BASE_LISTENER:
                    rc = nng_listener_get_addr(m_listener,toStringz(opt),&addr);
                    break;
                default:
                    rc = nng_socket_get_addr(m_socket,toStringz(opt),&addr);
                    break;
            }                
            if(rc == 0){ return addr; } else { m_errno = cast(nng_errno)rc; addr.s_family = nng_sockaddr_family.NNG_AF_NONE; return addr; }
        }
        
        void setopt_addr(string opt, nng_sockaddr val){
            m_errno = cast(nng_errno)0;
            auto rc = nng_socket_set_addr(m_socket,cast(const char*)toStringz(opt),&val);
            if(rc == 0){ return; }else{ m_errno = cast(nng_errno)rc; }
        }
    } // nothrow
}   // struct Socket


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
    nng_ctx ctx;
    void *context;
    nng_pool_callback cb;
    this(int iid, void *icontext){
        this.id = iid;
        this.context = icontext;
        this.state = nng_worker_state.NONE;
        this.msg = NNGMessage(0);
        this.aio = NNGAio(null, null);
        this.delay = msecs(0);
        this.cb = null;
    }
    void wait(){
        this.aio.wait();            
    }
    void shutdown(){
        this.state = nng_worker_state.EXIT;
        this.aio.stop();
    }
} // struct NNGPoolWorker

extern (C) void nng_pool_stateful ( void* p ){
    if(p == null) return;
    NNGPoolWorker *w = cast(NNGPoolWorker*)p;
    switch(w.state){
        case nng_worker_state.EXIT:
            return;
        case nng_worker_state.NONE:
            w.state = nng_worker_state.RECV;
            nng_ctx_recv(w.ctx, w.aio.aio);
            break;
        case nng_worker_state.RECV:
            auto rc = w.aio.result;
            if(rc != nng_errno.NNG_OK){
                nng_ctx_recv(w.ctx, w.aio.aio);
                break;
            }
            w.aio.get_msg(&w.msg);
            w.state = nng_worker_state.WAIT;
            w.aio.sleep(w.delay);
            break;
        case nng_worker_state.WAIT:
            w.cb(&w.msg, w.context);
            w.aio.set_msg(w.msg);
            w.state = nng_worker_state.SEND;
            nng_ctx_send(w.ctx, w.aio.aio);
            break;
        case nng_worker_state.SEND:
            auto rc = w.aio.result;
            if(rc != nng_errno.NNG_OK){
                return;
            }
            w.state = nng_worker_state.RECV;
            nng_ctx_recv(w.ctx, w.aio.aio);
            break;
        default:
            enforce(false, "Bad pool worker state");
            break;
    }
}

struct NNGPool {
    NNGSocket *sock;
    void *context;
    size_t nworkers;

    NNGPoolWorker*[] workers;

    @disable this();


    this(NNGSocket *isock, nng_pool_callback cb, size_t n, void* icontext ){
        enforce(isock.state == nng_socket_state.NNG_STATE_CREATED || isock.state == nng_socket_state.NNG_STATE_CONNECTED);
        enforce(isock.type == nng_socket_type.NNG_SOCKET_REP); // TODO: extend to surveyou
        enforce(cb != null);
        sock = isock;
        context = icontext;
        nworkers = n;
        for(auto i=0; i<n; i++){
            NNGPoolWorker* w = new NNGPoolWorker(i, icontext);
            w.aio.realloc(cast(nng_aio_cb)(&nng_pool_stateful), cast(void*)w);
            w.cb = cb;
            auto rc = nng_ctx_open(&w.ctx, sock.m_socket);
            enforce(rc == 0);
            workers ~= w;
        }
    }    

    void init () {
        enforce(nworkers > 0);
        for(auto i=0; i<nworkers; i++){
            nng_pool_stateful(workers[i]);
        }
    }

    void shutdown() {
        enforce(nworkers > 0);
        for(auto i=0; i<nworkers; i++){
            workers[i].shutdown();
        }    
        for(auto i=0; i<nworkers; i++){
            workers[i].wait();
        }    
    }

} // struct NNGPool


// ------------------ WebApp classes

alias nng_http_status = libnng.nng_http_status;
alias http_status = nng_http_status;
alias nng_tls_mode = libnng.nng_tls_mode;
alias nng_tls_auth_mode = libnng.nng_tls_auth_mode;
alias nng_tls_version = libnng.nng_tls_version;

alias nng_http_req = libnng.nng_http_req;
alias nng_http_res = libnng.nng_http_res;

struct WebAppConfig {
    string root_path = "";
    string static_path = "";
    string static_url = "";
    string template_path = "";
    string prefix_url = "";
    this(ref return scope WebAppConfig rhs) {}
};

struct WebData {
    string route;
    string uri;
    string[] path;
    string[string] param;
    string type;
    size_t length;
    string method;
    ubyte[] rawdata;
    string text;
    JSONValue json;
    http_status status;
    string msg;
}   

alias webhandler = WebData function ( WebData, void* );

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
    
    void route (string path, webhandler handler, string[] methods = ["GET"]){
        int rc;
        bool wildcard = false;
        if(path.endsWith("/*")){
            path = path[0..$-2];
            wildcard = true;
        }
        foreach(m; methods){
            foreach(r; sort(routes.keys)){
                enforce(m~":"~path != r, "router path already registered: " ~ m~":"~path);
            }
            routes[m~":"~path] = handler;
            nng_http_handler *hr;
            rc = nng_http_handler_alloc(&hr, toStringz(config.prefix_url~path), &router);
            enforce(rc==0,"route handler alloc");
            rc = nng_http_handler_set_method(hr, m.toStringz());
            enforce(rc==0,"route handler set method");
            rc = nng_http_handler_set_data(hr, &this, null);
            enforce(rc==0,"route handler set context");
            if(wildcard){
                rc = nng_http_handler_set_tree(hr);
                enforce(rc==0,"route handler tree");
            }            
            rc = nng_http_server_add_handler(server, hr);
            enforce(rc==0,"route handler add");
        }            
    }

    void start(){
        auto rc = nng_http_server_start(server);
        enforce(rc==0, "server start");
    }

    private:
    
    void init(){
        int rc;
        if(config.root_path == "")
            config.root_path = __FILE__.absolutePath.dirName;
        if(config.static_path == "")
            config.static_path = "/";
        if(config.static_url == "")
            config.static_url = config.static_path;
        rc = nng_http_server_hold(&server, url);
        enforce(rc==0,"server hold");
        
        nng_http_handler *hs;
        rc = nng_http_handler_alloc_directory(&hs, toStringz(config.prefix_url~"/"~config.static_path), buildPath(config.root_path,config.static_url).toStringz());
        enforce(rc==0,"static handler alloc");
        rc = nng_http_server_add_handler(server, hs);
        enforce(rc==0,"static handler add");
        
        rc = nng_aio_alloc(&aio, null, null);                    
        enforce(rc==0,"aio alloc");

    }

    static WebData default_handler ( WebData req, void* ctx ){
        WebData rep = { 
            type : "application/json",
            json : parseJSON("{\"response\": 200}"),
            status : nng_http_status.NNG_HTTP_STATUS_OK
        };
        return rep;
    }
        
    extern(C) static void router (nng_aio* aio) {
        int rc;
        nng_http_res *res;
        nng_http_req *req;
        nng_http_handler *h;
        void *reqbody;
        size_t reqbodylen;
        
        WebData sreq, srep;
        WebApp *app;

        rc = nng_http_res_alloc(&res);
        enforce(rc == 0, "router: res alloc");

        scope(failure){
            nng_http_res_free(res);
            nng_aio_finish(aio, rc);
        }

        scope(exit){
            nng_aio_set_output(aio, 0, res);
            nng_aio_finish(aio, 0);
        }
        
        req = cast(nng_http_req*)nng_aio_get_input(aio, 0);
        enforce(req != null, "router: req extract");
        
        h = cast(nng_http_handler*)nng_aio_get_input(aio, 1);
        enforce(req != null, "router: handler extract");
        
        app = cast(WebApp*)nng_http_handler_get_data(h);
        enforce(app != null, "router: app extract");

        nng_http_req_get_data(req, &reqbody, &reqbodylen);

        sreq.method = to!string(nng_http_req_get_method(req));
        sreq.type = to!string(nng_http_req_get_header(req, toStringz("Content-type")));
        sreq.uri = to!string(nng_http_req_get_uri(req));
        nng_url *u;
        rc = nng_url_parse(&u,("http://localhost"~sreq.uri).toStringz());
        enforce(rc==0, "router: url parse");
        sreq.route = to!string(u.u_path);
        sreq.path = to!string(u.u_path).split("/");
        if(sreq.path.length > 1 && sreq.path[0] == "")
            sreq.path = sreq.path[1..$];
        foreach(p; to!string(u.u_query).split("&")){
            auto a = p.split("=");
            if(a[0] != "")
                sreq.param[a[0]] = a[1];
        }

        sreq.rawdata = cast(ubyte[])(reqbody[0..reqbodylen].idup);
        
        if(sreq.type.startsWith("application/json")){
            sreq.json = parseJSON(to!string(cast(char*)reqbody[0..reqbodylen].idup));
        }
        
        if(sreq.type.startsWith("text/")){
            sreq.text = to!string(cast(char*)reqbody[0..reqbodylen].idup);
        }

        
        // TODO: implement full CEF parser for routes
        webhandler handler = null;    
        foreach(r; sort(app.routes.keys)){
            if(r.startsWith(sreq.method~":"~sreq.route)){
                handler = app.routes[r];
                break;
            }                
        }
        if(handler == null)
            handler = &app.default_handler;

        srep = handler(sreq, app.context);
        
        nng_http_res_set_status(res, cast(ushort)srep.status);
        if(srep.status != nng_http_status.NNG_HTTP_STATUS_OK)
            return;
        
        if(srep.type.startsWith("application/json")){
            string buf = srep.json.toString();
            rc = nng_http_res_copy_data(res, buf.toStringz(), buf.length);
            enforce(rc==0, "router: copy json rep");
        }
        else if(srep.type.startsWith("text")){
            rc = nng_http_res_copy_data(res, srep.text.toStringz(), srep.text.length);
            enforce(rc==0, "router: copy text rep");
        }else{
            rc = nng_http_res_copy_data(res, srep.rawdata.ptr, srep.rawdata.length);
            enforce(rc==0, "router: copy data rep");
        }

    }

} // struct WebApp















