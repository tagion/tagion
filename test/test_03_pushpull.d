import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;

import nngd;
import nngtestutil;

static double timestamp()
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static void log(A...)(string fmt, A a){
    writefln("%.6f ",timestamp,a);
}

void sender_worker(string url)
{
    int k = 0;
    string line;
    int rc;
    log("SS: started for URL: " ~ url);
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
    s.sendtimeout = msecs(1000);
    s.sendbuf = 4096;
    while(1){
        log("SS: to dial...");
        rc = s.dial(url);
        if(rc == 0) break;
        log("SS: Dial error: %s",rc);
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(100));
            continue;
        }
        assert(rc == 0);
    }
    log(nngtest_socket_properties(s,"sender"));
    while(1){
        line = format("%08d %s",k,randomUUID().toString());
        if(k > 9) line = "END";
        rc = s.send_string(line);
        assert(rc == 0);
        log(format("SS sent [%03d]: %s",line.length,line));
        k++;
        nng_sleep(msecs(200));
        if(k > 10) break;
    }
    log(" SS: bye!");
}


void receiver_worker(string url)
{
    int rc;
    log("RR: started with URL: " ~ url);
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
    s.recvtimeout = msecs(1000);
    rc = s.listen(url);
    assert(rc == 0);
    log(nngtest_socket_properties(s,"receiver"));
    while(1){
        auto str = s.receive_string();
        if(s.errno == 0){
            log(format("RR recv [%03d]: %s", str.length, str));
            if(str == "END") 
                break;
        }else{
            log("RR: Error string");
        }                
    }
    log(" RR: bye!");
}


int main()
{
    writeln("Hello NNGD!");
    writeln("Simple push-pull test with all transports");
    
    string[3] transports = ["tcp://127.0.0.1:31200", "ipc:///tmp/testnng.ipc", "inproc://testnng"];

    foreach(uri; transports){
        writeln("\n\n-------------------- simple push-pull with URL: " ~ uri);
        auto tid01 = spawn(&receiver_worker, uri);
        auto tid02 = spawn(&sender_worker, uri);
        thread_joinAll();
        writeln("-------------------- end test");
    }        
    writeln("Bye!");
    return 0;
}

