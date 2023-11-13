import core.thread;
import std.algorithm;
import std.concurrency;
import std.conv;
import std.datetime.systime;
import std.exception;
import std.file;
import std.random;
import std.regex;
import std.stdio;
import std.string;
import std.uuid;
import std.base64;

import nngd;
import nngtestutil;

string rndstr(size_t len = 32){
    string s, buf;
    do {
        buf = cast(string)(Base64.encode(cast(const(ubyte)[])"/dev/urandom".read(512)));
        s ~= buf[0..(min(buf.length,len-s.length))];
    }while(s.length < len);
    return s[0..len];
}



struct worker_context {
    int id;
    string name;
}

// REP
void server_callback(NNGMessage *msg, void *ctx)
{
    log("SERVER CALLBACK");
    if(msg is null){ 
        log("No message received");
        return;
    }    
    if(msg.length < 1){
        log("Empty message received");
        return;
    }
    auto cnt = cast(worker_context*)ctx;
    auto s = msg.body_trim!string();
    log("SERVER CONTEXT NAME: "~cnt.name);
    log("SERVER GOT: " ~ s[0..min(s.length,48)]);
    msg.clear();
    if(indexOf(s,"What time is it?") == 0){
        log("Going to send time");
        msg.body_append(cast(ubyte[])(format("It`s %f o`clock." ~ " DATA: ",timestamp()) ~ rndstr(uniform(4096,32768))));
    }else if(indexOf(s,"Swamp me!") == 0){    
        size_t bsz = 1048576;
        string buf = rndstr(bsz);
        msg.length = bsz + 32;
        msg.body_prepend(cast(ubyte[])("BIG DATA: " ~ buf));
        log("SERVER: BData set");
    }else{
        log("Going to stop sender");
        msg.body_append(cast(ubyte[])"END");
    }
}


// REQ
void client_worker(string url, string tag)
{
    int rc;
    string line, str;
    int k = 0;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    s.recvtimeout = msecs(5000);
    while(1){
        log("REQ("~tag~"): to dial...");
        rc = s.dial(url);
        if(rc == 0) break;
        log("REQ("~tag~"): Dial error: ",toString(rc));
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(10));
            continue;
        }
        enforce(rc == 0);
    }
    while(1){
        k++;
        if(k > 255){
            line = "Maybe that's enough?";
        } else if(k % 16 == 0) {
            line = "Swamp me!";
        } else {    
            line = format("What time is it? :: from(%s)[%d]", tag,k);            
        }    
        auto pl = rndstr(uniform(4096,32768));    
        rc = s.send!string(line~" DATA: "~pl);
        enforce(rc == 0);
        log("REQ("~tag~"): SENT: " ~ line[0..min(line.length,48)]);
        str = s.receive!string();
        if(s.errno == 0){
            log(format("REQ("~tag~") RECV [%03d]: %s", str.length, str[0..min(str.length,48)]));
        }else{
            log("REQ("~tag~"): Error string: " ~ toString(s.errno));
        }    
        if(str == "END")
            break;
    }
    s.close();
    log("REQ("~tag~"): bye!");
}


int main()
{
    writeln("Hello NNGD!");
    writeln("Pool req-rep test in async mode");

    string uri = "tcp://127.0.0.1:31200";
    immutable string[] tags = ["TAG0", "TAG1", "TAG2", "TAG3"];

    worker_context ctx;
    ctx.id = 1;
    ctx.name = "Context name";

    
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REP);
    s.sendtimeout = msecs(5000);
    s.recvtimeout = msecs(5000);
    s.sendbuf = 65536;

    NNGPool pool = NNGPool(&s, &server_callback, 8, &ctx);
    pool.init();

    auto rc = s.listen(uri);
    enforce(rc == 0);


    auto tid02 = spawn(&client_worker, uri, tags[0]);      // client for exact tag
    auto tid03 = spawn(&client_worker, uri, tags[1]);      // ...
    auto tid04 = spawn(&client_worker, uri, tags[2]);
    auto tid05 = spawn(&client_worker, uri, tags[3]);
    thread_joinAll();
    log("PLANNING SHUTDOWN");
    pool.shutdown();

    writeln("Bye!");

    return 0;
}
