module nngd.nngtests.test06;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.conv;
import std.regex;
import std.file;
import std.random;
import core.thread;
import core.thread.osthread;
import nngd;
import nngd.nngtests.suite;

const _testclass = "nngd.nngtests.nng_test06_message";

@trusted class nng_test06_message : NNGTest {
    
    this(Args...)(auto ref Args args) { super(args); }    

    override string[] run(){
        int rc;
        string s = "AbAbAgAlAmAgA";
        log("NNG test 06: nng message manupulation");
        
        log("NNGMessage test 1: assembly-disassembly");
        try{
            NNGMessage msg1 = NNGMessage(0);
            
            rc = msg1.body_append!ushort(11);  enforce(rc == 0);
            rc = msg1.body_append!uint(12);    enforce(rc == 0);
            rc = msg1.body_append!ulong(13);   enforce(rc == 0);
            rc = msg1.body_prepend(cast(ubyte[])s); enforce(rc == 0);
            
            enforce( msg1.length == 27 && msg1.header_length == 0 );

            auto x1 = msg1.body_chop!ulong(); 
                enforce(x1 == 13);
            auto x2 = msg1.body_chop!uint(); 
                enforce(x2 == 12);
            auto x3 = msg1.body_chop!ushort(); 
                enforce(x3 == 11);
            auto x4 = msg1.body_trim!(ubyte[])(); 
                string x5 = cast(string)x4;
                enforce(x5 == s);
            
            enforce( msg1.length == 0 && msg1.header_length == 0 );
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "test 1: assembly-disassembly"));
        }
        log("...passed");        
        
        log("NNGMessage test 2: send-receive");
        
        string url = "tcp://127.0.0.1:13006";
        try{
            NNGSocket sr = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
            sr.recvtimeout = msecs(1000);
            rc = sr.listen(url);
            enforce(rc == 0);
            NNGSocket ss = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
            ss.sendtimeout = msecs(1000);
            ss.sendbuf = 4096;
            rc = ss.dial(url);
            enforce(rc == 0);
            
            NNGMessage msg2 = NNGMessage(0);
            rc = msg2.body_append!ushort(11);  enforce(rc == 0);
            rc = msg2.body_append!uint(12);    enforce(rc == 0);
            rc = msg2.body_append!ulong(13);   enforce(rc == 0);
            rc = msg2.body_prepend(cast(ubyte[])s); enforce(rc == 0);
            NNGMessage msg3 = NNGMessage(0);
            
            rc = ss.sendmsg(msg2);
            enforce(rc == 0);

            rc = sr.receivemsg(&msg3);
            enforce(rc == 0);

            enforce( msg3.length == 27 && msg3.header_length == 0 );

            auto x6 = msg3.body_trim!string(s.length); 
                enforce(x6 == s);
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "test 2: send-receive"));
        }

        log("NNGMessage test 3: realloc");
        try{
            NNGMessage *msg4 = new NNGMessage(0);
            
            ubyte[] data = cast(ubyte[])("/dev/urandom".read(8192));
            auto rnd = Random(to!int(timestamp));
            ulong k;
            for(auto i=0; i<128; i++){
                k = uniform(0,8192,rnd);
                msg4.clear();
                msg4.body_append(data[0..k]);
                enforce(msg4.length == k);
            }        
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "test 3: realloc"));
        }

        log("...passed");        
        log(_testclass ~ ": Bye!");
        return [];
    }
    
    
}



