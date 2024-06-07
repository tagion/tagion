import core.thread;
import libnng;
import std.concurrency;
import std.conv;
import std.datetime.systime;
import std.stdio;
import std.string;


static double timestamp()
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static void log(A...)(A a){
    writeln(format("%.6f ",timestamp),a);
}


// [1] #begin push-pull test 

void test1_sender( string url ){
    nng_socket sock;
    nng_sockaddr sa;
    string s;
    int rc;
    rc = nng_push0_open(&sock);
    assert(rc == 0);
    log( " SS: created");
    rc = nng_socket_set_ms(sock,toStringz(NNG_OPT_SENDTIMEO),1000);
    assert(rc == 0);
    rc = nng_socket_set_int(sock,toStringz(NNG_OPT_SENDBUF),4096);
    assert(rc == 0);
    log( " SS: dialing");
    while(1){
    rc = nng_dial(sock, toStringz(url), null, 0);
        if(rc != 0){
            if(rc == nng_errno.NNG_ECONNREFUSED || rc == nng_errno.NNG_EAGAIN){
                log("SS: retry");
                continue;
            }
        }
        break;
    }
    assert(rc == 0);
    log( " SS: connected");
    int k = 0;
    while(k < 10){
        s = (k==0) ? "<START>" : ((k==9) ? "<END>" : format(">MSG:%d DBL:%d TRL:%d<",k,k*2,k*3));
        auto buf = cast(ubyte[])s.dup;
        rc = nng_send(sock, ptr(buf), s.length+1, 0);
        log("SS sent: ",k," : ",s);
        k++;
        nng_msleep(500);
    }
    log(" SS: bye!");
}

void test1_receiver( string url ){
    nng_socket sock;
    ubyte[4096] buf;
    size_t sz;
    foreach(i;0..4095) buf[i] = 0;
    auto rc = nng_pull0_open(&sock);
    assert(rc == 0);
    log( " RR: created");
    rc = nng_listen(sock, toStringz(url), null, 0);
    assert(rc == 0);
    rc = nng_socket_set_ms(sock,toStringz(NNG_OPT_RECVTIMEO),1000);
    assert(rc == 0);
    log( " RR: listen");
    while(1){
        sz = 4096;
        rc = nng_recv(sock, ptr(buf), &sz, 0);
        if(rc != 0){
            if(rc == nng_errno.NNG_ETIMEDOUT){
                log( " RR: waiting");
                continue;
            }
            if(rc == nng_errno.NNG_EAGAIN){
                log( " RR: interrupted");
                continue;
            }
        }
        assert(rc == 0);
        log( " RR: got bytes:",sz);
        auto s = cast(string)buf[0..sz-1];
        log( " RR: received: ", s);
        if(s == "<END>") break;
    }
    log( " RR: bye!");
}


// [1] #end push-pull test 


int main()
{
    writeln("Hello LIBNNG!");
    
    string[3] transports = ["tcp://127.0.0.1:31200", "ipc:///tmp/testnng.ipc", "inproc://testnng"];

    writeln("// ERROR TEST");
    for(auto i=1; i<32; i++ ){
        writeln("ERROR: ",i,"  =  ",nng_errstr(i));
    }

    // -- [1] push-pull test
        writeln("\n<TEST01>");
        foreach(uri; transports){
            writeln("TEST01 -------------------- simple push-pull on " ~ uri);
            auto tid01 = spawn(&test1_sender, uri);
            auto tid02 = spawn(&test1_receiver, uri);
            //nng_msleep(50);
            //nng_msleep(2000);
            thread_joinAll();
        }
        writeln("</TEST01>\n");
        


    return 0;
}
