module nngd.nngtests.test05;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.conv;
import std.regex;
import core.thread;
import core.thread.osthread;
import nngd;
import nngd.nngtests.suite;

const _testclass = "nngd.nngtests.nng_test05_reqrep";

@trusted class nng_test05_reqrep : NNGTest {
    
    this(Args...)(auto ref Args args) { super(args); }    

    override string[] run(){
        log("NNG test 05: request-reply");
        this.uri = "tcp://127.0.0.1:31005";
        immutable string[] tags = ["TAG0", "TAG1", "TAG2", "TAG3"];
        workers ~= new Thread(&(this.server_worker)).start();
        foreach(t; tags){
            this.tag = t;
            workers ~= new Thread(&(this.client_worker)).start();
        }            
        foreach(w; workers)
            w.join();
        log(_testclass ~ ": Bye!");
        return [];
    }
    
    void server_worker() @trusted {
        const NTAGS = 4;
        const NMSGS = 31;
        auto ctr = regex(r" ([0-9]+)$");
        uint k = 0, p=0;
        int rc;
        try{
            thread_attachThis();
            rt_moduleTlsCtor();
            log("REP: Listening at " ~ uri);
            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REP);
            s.sendtimeout = msecs(1000);
            s.recvtimeout = msecs(1000);
            s.sendbuf = 4096;
            rc = s.listen(uri);
            enforce(rc == 0);
            while( p < NTAGS ){
                auto line = s.receive!string();
                if(s.errno != 0){
                    error("REP: RECV ERROR: " ~ nng_errstr(s.errno));
                    continue;
                }
                k++;
                log("REP: RECV: " ~ line);
                auto rres = matchFirst(line, ctr);
                line = format("REPLY(%d) = %s",k,line);
                if(!rres.empty){
                    auto i = to!int(rres[1]);
                    if(i>NMSGS){
                        line = "END";
                        p++;
                    }
                }
                rc = s.send!string(line);
                if(rc != 0){
                    error("REP: SEND ERROR: " ~ nng_errstr(rc));
                }else{
                    log("REP: SENT: " ~ line);
                }
            }
            log("REP: bye!");
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "SS: Sender worker"));
        }
    }

    void client_worker() @trusted {
        const NDIALS = 32;
        uint k = 0;
        int rc;
        bool _ok = false;
        string tag = this.tag.dup;
        Thread.sleep(msecs(10));
        try{
            thread_attachThis();
            rt_moduleTlsCtor();
            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
            s.recvtimeout = msecs(1000);
            while(++k < NDIALS){
                log("REQ("~tag~"): to dial...");
                rc = s.dial(uri);
                if(rc == 0) 
                    break;
                if(rc == nng_errno.NNG_ECONNREFUSED){
                    nng_sleep(msecs(100));
                    continue;
                }
                error("REQ("~tag~"): Dial error: ",nng_errstr(rc));
                enforce(rc == 0);
            }
            if(s.state is nng_socket_state.NNG_STATE_CONNECTED){
                log("REQ: connected with : " ~ nng_errstr(s.errno));
            }else{
                enforce(false, "SS: connection timed out");
            }
            k = 0;
            while(true){
                k++;
                auto line = format("Client(%s) request %d", tag, k);            
                rc = s.send!string(line);
                enforce(rc == 0);
                log("REQ("~tag~"): SENT: " ~ line);
                auto str = s.receive!string();
                if(s.errno == 0){
                    log(format("REQ("~tag~") RECV [%03d]: %s", str.length, str));
                }else{
                    error("REQ("~tag~"): Error string: " ~ nng_errstr(s.errno));
                }    
                if(str == "END"){
                    _ok = true;
                    break;
                }            
            }
            if(!_ok){
                error("Test stopped without normal end.");
            }        
            log("REQ("~tag~"): bye!");
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "RR: Receiver worker"));
        }
    }
    
    private:
        Thread[] workers;
        string uri;
        string tag;

}


