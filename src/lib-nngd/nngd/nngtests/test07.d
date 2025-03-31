module nngd.nngtests.test07;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.conv;
import std.datetime.systime;
import std.uuid;
import core.thread;
import core.thread.osthread;
import nngd;
import nngd.nngtests.suite;

const _testclass = "nngd.nngtests.nng_test07_aio_callback";

@trusted class nng_test07_aio_callback : NNGTest {
    
    this(Args...)(auto ref Args args) { 
        super(args);
    }    

    override string[] run(){
        log("NNG test 07: aio callbback");
        int rc;
        string s = "AbAbAgAlAmAgA";
        string url = "tcp://127.0.0.1:13007";
        try{
            NNGSocket sr = NNGSocket(nng_socket_type.NNG_SOCKET_PULL, false);
            sr.recvtimeout = msecs(1000);
            rc = sr.listen(url);
            enforce(rc == 0);
            NNGSocket ss = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH, false);
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
            
            NNGAio saio = NNGAio(null, null);
            NNGAio raio = NNGAio(null, null);
            
            auto self_ = self;

            saio.realloc( &this.scb, &saio, &(self_) );
            raio.realloc( &this.rcb, &raio, &(self_) );

            log("AIO allocated");

            saio.timeout = msecs(1000);
            raio.timeout = msecs(1000);
            saio.set_msg(msg2);

            ss.sendaio(saio);

            log("AIO send started");

            sr.receiveaio(raio);
            
            log("AIO receive started");
            
            saio.wait();
            raio.wait();

            log("AIO wait completed");
            
            nng_sleep(msecs(1000));

            log("Test error message with header");

            msg3.clear();
            log(format("M3: L: %d H: %d ", msg3.length, msg3.header_length));   
            msg3.body_append("ERROR");
            msg3.header_append("ERROR:404");
            log(format("M3: L: %d H: %d ", msg3.length, msg3.header_length));   
            saio.set_msg(msg3);
            ss.sendaio(saio);
            sr.receiveaio(raio);
            
            saio.wait();
            raio.wait();

            Thread.sleep(msecs(500));
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "Main: " ~ _testclass));
        }    
        log(_testclass ~ ": Bye!");      
        return [];
    }

    static void scb ( void* p )  {
        try{
            NNGAio* aio = cast(NNGAio*)p;
            nng_test07_aio_callback* obj = cast(nng_test07_aio_callback*) aio.context;
            obj.log("Send callback");
            if(p is null){ obj.error("Null send AIO"); return; } 
            int res = aio.result;
            size_t cnt = aio.count;
            enforce(res == 0);
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Send callback"));
        }    
    }

    static void rcb ( void* p ) {
        try{
            NNGAio* aio = cast(NNGAio*)p;
            nng_test07_aio_callback* obj = cast(nng_test07_aio_callback*) aio.context;
            obj.log("Receive callback");
            if(p is null){ obj.error("Null recv AIO"); return; } 
            int res = aio.result;
            size_t cnt = aio.count;
            enforce(res == 0);
            NNGMessage msg  = NNGMessage(0);
            if(aio.get_msg(msg) != nng_errno.NNG_OK){
                obj.error("Received empy msg");
                return;
            }
            obj.log("Received message: %d : %d", msg.length,  msg.header_length);
            if(msg.length > 14){
                auto x = msg.body_trim!string(); 
                    obj.log("Received string: %s",x);
            }else{
                auto y = msg.header_trim!string();
                obj.log("Received header: %s",y);
                auto z = msg.body_trim!string();
                obj.log("Received body: %s",z);
            }      
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Receive callback"));
        }    
    }

    
}


