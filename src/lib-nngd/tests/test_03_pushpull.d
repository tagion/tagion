import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.exception;

import nngd;
import nngtestutil;


const NSTEPS = 9;

void sender_worker(string url)
{
    int k = 0;
    string line;
    int rc;
    thread_attachThis();
    rt_moduleTlsCtor();
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
        enforce(rc == 0);
    }
    log(nngtest_socket_properties(s,"sender"));
    while(1){
        line = format("%08d %s",k,randomUUID().toString());
        if(k > NSTEPS) line = "END";
        rc = s.send(line);
        enforce(rc == 0);
        log(format("SS sent [%03d]: %s",line.length,line));
        k++;
        nng_sleep(msecs(200));
        if(k > NSTEPS+1) break;
    }
    log(" SS: bye!");
}


void receiver_worker(string url)
{
    int rc;
    thread_attachThis();
    rt_moduleTlsCtor();
    log("RR: started with URL: " ~ url);
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
    s.recvtimeout = msecs(1000);
    rc = s.listen(url);
    enforce(rc == 0);
    log(nngtest_socket_properties(s,"receiver"));
    int k = 0;
    bool _ok = false;
    while(1){
        if(k++ > NSTEPS + 3) break;
        auto str = s.receive!string;
        if(s.errno == 0){
            log(format("RR recv [%03d]: %s", str.length, str));
            if(str == "END"){
                _ok = true;
                break;
            }                
        }else{
            error("RR: Error string");
        }                
    }
    if(!_ok){
        error("Test stopped without normal end.");
    }    
    log(" RR: bye!");
}


int main()
{
    log("Hello NNGD!");
    log("Simple push-pull test with all transports");
    
    string[3] transports = ["tcp://127.0.0.1:31200", "ipc:///tmp/testnng.ipc", "inproc://testnng"];
    
    int _res = 0;

    foreach(uri; transports){
        log("\n\n-------------------- simple push-pull with URL: " ~ uri);
        auto tid01 = spawn(&receiver_worker, uri);
        auto tid02 = spawn(&sender_worker, uri);
        thread_joinAll();
        log("-------------------- end test");
        _res += populate_state(3, "transport test: push-pull with URL: " ~ uri);
    }        
    log("Bye!");
    return _res;
}

