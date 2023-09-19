import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.regex;

import nngd;
import nngtestutil;


// REP
void server_callback(NNGMessage *msg)
{
    log("SERVER CALLBACK");
    auto s = msg.body_trim!string(msg.length);
    log("SERVER GOT: " ~ s);
    msg.clear();
    if(indexOf(s,"What time is it?") == 0){
        log("Going to send time");
        msg.body_append(cast(ubyte[])format("It`s %f o`clock.",timestamp()));
    }else{
        log("Going to stop sender");
        msg.body_append(cast(ubyte[])"END");
    }
}


// REQ
void client_worker(string url, string tag)
{
    int rc;
    string line;
    int k = 0;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    s.recvtimeout = msecs(1000);
    while(1){
        log("REQ("~tag~"): to dial...");
        rc = s.dial(url);
        if(rc == 0) break;
        log("REQ("~tag~"): Dial error: ",toString(rc));
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(100));
            continue;
        }
        assert(rc == 0);
    }
    while(1){
        k++;
        line = format("What time is it? :: from(%s)[%d]", tag,k);            
        if(k > 16)
            line = "Maybe that's enough?";
        rc = s.send!string(line);
        assert(rc == 0);
        log("REQ("~tag~"): SENT: " ~ line);
        auto str = s.receive!string();
        if(s.errno == 0){
            log(format("REQ("~tag~") RECV [%03d]: %s", str.length, str));
        }else{
            log("REQ("~tag~"): Error string: " ~ toString(s.errno));
        }    
        if(str == "END")
            break;
    }
    log("REQ("~tag~"): bye!");
}


int main()
{
    writeln("Hello NNGD!");
    writeln("Pool req-rep test in async mode");

    string uri = "tcp://127.0.0.1:31200";
    immutable string[] tags = ["TAG0", "TAG1", "TAG2", "TAG3"];

    
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REP);
    s.sendtimeout = msecs(1000);
    s.recvtimeout = msecs(1000);
    s.sendbuf = 4096;

    NNGPool pool = NNGPool(&s, &server_callback, 4);
    pool.init();

    auto rc = s.listen(uri);
    assert(rc == 0);


    auto tid02 = spawn(&client_worker, uri, tags[0]);      // client for exact tag
    auto tid03 = spawn(&client_worker, uri, tags[1]);      // ...
    auto tid04 = spawn(&client_worker, uri, tags[2]);
    auto tid05 = spawn(&client_worker, uri, tags[3]);
    thread_joinAll();

    pool.shutdown();

    writeln("Bye!");

    return 0;
}

