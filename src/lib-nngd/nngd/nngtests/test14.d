module nngd.nngtests.test14;

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
import nngd.nngtests.suite;

const _testclass = "nngd.nngtests.nng_test14_websocketpool";


struct ws_device {
    Tid tid;
    WebSocket *ws;
    void  *ctx;
}

@trusted class nng_test14_websocketpool : NNGTest {
    
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
            scope(exit){
                wc.close;
                wsa.stop;
            }
            while(wc.state != ws_state.CLOSED){
                nng_sleep(300.msecs);
                wc.poll();
                // TODO: fix dispatch template to avoid that cast
                wc.dispatch(cast(ws_client_handler)&this.client_handler);
                auto et = timestamp();
                if( et - st > 2.0 ) break;
            }
            assert(received[1].endsWith("TICK: 0"));
            assert(received[19].endsWith("TICK: 18"));
            nng_sleep(500.msecs);
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "MAIN"));
        }    
        log(_testclass ~ ": Bye!");
        return [];
    }

    static void client_handler ( string msg, void* ctx ) @trusted {
        try{
            auto obj = cast(nng_test14_websocketpool*)ctx;
            obj.log("Client RECV: "~msg);
            obj.received ~= msg;
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Client handler"));
        }        
    }

    static void onaccept_handler ( WebSocket *ws, void *ctx ) @trusted {
        try{
            auto sid = ws.sid;
            auto obj = cast(nng_test14_websocketpool*)ctx;
            auto s = `{"hello":"ws", "sid":"`~ sid ~`"}`;
            obj.log("===> ONACCEPT handler:");
            ws.send(cast(ubyte[])s.dup);
            if(sid in obj.ws_devices){
                obj.log("Already cached socket: ", sid);
                return;
            }
            ws_device d = {
                ws: ws,
                ctx: ctx
            };
            obj.ws_devices[sid] = cast(shared ws_device)d;
            auto tid =  spawn(&ws_fiber, ws.sid, cast(immutable(void*))ctx);
            obj.ws_devices[sid].tid = cast(shared(Tid))tid;
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Onaccept handler"));
        }        
    }   

    static void onmessage_handler ( WebSocket *ws, ubyte[] data, void *ctx ) @trusted {
        try{
            JSONValue jdata;
            int i;
            auto obj = cast(nng_test14_websocketpool*)ctx;
            auto sid = ws.sid;
            obj.log("===> ONMESSAGE handler: " ~ sid);
            obj.log("RECV: " ~ cast(string)data);
            if(sid in obj.ws_devices){
                obj.log("Sent to TID:");
                send(cast(Tid)obj.ws_devices[sid].tid, cast(string)data);
            }
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Onmessage handler"));
        }        
    }   

    static void onclose_handler( WebSocket *ws, void *ctx ) @trusted {
        try {
            auto obj = cast(nng_test14_websocketpool*)ctx;
            obj.log("===> ONCLOSE handler:" ~ ws.sid);
            // TODO:
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Onmessage handler"));
        }        
    }

    static void onerror_handler(WebSocket *ws, int err, void *ctx ) @trusted {
        try{
            auto obj = cast(nng_test14_websocketpool*)ctx;
            obj.log("===> ONERROR handler: " ~ ws.sid ~ ": " ~  to!string(err));
            // TODO:
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Onmessage handler"));
        }        
    }

    static void ws_fiber( string sid, immutable void* ctx ) @trusted {
        try{
            int rc;
            int attempts = 0;
            int i = 0;
            auto obj = cast(nng_test14_websocketpool*)ctx;
            WebSocket *ws = cast(WebSocket*)obj.ws_devices[sid].ws;
            obj.log("WS: connected ", ws.sid);
            scope(exit){
                obj.ws_devices.remove(sid);
            }
            while (!ws.closed) {
                receiveTimeout( 10.msecs,
                    (string s){
                        ws.send(cast(ubyte[])("WSF: "~sid~" CMD: "~s));
                        if(s == "close"){
                            ws.close();
                        }
                    }
                );    
                ws.send(cast(ubyte[])("WSF: "~sid~" TICK: "~to!string(i)));
                i++;
                Thread.sleep(100.msecs);
            }
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Websocket fiber"));
        }        
    }
    
    private:
        string uri;
        string[] received;
        shared ws_device[string] ws_devices;

}




