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

import nngd;
import nngtestutil;

void onaccept_handler ( WebSocket *ws, void *ctx ){
    log("===> ONACCEPT handler:");
    stdout.flush();
}   

void onmessage_handler ( WebSocket *ws, ubyte[] data, void *ctx ){
    log("===> ONMESSAGE handler:");
    writeln("RECV: ",cast(string)data);
    stdout.flush();
    JSONValue jdata;
    int i;
    for(i=0; i<8; i++){
        jdata = parseJSON("{}");
        jdata["time"] = timestamp();
        jdata["index"] = i;
        jdata["request"] = cast(string)data;
        auto js = jdata.toString();
        writeln("SENT: ", js);
        ws.send(cast(ubyte[])js.dup);
    }
}   


int
main()
{
    int rc;
    
    const uri = "ws://127.0.0.1:8034";

    log("TEST ---------------------------------------------------  WS SERVER ");
    
    WebSocketApp wsa = WebSocketApp(uri, &onaccept_handler, &onmessage_handler, null );

    wsa.start();

    while(true)
        nng_sleep(100.msecs);

    writeln("Bye!");
    return 0;
}



