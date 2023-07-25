import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;

import nngd;

static double timestamp()
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static void log(A...)(A a){
    writeln(format("%.6f ",timestamp),a);
}

void sender_worker(string url)
{
    int k = 0;
    string line;
    int rc;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
    s.sendtimeout = msecs(1000);
    s.sendbuf = 4096;
    log("SS: dialing");
    rc = s.dial(url);
log("SS: PROPERTIES -----------------------------\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = name: ", s.name,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = raw: ", s.raw,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = proto: ", s.proto,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = protoname: ", s.protoname,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = peer: ", s.peer,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = peername: ", s.peername,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = recvbuf: ", s.recvbuf,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = sendbuf: ", s.sendbuf,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = recvfd: ", s.recvfd,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = sendfd: ", s.sendfd,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = recvtimeout: ", s.recvtimeout,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = sendtimeout: ", s.sendtimeout,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = locaddr: ", toString(s.locaddr),"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = remaddr: ", toString(s.remaddr),"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = url: ", s.url,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = maxttl: ", s.maxttl,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = recvmaxsz: ", s.recvmaxsz,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = reconnmint: ", s.reconnmint,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = reconnmaxt: ", s.reconnmaxt,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"SS: /PROPERTIES -----------------------------\n");
    assert(rc == 0);
    while(1){
        line = format(">MSG:%d DBL:%d TRL:%d<",k,k*2,k*3);
        if(k > 9) line = "END";
        rc = s.send_string(line);
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
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
    s.recvtimeout = msecs(1000);
    rc = s.listen(url);
    log("RR: listening");
log("RR: PROPERTIES -----------------------------\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = name: ", s.name,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = raw: ", s.raw,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = proto: ", s.proto,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = protoname: ", s.protoname,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = peer: ", s.peer,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = peername: ", s.peername,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = recvbuf: ", s.recvbuf,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = sendbuf: ", s.sendbuf,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = recvfd: ", s.recvfd,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = sendfd: ", s.sendfd,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = recvtimeout: ", s.recvtimeout,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = sendtimeout: ", s.sendtimeout,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = locaddr: ", toString(s.locaddr),"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = remaddr: ", toString(s.remaddr),"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = url: ", s.url,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = maxttl: ", s.maxttl,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = recvmaxsz: ", s.recvmaxsz,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = reconnmint: ", s.reconnmint,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"\t = reconnmaxt: ", s.reconnmaxt,"\n"
,"\t\t = state: ", s.state," errno: ", s.errno,"\n"
,"RR: /PROPERTIES -----------------------------\n");
    assert(rc == 0);
    while(1){
        log("RR to receive");
        log("RR: debug state: ",s.state, " errno: ", s.errno);
        auto str = s.receive_string();
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

