import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.random;
import std.exception;

import nngd;
import nngtestutil;

const NSTEPS = 32;

void pub_worker(string url, const string[] tags)
{
    int k = 0;
    string line;
    int rc;
    thread_attachThis();
    rt_moduleTlsCtor();
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUB);
    s.sendtimeout = msecs(1000);
    s.sendbuf = 4096;
    log("PUB: listening");
    rc = s.listen(url);
    enforce(rc == 0);
    log(nngtest_socket_properties(s,"PUB"));
    auto rnd = Random(42);
    while(1){
        line = format("%s %08d %s",tags.choice(rnd),k,randomUUID().toString());
        if(k >= NSTEPS) {
            foreach(tag; tags){
                line = tag ~ " END";
                rc = s.send(line);
                enforce(rc == 0);
                log("PUB sent: ",k," : ",line);
            }
            break;
        }
        rc = s.send(line);
        enforce(rc == 0);
        log("PUB sent: ",k," : ",line);
        k++;
        nng_sleep(msecs(200));
    }
    log("PUB: bye!");
}

void sub_worker(string url, string tag)
{
    int rc;
    thread_attachThis();
    rt_moduleTlsCtor();
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
    s.recvtimeout = msecs(6000);
    s.subscribe(tag);
    enforce(rc == 0);
    log("SUB("~tag~"): subscribed to " ~ tag);
    int k = 0;
    bool _ok = false;
    while(1){
        if(k++ > NSTEPS + 4) break;
        log("SUB("~tag~"): to dial...");
        rc = s.dial(url);
        if(rc == 0) {
            _ok = true;
            break;
        }    
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(100));
            continue;
        }            
        error("SUB(%s): Dial error: %s", tag, rc);
        enforce(rc == 0);
    }
    if(!_ok){
        error("SUB("~tag~"): couldn`t dial");
        return;
    }
    log(nngtest_socket_properties(s,"SUB("~tag~")"));
    log("%s",s.subscriptions());
    k = 0;
    _ok = false;
    while(1){
        if(k++ > NSTEPS + 12) break;
        log("SUB("~tag~"): to receive");
        auto str = s.receive!string;
        if(s.errno == 0){
            log(format("SUB("~tag~") recv [%03d]: %s", str.length, str));
            if(str[$-3..$] == "END"){
                log("SUB("~tag~"): to stop");
                _ok = true;
                break;
            }                
        }else{
            error("SUB(%s): Error string: %s", tag,s.errno);
        }                
    }
    if(!_ok){
        error("Test stopped without normal end.");
    }    
    log("SUB("~tag~"): bye!");
}


int main()
{
    log("Hello NNGD!");
    log("Simple pub-sub test with post-allocated strings");

    string uri = "tcp://127.0.0.1:31200";
    immutable string[] tags = ["TAG0", "TAG1", "TAG2", "TAG3"];

    auto tid01 = spawn(&pub_worker, uri, tags);         // pub for random tag publish
    auto tid02 = spawn(&sub_worker, uri, tags[0]);      // sub for exact tag
    auto tid03 = spawn(&sub_worker, uri, tags[1]);      // ...
    auto tid04 = spawn(&sub_worker, uri, tags[2]);
    auto tid05 = spawn(&sub_worker, uri, tags[3]);
//    auto tid06 = spawn(&sub_worker, uri, "");           // sub for all tags
    thread_joinAll();

    return populate_state(4, "simple pub-sub socket");
}

