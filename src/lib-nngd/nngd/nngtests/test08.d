module nngd.nngtests.test08;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.conv;
import std.datetime.systime;
import std.uuid;
import std.regex;
import std.algorithm;
import std.random;
import std.string;
import std.file;
import std.base64;
import core.thread;
import core.thread.osthread;
import nngd;

const _testclass = "nngd.nngtests.nng_test08_pool";

string rndstr(size_t len = 32) @trusted {
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
    void* cptr;
}


@trusted class nng_test08_pool : NNGTest {
    
    this(Args...)(auto ref Args args) { super(args); }    

    override string[] run(){
        log("NNG test 08: nng worker pool");
        this.uri = "tcp://127.0.0.1:31008";
        immutable string[] tags = ["TAG0", "TAG1", "TAG2", "TAG3"];
        try{ 
            auto self_ = self;

            worker_context ctx;
            ctx.id = 1;
            ctx.name = "Context name";
            ctx.cptr = &self_;
            
            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REP);
            s.sendtimeout = msecs(5000);
            s.recvtimeout = msecs(5000);
            s.sendbuf = 65536;

            NNGPool pool = NNGPool(&s, &this.server_callback, 8, &ctx, this.logfile.fileno());
            pool.init();

            auto rc = s.listen(uri);
            enforce(rc == 0);

            foreach(t; tags){
                this.tag = t;
                workers ~= new Thread(&(this.client_worker)).start();
                Thread.sleep(msecs(100));
            }
            foreach(w; workers)
                w.join();
            log("PLANNING SHUTDOWN");
            pool.shutdown();
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "Main: " ~ _testclass));
        }
        log(_testclass ~ ": Bye!");
        log("Passed!");
        return [];
    }
    
    
    private:
        
        Thread[] workers;
        string uri;
        string tag;

        static void server_callback(NNGMessage *msg, void *ctx) @trusted
        {
            try{
                auto cnt = cast(worker_context*)ctx;
                auto obj = cast(nng_test08_pool*)cnt.cptr;

                obj.log("SERVER CALLBACK");
                if(msg is null){ 
                    obj.log("No message received");
                    return;
                }    
                if(msg.length < 1){
                    obj.log("Empty message received");
                    return;
                }
                auto s = msg.body_trim!string();
                obj.log("SERVER CONTEXT NAME: "~cnt.name);
                obj.log("SERVER GOT: " ~ s[0..min(s.length,48)]);
                msg.clear();
                if(indexOf(s,"What time is it?") == 0){
                    obj.log("Going to send time");
                    msg.body_append(cast(ubyte[])(format("It`s %f o`clock." ~ " DATA: ",timestamp()) ~ rndstr(uniform(4096,32768))));
                }else if(indexOf(s,"Swamp me!") == 0){    
                    size_t bsz = 1048576;
                    string buf = rndstr(bsz);
                    msg.length = bsz + 32;
                    msg.body_prepend(cast(ubyte[])("BIG DATA: " ~ buf));
                    obj.log("SERVER: BData set");
                }else if(indexOf(s,"Break!") == 0){
                    obj.log("SERVER: Let's fool around!");
                    obj.log("Error condition emulated!");
                }else{
                    obj.log("Going to stop sender");
                    msg.body_append(cast(ubyte[])"END");
                }
            } catch(Throwable e) {
                nngtest_error(dump_exception_recursive(e, "Server callback"));
            }    
        }

        // REQ
        void client_worker() @trusted
        {
            const NDIALS = 32;
            const NMSGS = 32;
            try{
                int rc;
                string line, str;
                int k = 0;
                NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
                s.recvtimeout = msecs(5000);
                while( ++k < NDIALS ){
                    log("REQ("~tag~"): to dial...");
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
                while(true){
                    k++;
                    if(k > NMSGS){
                        line = "Maybe that's enough?";
                    } else if(k % 16 == 0) {
                        line = "Swamp me!";
                    } else if(k % 21 == 0) {
                        line = "Break!";
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
                        log("REQ("~tag~"): Error string: " ~ nng_errstr(s.errno));
                    }    
                    if(str == "END")
                        break;
                }
                s.close();
                log("REQ("~tag~"): bye!");
            } catch(Throwable e) {
                error(dump_exception_recursive(e, "Client worker"));
            }    
        }

}

