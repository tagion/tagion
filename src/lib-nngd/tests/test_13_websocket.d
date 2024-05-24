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

import nngd;
import nngtestutil;

void onaccept_handler ( WebSocket *ws, void *ctx ){
    log("===> ONACCEPT handler:");
    auto s = `{"hello":"ws"}`;
    ws.send(cast(ubyte[])s.dup);
}   

void onmessage_handler ( WebSocket *ws, ubyte[] data, void *ctx ){
    log("===> ONMESSAGE handler:");
    log("RECV: ",cast(string)data);
    try{
        JSONValue jdata;
        int i;
        for(i=0; i<8; i++){
            jdata = parseJSON("{}");
            jdata["time"] = timestamp();
            jdata["index"] = i;
            jdata["request"] = cast(string)data;
            auto js = jdata.toString();
            log("SENT: ", js);
            ws.send(cast(ubyte[])js.dup);
        }
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Onmessage handler"));
    }        
}   


int
main()
{
    int rc;
    
    const uri = "ws://127.0.0.1:8034";

    log("TEST ---------------------------------------------------  WS SERVER ");

    try{
        std.file.write("data.txt", "12345");
        WebSocketApp wsa = WebSocketApp(uri, &onaccept_handler, &onmessage_handler, null );
        wsa.start();
        nng_sleep(300.msecs);
        auto res = executeShell("timeout 2 uwsc -i -s -t data.txt ws://127.0.0.1:8034 2>&1");
        assert(res.status == 124);
        assert(indexOf(res.output,"Websocket connected") == 0);
        assert(indexOf(res.output,`"request":"12345"`) == 136);
        nng_sleep(2000.msecs);

    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Main"));
    }        
    
    log("Bye!");
    return populate_state(13, "Websocket tests");
}



