module tagion.testbench.nng.nng_testsuite;
// Default import list for bdd
import std.algorithm;
import std.range;
import std.array;
import std.file : exists, fread = read, readText, fwrite = write;
import std.format;
import std.path;
import std.process;
import std.stdio;
import std.json;
import std.typecons : Tuple;
import std.exception;
import std.datetime.systime;
import std.process: environment;
import std.concurrency;
import tagion.basic.Types : FileExtension;
import tagion.behaviour;
import tagion.behaviour : check;
import tagion.behaviour.Behaviour;
import tagion.behaviour.BehaviourException : check;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;

import core.thread;
import nngd;


@trusted shared class NNGTest {
    private string[] _errors;

    static double timestamp() {
        auto ts = Clock.currTime().toTimeSpec();
        return ts.tv_sec + ts.tv_nsec/1e9;
    }

    static string dump_exception_recursive(Throwable ex, string tag = "") {
        string[] res;
        res ~= format("\r\nException caught %s : %s\r\n", Clock.currTime().toSimpleString(), tag);
        foreach (t; ex) {
            res ~= format("%s [%d]: %s \r\n%s\r\n", t.file, t.line, t.message(), t.info);
        }
        return join(res, "\r\n");
    }   

    static uint rot3 ( uint data ) { return ( data << 3 )&( data >> 29 ); }
    static uint mkrot3 ( uint data ) { return data ^ rot3(data); }
    static bool chkrot3 ( uint data, uint chk ) { return (chk ^ rot3(data)) == data; }

    void error(A...)(string fmt, A a) {
         _errors ~= format(fmt, a);
         auto _debug = environment.get("NNG_DEBUG");
         if(_debug is null || _debug != "TRUE") return;
         writefln("%.6f "~fmt,timestamp,a);
         stdout.flush();
    }

    void log(A...)(string fmt, A a) {
        auto _debug = environment.get("NNG_DEBUG");
        if(_debug is null || _debug != "TRUE") return;
        writefln("%.6f "~fmt,timestamp,a);
        stdout.flush();
    }

    string errors(){
        return _errors.empty() ? null :  "ERRORS: " ~  _errors.join("\n");
    }
}

enum feature = Feature(
            "Test of the NNG wrapper.",
            ["This Feature test of NNG sockets and services.",
            "NNG source: https://github.com/nanomsg/nng"]);

alias FeatureContext = Tuple!(
        PushpullSocketShouldSendAndReceiveByteBuffer, "PushpullSocketShouldSendAndReceiveByteBuffer",
        FeatureGroup*, "result"
);

static string testroot;

@safe @Scenario("push-pull socket should send and receive byte buffer.",
        [])
class PushpullSocketShouldSendAndReceiveByteBuffer {
    
    shared NNGTest test;
    string uri;    
    Tid[] workers; 


    this(const string iuri) {
        this.uri = iuri;
        this.test = new NNGTest();
    }

    static void sender_worker(string uri, shared NNGTest test) @trusted {
        const NDIALS = 32;
        const NMSGS = 32;
        const BSIZE = 4096;
        ubyte[BSIZE] sbuf; 
        uint k = 0;
        int rc;
        try{
            thread_attachThis();
            rt_moduleTlsCtor();
            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
            s.sendtimeout = msecs(1000);
            s.sendbuf = 4096;
            while( ++k < NDIALS ){
                rc = s.dial(uri);
                if(rc == 0) break;
                if(rc == nng_errno.NNG_ECONNREFUSED){
                    test.log("SS: Connection refused attempt %d", k);
                    nng_sleep(msecs(100));
                    continue;
                }
                test.error("SS: Dial error after %d attempts: %d", NDIALS, rc);
                enforce(rc == 0);
            }
            if(s.state is nng_socket_state.NNG_STATE_CONNECTED){
                test.log("SS:  connected with : " ~ nng_errstr(s.errno));
            }else{
                enforce(false, "SS: connection timed out");
            }
            k = 0;
            while(++k < NMSGS){
                auto line = format(`{"msg": %d, "check": %d, "time": %f}`,
                    k, test.mkrot3(k), test.timestamp());
                sbuf = cast(ubyte[])line.dup;
                rc = s.send!(ubyte[])(sbuf);
                enforce(rc == 0);
                test.log("SS: sent: " ~ line);
                nng_sleep(msecs(500));
            }
            nng_sleep(msecs(1000));
        } catch(Throwable e) {
            test.error(test.dump_exception_recursive(e, "SS: Sender worker"));
        }
    }
    
    static void receiver_worker(string uri, shared NNGTest test) @trusted {
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
                    test.error("REcv error: " ~ nng_errstr(s.errno));
                    continue;
                }
                auto line = cast(string)rbuf[0..sz];
                test.log("RR: received: " ~ line);
                auto jdata = parseJSON(line);
                k = cast(uint)(jdata["msg"].integer);
                auto c = cast(uint)(jdata["check"].integer);
                if(!test.chkrot3(k,c)){
                    test.error("Invalid message data: " ~ line);
                    continue;
                }
                if(k >= NMSGS)
                    break;
            }
        } catch(Throwable e) {
            test.error(test.dump_exception_recursive(e, "RR: Receiver worker"));
        }
    }

    @Given("a receiver and a sender worker has been spawn.")
    Document spawn_worker() @trusted {
        workers ~= spawn(&receiver_worker, this.uri, this.test);
        workers ~= spawn(&sender_worker, this.uri, this.test);
        return result_ok;
    }
    
    @When("wait until the worker has completed the conversation.")
    Document conversation() {
        (() @trusted => thread_joinAll())();
        return result_ok;
    }

    @Then("check that communication has passed with out errors.")
    Document errors() {
        auto e = test.errors;
        check( e is null , e );
        return result_ok;
    }

}
