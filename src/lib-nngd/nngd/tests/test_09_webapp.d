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

long getmemstatus() {
    long sz = -1;
    auto f = File("/proc/self/status", "rt");
    foreach (line; f.byLine) {
        if (line.startsWith("VmRSS")) {
            sz = to!long(line.split()[1]);
            break;
        }
    }
    f.close();
    return sz;
}



static void api_handler1 ( WebData *req, WebData *rep, void* ctx ){
    thread_attachThis();
    rep.text =  "REPLY TO: "~to!string(*req);
    rep.type =  "text/plain";
    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
}

static void api_handler2 ( WebData *req, WebData *rep, void* ctx ){
    thread_attachThis();
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

static void getmem_handler(WebData* req, WebData* rep, void* ctx){
       thread_attachThis();
       JSONValue data = parseJSON("{}");
       data["memsize"] = getmemstatus();
       rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
       rep.type = "applicaion/json";
       rep.json = data;
  
       writeln(rep.toString());
}

int
main()
{
    int rc;
 

    WebApp app = WebApp("myapp", "http://localhost:8081", parseJSON(`{"root_path":"/home/yv/work/repo/nng/tests/webapp","static_path":"static"}`), null);
    
    app.route("/api/v1/test2",&api_handler2,["POST"]);
    app.route("/api/v1/test1",&api_handler1,["GET"]);
    app.route("/api/v1/memsize",&getmem_handler,["GET"]);

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



