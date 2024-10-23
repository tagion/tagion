import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.path;
import std.file;
import std.uuid;
import std.regex;
import std.json;
import std.exception;
import std.process;
import std.algorithm;
import std.array;

import nngd;
import nngtestutil;

void onaccept_handler ( WebSocket *ws, void *ctx ){
    log("===> ONACCEPT handler:");
    auto s = `{"hello":"ws"}`;
    ws.send(cast(ubyte[])s.dup);
}   

void onmessage_handler ( WebSocket *ws, ubyte[] data, void *ctx ){
    log("===> ONMESSAGE handler:");
    log("RECV: " ~ cast(string)data);
    try{
        JSONValue jdata;
        int i;
        for(i=0; i<8; i++){
            jdata = parseJSON("{}");
            jdata["time"] = timestamp();
            jdata["index"] = i;
            jdata["request"] = cast(string)data;
            auto js = jdata.toString();
            log("SENT: " ~ js);
            ws.send(cast(ubyte[])js.dup);
        }
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Onmessage handler"));
    }        
}   

void onclose_handler( WebSocket *ws, void *ctx ){
    log("===> ONCLOSE handler:");
}

void onerror_handler(WebSocket *ws, int err, void *ctx ){
    log("===> ONERROR handler: " ~ to!string(err));
}

string[] received;

void client_handler( string msg ){
    received ~= msg;
}

int
main()
{
    int rc;
    
    const uri = "ws://127.0.0.1:31034";

    log("TEST ---------------------------------------------------  WS SERVER ");

    try{
        WebSocketApp wsa = WebSocketApp(uri, &onaccept_handler, &onclose_handler, &onerror_handler, &onmessage_handler, null );
        wsa.start();
        nng_sleep(300.msecs);
        auto st = timestamp();
        WebSocketClient wc = WebSocketClient(uri);
        while(wc.state != ws_state.CLOSED){
            nng_sleep(300.msecs);
            wc.send("ping");
            wc.poll();
            wc.dispatch(&client_handler);
            auto et = timestamp();
            if( et - st > 2.0 ) break;
        }
        auto jres = received.map!(parseJSON).array();
        assert((jres[0]["hello"]).str == "ws");
        assert((jres[1]["index"]).integer == 0);
        assert((jres[8]["index"]).integer == 7);
        nng_sleep(1000.msecs);
        wsa.stop;
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Main"));
    }        
    
    log("Bye!");
    return populate_state(13, "Websocket tests");
}



