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


void sidea_worker(string url)
{
    int k = 0;
    string line;
    int rc;
    log("SA: started for URL: " ~ url);
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PAIR);
    s.sendtimeout = msecs(1000);
    s.sendbuf = 4096;
    while(1){
        log("SA: to dial...");
        rc = s.dial(url);
        if(rc == 0) break;
        log("SA: Dial error: %s",rc);
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(100));
            continue;
        }
        enforce(rc == 0);
    }
    while(1){
        line = format("%08d %s",k,randomUUID().toString());
        if(k > 9) line = "END";
        rc = s.send(line);
        enforce(rc == 0);
        log(format("SA sent [%03d]: %s",line.length,line));
        k++;
        if(k > 10) break;
        auto str = s.receive!string;
        if(s.errno != 0){
            log("SA: Error string1: " ~ nng_errstr(s.errno));
            continue;
        }    
        log(format("SA recv [%03d]: %s", str.length, str));
        line = "ACK!";
        rc = s.send(line);
        enforce(rc == 0);
        log(format("SA sent again [%03d]: %s",line.length,line));
        nng_sleep(msecs(200));
    }
    log(" SA: bye!");
}


void sideb_worker(string url)
{
    int rc;
    log("SB: started with URL: " ~ url);
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PAIR);
    s.recvtimeout = msecs(1000);
    rc = s.listen(url);
    enforce(rc == 0);
    while(1){
        auto str1 = s.receive!string;
        if(s.errno != 0){
            log("SB: Error string1: " ~ nng_errstr(s.errno));
            continue;
        }    
        log(format("SB recv [%03d]: %s", str1.length, str1));
        if(str1 == "END") 
            break;
        auto line = "PONG on " ~ str1;
        rc = s.send(line);
        enforce(rc == 0);
        log(format("SB sent bytes: %d", line.length));
        auto str2 = s.receive!string;
        if(s.errno != 0){
            log("SB: Error string2: " ~ nng_errstr(s.errno));
            continue;
        }    
        log(format("SB rcv again [%03d]: %s", str2.length, str2));
    }
    log(" SB: bye!");
}


int main()
{
    writeln("Hello NNGD!");
    writeln("Simple pair free duplex test");
    
    string uri = "tcp://127.0.0.1:31200";


    auto tid01 = spawn(&sidea_worker, uri);
    auto tid02 = spawn(&sideb_worker, uri);
    thread_joinAll();
    
    writeln("Bye!");
    return 0;
}

