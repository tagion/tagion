module nngd.nngtests.test12;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.uuid;
import core.thread;
import core.thread.osthread;
import nngd;
import nngd.nngtests.suite;

const _testclass = "nngd.nngtests.nng_test12_pair";

@trusted class nng_test12_pair : NNGTest {
    
    this(Args...)(auto ref Args args) { super(args); }    

    override string[] run(){
        log("NNG test 01: pushpuli send buffer");
        this.uri = "tcp://127.0.0.1:31012";
        workers ~= new Thread(&(this.sidea_worker)).start();
        workers ~= new Thread(&(this.sideb_worker)).start();
        foreach(w; workers)
            w.join();
        log(_testclass ~ ": Bye!");
        return [];
    }
    
    void sidea_worker() @trusted  {
        const NDIALS = 32;
        int k = 0;
        string line;
        int rc;
        try{
            thread_attachThis();
            rt_moduleTlsCtor();
            log("SA: started for URL: " ~ uri);
            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PAIR);
            s.sendtimeout = msecs(1000);
            s.sendbuf = 4096;
            while(++k < NDIALS){
                log("SA: to dial...");
                rc = s.dial(uri);
                if(rc == 0) break;
                if(rc == nng_errno.NNG_ECONNREFUSED){
                    nng_sleep(msecs(100));
                    continue;
                }
                error("SA: Dial error: %s",rc);
            }
            if(s.state is nng_socket_state.NNG_STATE_CONNECTED){
                log("AA:  connected with : " ~ nng_errstr(s.errno));
            }else{
                enforce(false, "SS: connection timed out");
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
                    error("SA: Error string1: " ~ nng_errstr(s.errno));
                    continue;
                }    
                log(format("SA recv [%03d]: %s", str.length, str));
                line = "ACK!";
                rc = s.send(line);
                enforce(rc == 0);
                log(format("SA sent again [%03d]: %s",line.length,line));
                nng_sleep(msecs(200));
            }
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "Side A"));
        }    
        log(" SA: bye!");
    }


    void sideb_worker() @trusted  {
        int rc;
        try{
            thread_attachThis();
            rt_moduleTlsCtor();
            log("SB: started with URL: " ~ uri);
            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PAIR);
            s.recvtimeout = msecs(1000);
            rc = s.listen(uri);
            enforce(rc == 0);
            while(1){
                auto str1 = s.receive!string;
                if(s.errno != 0){
                    error("SB: Error string1: " ~ nng_errstr(s.errno));
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
                    error("SB: Error string2: " ~ nng_errstr(s.errno));
                    continue;
                }    
                log(format("SB rcv again [%03d]: %s", str2.length, str2));
            }
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "Side B"));
        }    
        log(" SB: bye!");
    }
    
    private:
        Thread[] workers;
        string uri;

}


