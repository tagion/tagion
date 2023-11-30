import core.thread;
import nngd;
import nngtestutil;
import std.concurrency;
import std.conv;
import std.datetime.systime;
import std.exception;
import std.json;
import std.regex;
import std.stdio;
import std.string;
import std.uuid;

static void api_handler1 ( WebData *req, WebData *rep, void* ctx ){
    rep.text =  "REPLY TO: "~to!string(*req);
    rep.type =  "text/plain";
    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
}

static void api_handler2 ( WebData *req, WebData *rep, void* ctx ){
    JSONValue data = parseJSON("{}");
    if(req.method == "GET"){
        data["replyto"] = "REPLY TO: "~to!string(req);
        rep.json = data;
        rep.type = "application/json";
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        return;
    }
    if(req.method == "POST"){
        if(req.type == "application/octet-stream"){
            data["datalength"] = req.rawdata.length;
            data["datatype"] = req.type;
            rep.json = data,
            rep.type = "application/json",
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            return;
        }else{
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "Invalid request";
            return;
        }
    }
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


