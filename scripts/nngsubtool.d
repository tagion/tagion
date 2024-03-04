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

void sub_worker(string url, string tag)
{
    int rc;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
    s.recvtimeout = msecs(1000);
    s.subscribe(tag);
    enforce(rc == 0);
    while(1){
        rc = s.dial(url);
        if(rc == 0) break;
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(100));
            continue;
        }
        enforce(rc == 0);
    }
    while(1){
        auto str = s.receive!string;
        if(s.errno == 0){
            writeln(str);
        }else{
            writeln("SUB(%s): Error string: %s", tag,s.errno);
        }                
    }
    writeln("SUB("~tag~"): bye!");
}


int main(string[] argv)
{
    if(argv.length < 2){
        writeln("Usage: %s <uri> [subscribe]");
        return 1;
    }           

    auto tid = spawn(&sub_worker, argv[1], (argv.length > 2)?argv[2]:"");
    
    thread_joinAll();

    return 0;
}

