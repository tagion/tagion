
module nngd.nngd;

import core.memory;
import core.time;
import std.conv;
import std.string;
import std.typecons;
import std.algorithm;
import std.datetime.systime;


import libnng;


@safe
T* ptr(T)(T[] arr, size_t off = 0) pure nothrow { return arr.length == 0 ? null : &arr[off]; }

alias nng_errno = libnng.nng_errno;


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

string toString(nng_errno e){
    return nng_errstr(cast(int)e);        
}

string nng_strerror( int e ){
    return nng_errstr(e);
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

        /+
        default:
                rc = -1;
+/  
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
        if(!m_subscriptions.canFind(tag))
            return 0;
        setopt_buf(NNG_OPT_SUB_UNSUBSCRIBE,cast(ubyte[])(tag.dup));                
        if(m_errno == 0)
            m_subscriptions.remove(tag);
        return m_errno;    
    }

    int clearsubscribe (){
        foreach(tag; m_subscriptions){
            setopt_buf(NNG_OPT_SUB_UNSUBSCRIBE,cast(ubyte[])(tag.dup));
            if(m_errno != 0)
                return m_errno;
            if(m_subscriptions.canFind(tag))    
                m_subscriptions.remove(tag);    
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

    /+ I don't think we need the size and offset 
    // because it east to move the posstion in an array
    // like
    // auto buf=new ubyte[100]
    // _send(buf[offset..size+offset]);
   
    I suggest to use a template Type because the it work ofr both char[] and byte[] ubyte[] etc..
    +/
    int _send (T)( const(T) data , bool nonblock = false) if(isArray!T)
     {
        alias U=ForeachType!T;
        static assert(U.sizeof == 1, "None byte size array element are not supported");

        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            void* ptr=cast(void*)&data[0];
            auto rc = nng_send(m_socket, ptr, data.length, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0);
            if( rc != 0){
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            return 0;
        }
        return -1;
    }
    // send & receive
     int send ( ubyte[] data , bool nonblock = false, size_t size = 0, size_t offset = 0 ){
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            auto rc = nng_send(m_socket, ptr(data,offset), (size > 0) ? size : (data.length - offset), nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0);
            if( rc != 0){
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            return 0;
        }else{
            return -1;
        }
    }
    
    int send ( const(char[]) s, const bool nonblock = false ) nothrow {
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            auto data = cast(ubyte[])(s.dup);
            auto rc = nng_send(m_socket, ptr(data), data.length, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0);
            if( rc != 0){
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            return 0;
        }
        return -1;
        
    }

    /**
        Receives a data buffer of the max size data.length 
Params:
            data = preallocated buffer
            nonblock = set the non blocking mode
            sz = if sz != the this sz is used as max size
*/
    @nogc @safe
    const(ubyte[]) _receive ( ubyte[] data,  bool nonblock = false, size_t sz=0 ) nothrow 
        in(data.length>=sz)
        in(data.length)
do {
        m_errno = nng_errno.init;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            sz =(sz==0)?data.length:sz;
            m_errno = (() @trusted => cast(nng_errno)nng_recv(m_socket, &data[0], &sz, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 ))();
            if (m_errno !is nng_errno.init) {    
                return null;
            }
            return data[0..sz];
        }
        return null;
    }

     int receive ( ubyte[] data, size_t* sz, bool nonblock = false ){
        m_errno = cast(nng_errno)0;
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            auto rc = nng_recv(m_socket, ptr(data), sz, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 );
            if( rc != 0){
                m_errno = cast(nng_errno)rc;
                return rc;
            }
            data = data[0..*sz];
            return 0;
        }
            return -1;
        
    }
   
    import std.traits;
    T receive(T)( bool nonblock = false ) if (isArray!T) {
        m_errno = nng_errno.init;
        alias U=ForeachType!T;
        static assert(U.sizeof == 1, "None byte size array element are not supported");
        if(m_state == nng_socket_state.NNG_STATE_CONNECTED){
            ubyte* buf;
            size_t sz;
            const rc = nng_recv(m_socket, &buf, &sz, nonblock ? nng_flag.NNG_FLAG_NONBLOCK : 0 + nng_flag.NNG_FLAG_ALLOC );
            if (rc != 0) { 
                m_errno = cast(nng_errno)rc;
                return T.init;
            }
            GC.addRange(buf,sz);
            return (cast(U*)buf)[0..sz];
        }
        return T.init;
        
    }
    // properties Note @propery is not need anymore
    @nogc nothrow pure  {
    @property int state() const { return m_state; }
    @property int errno() const { return m_errno; }

    string name() const { return m_name; }
    
    /* You don't need to dup the string because is immutable 
        Only if you are planing to change the content in the string
@property void name(string val) { m_name = val.dup; }
        Ex:
        The function can be @nogc if you don't duplicate
*/    
    void name(string val) { m_name = val; }

    @property bool raw() const { return m_raw; }
    }

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

    @property nng_sockaddr locaddr() { return (m_may_send) ? getopt_addr(NNG_OPT_LOCADDR,"dialer") : getopt_addr(NNG_OPT_LOCADDR,"listener"); } 
    @property nng_sockaddr remaddr() { return (m_may_send) ? getopt_addr(NNG_OPT_REMADDR,"dialer") : nng_sockaddr(nng_sockaddr_family.NNG_AF_NONE); } 
}
    // Recommend the use a enum for like this
    enum Modes {
        dialer,
        listner,
        socket,
    }
    /+ And then use
    const m=Modes.dailer;
    string name=m.to!string;
    +/
    @property string url() { 
        if(m_may_send)
            return getopt_string(NNG_OPT_URL,"dialer"); 
        else if(m_may_recv)    
            return getopt_string(NNG_OPT_URL,"listener"); 
        else            
            return getopt_string(NNG_OPT_URL,"socket"); 
    }

    @property Duration maxttl() { return getopt_duration(NNG_OPT_MAXTTL); } 
    @property void maxttl(Duration val){ setopt_duration(NNG_OPT_MAXTTL,val); }
    
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
    
    string getopt_string(string opt, string base = "socket" ) { 
        m_errno = cast(nng_errno)0;
        char *ptr;
        int rc;
        switch(base){
            case "dialer":
                rc = nng_dialer_get_string(m_dialer,cast(const char*)toStringz(opt),&ptr); 
            break;
            case "listener":
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

    nng_sockaddr getopt_addr(string opt, string base = "socket" ){
        m_errno = cast(nng_errno)0;
        nng_sockaddr addr;
        int rc;
        switch(base){
            case "dialer":
                rc = nng_dialer_get_addr(m_dialer,toStringz(opt),&addr);
                break;
            case "listener":
                rc = nng_listener_get_addr(m_listener,toStringz(opt),&addr);
                break;
            case "socket":
                rc = nng_socket_get_addr(m_socket,toStringz(opt),&addr);
                break;
            default:
                rc = -1;
        }                
        if(rc == 0){ return addr; } else { m_errno = cast(nng_errno)rc; addr.s_family = nng_sockaddr_family.NNG_AF_NONE; return addr; }
    }
    
    void setopt_addr(string opt, nng_sockaddr val){
        m_errno = cast(nng_errno)0;
        auto rc = nng_socket_set_addr(m_socket,cast(const char*)toStringz(opt),&val);
        if(rc == 0){ return; }else{ m_errno = cast(nng_errno)rc; }
    }
    }
}   // struct Socket

