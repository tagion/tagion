import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.file;
import std.regex;
import std.json;
import std.exception;
import std.process;

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
    try{
        thread_attachThis();
        rep.text =  to!string((*req).toJSON("handler1"));
        rep.type =  "text/plain";
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Handler - 1"));
    }        
}

static void api_handler2 ( WebData *req, WebData *rep, void* ctx ){
    try{
        thread_attachThis();
        JSONValue data = parseJSON("{}");
        if(req.method == "GET"){
            data["replyto"] = (*req).toJSON("handler2");
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
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Handler - 2"));
    }        
}

static void getmem_handler(WebData* req, WebData* rep, void* ctx){
    try{
        thread_attachThis();
        JSONValue data = parseJSON("{}");
        data["memsize"] = getmemstatus();
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        rep.type = "applicaion/json";
        rep.json = data;
        log(rep.toString());
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "GetMem handler"));
    }        
}

int
main()
{
    int rc;
   
    try {

        WebApp app = WebApp("myapp", "http://localhost:8081", parseJSON(`{"root_path":"`~getcwd()~`/webapp","static_path":"static"}`), null);
        
        app.route("/api/v1/test2/*",&api_handler2,["POST","GET"]);
        app.route("/api/v1/test1/*",&api_handler1,["GET"]);
        app.route("/api/v1/memsize",&getmem_handler,["GET"]);

        app.start();

    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Server start"));
    }        
    
    log(`
        Consider tests:

        curl http://localhost:8081/api/v1/test1
        curl http://localhost:8081/api/v1/test2/a/b/c?x=y
        curl -X POST -H "Content-Type: application/octet-stream" -d @file.bin http://localhost:8081/api/v1/test2

    `);

    nng_sleep(500.msecs);    
    
    try {

        
        {
            auto res = executeShell("curl -k -s http://localhost:8081/api/v1/test1/a/b/c/?x=y");
            assert(res.status == 0);
            auto jres = parseJSON(res.output);
            assert(jres["#TAG"].str == "handler1");
            assert(jres["path"][2].str == "test1" );
            assert(jres["param"]["x"].str == "y" );
        }

        {
            auto res = executeShell("curl -k -s http://localhost:8081/api/v1/test2/a/b/c/?x=y");
            assert(res.status == 0);
            auto jres = parseJSON(res.output);
            assert(jres["replyto"]["#TAG"].str == "handler2");
            assert(jres["replyto"]["path"][2].str == "test2" );
            assert(jres["replyto"]["param"]["x"].str == "y" );
        }
        
        {
            auto drc = executeShell("dd if=/dev/urandom of=file.bin count=1 bs=1048576");
            assert(drc.status == 0);
            auto res = executeShell("curl -k -s -X POST -H \"Content-Type: application/octet-stream\" --data-bin @file.bin http://localhost:8081/api/v1/test2");
            assert(res.status == 0);
            auto jres = parseJSON(res.output);
            assert(jres["datalength"].integer == 1048576);
            assert(jres["datatype"].str == "application/octet-stream" );
        }
    
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Endpoint tests"));
    }        
    

    log("...passed");        

    log("Bye!");

    return populate_state(9, "Webapp tests");
}



