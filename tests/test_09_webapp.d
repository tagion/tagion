import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.regex;
import std.json;
import std.exception;

import nngd;
import nngtestutil;

static WebData api_handler1 ( WebData req, void* ctx ){
    WebData rep = {
        text: "REPLY TO: "~to!string(req),
        type: "text/plain",
        status: nng_http_status.NNG_HTTP_STATUS_OK
    };
    return rep;
}

static WebData api_handler2 ( WebData req, void* ctx ){
    JSONValue data = parseJSON("{}");
    if(req.method == "GET"){
        data["replyto"] = "REPLY TO: "~to!string(req);
        WebData rep = {
            json: data,
            type: "application/json",
            status: nng_http_status.NNG_HTTP_STATUS_OK
        };
        return rep;
    }
    if(req.method == "POST"){
        if(req.type == "application/octet-stream"){
            data["datalength"] = req.rawdata.length;
            data["datatype"] = req.type;
            WebData rep = {
                json: data,
                type: "application/json",
                status: nng_http_status.NNG_HTTP_STATUS_OK
            };
            return rep;
        }else{
            WebData rep = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "Invalid request"};
            return rep;
        }
    }
    return WebData();
}


int
main()
{
    int rc;
 

    WebApp app = WebApp("myapp", "http://localhost:8081", parseJSON(`{"root_path":"/home/yv/work/repo/nng/tests/webapp","static_path":"static"}`), null);
    
    app.route("/api/v1/test1",&api_handler1);
    app.route("/api/v1/test2/*",&api_handler2,["GET","POST"]);

    app.start();
    
    writeln(`
        Consider tests:

        curl http://localhost:8081/api/v1/test1
        curl http://localhost:8081/api/v1/test2/a/b/c?x=y
        curl -X POST -H "Content-Type: application/octet-stream" -d @file.bin http://localhost:8081/api/v1/test2

    `);


    while(true){
        nng_sleep(1000.msecs);
    }

    log("...passed");        

    writeln("Bye!");
    return 0;
}



