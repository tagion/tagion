import core.thread;
import nngd;
import nngtestutil;
import std.concurrency;
import std.conv;
import std.datetime.systime;
import std.exception;
import std.stdio;
import std.string;


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
        log("SS: Dial error: %s",rc);
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(100));
            continue;
        }
        enforce(rc == 0);
    }
    log(nngtest_socket_properties(s,"sender"));
    while(1){
        line = format(">MSG:%d DBL:%d TRL:%d<",k,k*2,k*3);
        if(k > 9) line = "END";
        rc = s.send!string(line);
        enforce(rc == 0);
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
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
    s.recvtimeout = msecs(1000);
    rc = s.listen(url);
    log("RR: listening");
    enforce(rc == 0);
    log(nngtest_socket_properties(s,"receiver"));
    while(1){
        log("RR to receive");
        log("RR: debug state: ",s.state, " errno: ", s.errno);
        auto str = s.receive!string();
        log("RR: debug state: ",s.state, s.errno);
        if(s.errno == 0){
            log("RR: GOT["~(to!string(str.length))~"]: >"~str~"<");
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
    writeln("Simple push-pull test with byte buffers");

    string uri = "tcp://127.0.0.1:31200";

    auto tid01 = spawn(&receiver_worker, uri);
    auto tid02 = spawn(&sender_worker, uri);
    thread_joinAll();

    return 0;
}
