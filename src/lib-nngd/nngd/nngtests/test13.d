module nngd.nngtests.test13;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.conv;
import std.string;
import std.datetime.systime;
import std.path;
import std.file;
import std.uuid;
import std.regex;
import std.exception;
import std.process;
import std.algorithm;
import std.array;
import core.thread;
import core.thread.osthread;

import nngd;

const _testclass = "nngd.nngtests.nng_test13_websocket";

@trusted class nng_test13_websocket : NNGTest {
    
    this(Args...)(auto ref Args args) { super(args); }    

    override string[] run(){
        try{
            log("NNG test 13: websocket");
            this.uri = "ws://127.0.0.1:31013";
            auto self_ = self;
            WebSocketApp wsa = WebSocketApp(uri, &this.onaccept_handler, &this.onclose_handler, &this.onerror_handler, &this.onmessage_handler, &self_ );
            wsa.start();
            nng_sleep(300.msecs);
            auto st = timestamp();
            WebSocketClient wc = WebSocketClient(uri, &self_);
            while(wc.state != ws_state.CLOSED){
                nng_sleep(300.msecs);
                wc.send("ping");
                wc.poll();
                // TODO: fix dispatch template to avoid that cast
                wc.dispatch(cast(ws_client_handler)&this.client_handler);
                auto et = timestamp();
                if( et - st > 2.0 ) break;
            }
            auto jres = received.map!(parseJSON).array();
            assert((jres[0]["hello"]).str == "ws");
            assert((jres[1]["index"]).integer == 0);
            assert((jres[8]["index"]).integer == 7);
            nng_sleep(1000.msecs);
            wc.close;
            wsa.stop;
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "MAIN"));
        }    
        log(_testclass ~ ": Bye!");
        return [];
    }

    static void client_handler ( string msg, void* ctx ) @trusted {
        try{
            auto obj = cast(nng_test13_websocket*)ctx;
            obj.log("Client RECV: "~msg);
            obj.received ~= msg;
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Client handler"));
        }        
    }

    static void onaccept_handler ( WebSocket *ws, void *ctx ) @trusted {
        try{
            auto obj = cast(nng_test13_websocket*)ctx;
            obj.log("===> ONACCEPT handler:");
            auto s = `{"hello":"ws"}`;
            ws.send(cast(ubyte[])s.dup);
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Onaccept handler"));
        }        
    }   

    static void onmessage_handler ( WebSocket *ws, ubyte[] data, void *ctx ) @trusted {
        try{
            JSONValue jdata;
            int i;
            auto obj = cast(nng_test13_websocket*)ctx;
            obj.log("===> ONMESSAGE handler:");
            obj.log("RECV: " ~ cast(string)data);
            for(i=0; i<8; i++){
                jdata = parseJSON("{}");
                jdata["time"] = timestamp();
                jdata["index"] = i;
                jdata["request"] = cast(string)data;
                auto js = jdata.toString();
                obj.log("SENT: " ~ js);
                ws.send(cast(ubyte[])js.dup);
            }
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Onmessage handler"));
        }        
    }   

    static void onclose_handler( WebSocket *ws, void *ctx ) @trusted {
        try {
            auto obj = cast(nng_test13_websocket*)ctx;
            obj.log("===> ONCLOSE handler:");
            // TODO:
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Onmessage handler"));
        }        
    }

    static void onerror_handler(WebSocket *ws, int err, void *ctx ) @trusted {
        try{
            auto obj = cast(nng_test13_websocket*)ctx;
            obj.log("===> ONERROR handler: " ~ to!string(err));
            // TODO:
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Onmessage handler"));
        }        
    }
    
    private:
        string uri;
        string[] received;

}


