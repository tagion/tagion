import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;

import nngd;
import nngtestutil;

static double timestamp()
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static void log(A...)(string fmt, A a){
    writefln("%.6f "~fmt,timestamp,a);
}

void sender_worker(string url)
{
    int k = 0;
    string line;
    int rc;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
    s.sendtimeout = msecs(1000);
    s.sendbuf = 4096;
    while(1){
        log("SS: to dial...");
        rc = s.dial(url);
        if(rc == 0) break;
        log("SS: Dial error: %s", rc);
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(100));
            continue;
        }
        assert(rc == 0);
    }
    log(nngtest_socket_properties(s,"sender"));
    while(1){
        line = format(">MSG:%d DBL:%d TRL:%d<",k,k*2,k*3);
        if(k > 9) line = "END";
        auto buf = cast(ubyte[])line.dup;
        rc = s.send!(ubyte[])(buf);
        assert(rc == 0);
        log("SS sent: ",k," : ",line);
        k++;
        nng_sleep(msecs(500));
        if(k > 10) break;
    }
    log(" SS: bye!");
}


void receiver_worker(string url)
{
    int rc;
    ubyte[4096] buf;
    size_t sz = buf.length;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
    s.recvtimeout = msecs(1000);
    rc = s.listen(url);
    log("RR: listening");
    assert(rc == 0);
    log(nngtest_socket_properties(s,"receiver"));
    while(1){
        sz = s._receive(buf, buf.length);
        if(sz < 0){
            log("REcv error: " ~ toString(s.m_errno));
            continue;
        }
        auto str = cast(string)buf[0..sz];
        log("RR: GOT["~(to!string(sz))~"]: >"~str~"<");
        writeln(str);
        if(str == "END") 
            break;
    }
    log(" RR: bye!");
}


int main()
{
    
    writeln("Hello NNGD!");
    writeln("Simple push-pull test with byte buffers");

    string uri = "tcp://127.0.0.1:31200";

    auto tid01 = spawn(&receiver_worker, uri);
    auto tid02 = spawn(&sender_worker, uri);
    thread_joinAll();

    return 0;
}

