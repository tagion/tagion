import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.random;

import nngd;
import nngtestutil;

static double timestamp()
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static void log(A...)(string fmt, A a){
    writefln("%.6f "~fmt,timestamp,a); stdout.flush();
}

void pub_worker(string url, const string[] tags)
{
    int k = 0;
    string line;
    int rc;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUB);
    s.sendtimeout = msecs(1000);
    s.sendbuf = 4096;
    log("PUB: listening");
    rc = s.listen(url);
    assert(rc == 0);
    log(nngtest_socket_properties(s,"PUB"));
    auto rnd = Random(42);
    while(1){
        line = format("%s %08d %s",tags.choice(rnd),k,randomUUID().toString());
        if(k > 31) {
            foreach(tag; tags){
                line = tag ~ " END";
                rc = s.send(line);
                assert(rc == 0);
                log("PUB sent: ",k," : ",line);
            }
            break;
        }
        rc = s.send(line);
        assert(rc == 0);
        log("PUB sent: ",k," : ",line);
        k++;
        nng_sleep(msecs(500));
    }
    log("PUB: bye!");
}

void sub_worker(string url, string tag)
{
    int rc;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
    s.recvtimeout = msecs(1000);
    s.subscribe(tag);
    assert(rc == 0);
    log("SUB("~tag~"): subscribed to " ~ tag);
    while(1){
        log("SUB("~tag~"): to dial...");
        rc = s.dial(url);
        if(rc == 0) break;
        log("SUB(%s): Dial error: %s", tag, rc);
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(100));
            continue;
        }
        assert(rc == 0);
    }
    log(nngtest_socket_properties(s,"SUB("~tag~")"));
    log("%s",s.subscriptions());
    while(1){
        log("SUB("~tag~"): to receive");
        auto str = s.receive_string();
        if(s.errno == 0){
            log(format("SUB("~tag~") recv [%03d]: %s", str.length, str));
            if(str[$-3..$] == "END") 
                break;
        }else{
            log("SUB(%s): Error string: %s", tag,s.errno);
        }                
    }
    log("SUB("~tag~"): bye!");
}


int main()
{
    writeln("Hello NNGD!");
    writeln("Simple pub-sub test with post-allocated strings");

    string uri = "tcp://127.0.0.1:31200";
    immutable string[] tags = ["TAG0", "TAG1", "TAG2", "TAG3"];

    auto tid01 = spawn(&pub_worker, uri, tags);         // pub for random tag publish
    auto tid02 = spawn(&sub_worker, uri, tags[0]);      // sub for exact tag
    auto tid03 = spawn(&sub_worker, uri, tags[1]);      // ...
    auto tid04 = spawn(&sub_worker, uri, tags[2]);
    auto tid05 = spawn(&sub_worker, uri, tags[3]);
//    auto tid06 = spawn(&sub_worker, uri, "");           // sub for all tags
    thread_joinAll();

    return 0;
}

