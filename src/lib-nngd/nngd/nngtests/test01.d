module nngd.nngtests.test01;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import core.thread;
import core.thread.osthread;
import nngd;

const _testclass = "nngd.nngtests.nng_test01_pushpull_buffer";

@trusted class nng_test01_pushpull_buffer : NNGTest {
    
    this(Args...)(auto ref Args args) { super(args); }    

    override string[] run(){
        log("NNG test 01: pushpuli send buffer");
        this.uri = "tcp://127.0.0.1:31000";
        workers ~= new Thread(&(this.receiver_worker)).start();
        workers ~= new Thread(&(this.sender_worker)).start();
        foreach(w; workers)
            w.join();
        return [];
    }
    

    void sender_worker() @trusted {
        const NDIALS = 32;
        const NMSGS = 32;
        uint k = 0;
        int rc;
        try{
            thread_attachThis();
            rt_moduleTlsCtor();
            log("SS: Conncting to " ~ uri);
            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
            s.sendtimeout = msecs(1000);
            s.sendbuf = 4096;
            while( ++k < NDIALS ){
                rc = s.dial(uri);
                if(rc == 0) break;
                if(rc == nng_errno.NNG_ECONNREFUSED){
                    log("SS: Connection refused attempt %d", k);
                    nng_sleep(msecs(100));
                    continue;
                }
                error("SS: Dial error after %d attempts: %d", NDIALS, rc);
                enforce(rc == 0);
            }
            if(s.state is nng_socket_state.NNG_STATE_CONNECTED){
                log("SS:  connected with : " ~ nng_errstr(s.errno));
            }else{
                enforce(false, "SS: connection timed out");
            }
            k = 0;
            while(++k < NMSGS){
                auto line = format(`{"msg": %d, "check": %d, "time": %f}`,
                    k, mkrot3(k), timestamp());
                log(line);   
                auto sbuf = cast(ubyte[])line.dup;
                rc = s.send!(ubyte[])(sbuf);
                enforce(rc == 0);
                log("SS: sent: " ~ line);
                nng_sleep(msecs(100));
            }
            nng_sleep(msecs(100));
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "SS: Sender worker"));
        }
    }

    void receiver_worker() @trusted {
        const NDIALS = 32;
        const NMSGS = 32;
        const BSIZE = 4096;
        ubyte[BSIZE] rbuf; 
        uint k = 0;
        int rc;
        size_t sz = rbuf.length;
        try{
            thread_attachThis();
            rt_moduleTlsCtor();
            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
            s.recvtimeout = msecs(1000);
            rc = s.listen(uri);
            enforce(rc == 0, "RR: Error listening socket");
            while(1){
                sz = s.receivebuf(rbuf, rbuf.length);
                if(sz < 0 || sz == size_t.max){
                    error("REcv error: " ~ nng_errstr(s.errno));
                    continue;
                }
                auto line = cast(string)rbuf[0..sz];
                log("RR: received: " ~ line);
                auto jdata = parseJSON(line);
                k = cast(uint)(jdata["msg"].integer);
                auto c = cast(uint)(jdata["check"].integer);
                if(!chkrot3(k,c)){
                    error("Invalid message data: " ~ line);
                    continue;
                }
                if(k >= NMSGS-1)
                    break;
            }
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "RR: Receiver worker"));
        }
    }
    
    private:
        Thread[] workers;
        string uri;

}




