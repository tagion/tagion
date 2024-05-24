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
import std.base64;
import std.exception;
import std.process;

import nngd;
import nngtestutil;

static void client_handler ( WebData *res, void* ctx ){
    log("===> Client handler:");
    try{
        auto jdata = res.toJSON();
        if(ctx is null){
            assert(jdata["length"].uinteger == 67);
        }else{
            int c = *(cast(int*)ctx);
            assert(c == 123456);
            assert(jdata["json"]["data"].str == "{\"more\":{\"three\":3},\"one\":1,\"two\":2}");
        }    
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Client handler"));
    }    
}   

static void error_handler ( WebData *res, void* ctx ){
    try{
        log("===> Error handler:");
        auto jdata = res.toJSON();
        assert(jdata["length"].uinteger == 369);
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Error handler"));
    }    
}   


static void server_get_handler ( WebData *req, WebData *rep, void* ctx ){
    try{
        thread_attachThis();
        rep.type =  "application/json";
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        JSONValue jdata = parseJSON("{}");
        jdata["uri"] = req.rawuri;
        jdata["headers"] = JSONValue(req.headers);
        rep.json = jdata;
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "GET handler"));
    }        
}

static void server_post_handler ( WebData *req, WebData *rep, void* ctx ){
    try{
        thread_attachThis();
        rep.type =  "application/json";
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        rep.json = parseJSON("{}");
        rep.json["uri"] = req.rawuri;
        rep.json["headers"] = JSONValue(req.headers);
        if(req.type.startsWith("application/json")){
            rep.json["data"] = JSONValue(cast(string)req.rawdata.dup);
        }            
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "POST handler"));
    }        
}

int
main()
{
    int rc;
    const wd = dirName(thisExePath());
    

    try{
        {
            auto drc = executeShell("dd if=/dev/urandom of="~wd~"/data.bin count=1 bs=4096");
            assert(drc.status == 0);
        }
            
        ubyte[] data = cast(ubyte[])(wd~"/data.bin").read;

        
        {
            auto drc = executeShell("mkdir -p "~wd~"/webapp/static"); 
            assert(drc.status == 0);
            WebApp app = WebApp("myapp", "http://localhost:8081", parseJSON(`{"root_path":"`~wd~`/webapp","static_path":"static"}`), null);
            app.route("/get",&server_get_handler,["GET"]);
            app.route("/post",&server_post_handler,["POST"]);
            app.start();
        }


        {
            log("TEST1 ---------------------------------------------------  simple http get ");
            WebData rep = WebClient.get("http://localhost:8081/get", null);
            auto jdata = rep.toJSON();
            if(jdata["status"].integer != 200){
                error("HTTP GET Error: "~jdata["msg"].str);
            }else{
                assert(jdata["datasize"].uinteger == 67);
                assert(jdata["length"].uinteger == 67);
            }                
        }
        
        {
            log("TEST2 ---------------------------------------------------  simple http post ");    
            WebData rep = WebClient.post("http://localhost:8081/post", data, ["Content-type": "application/octet-stream"]);
            auto jdata = rep.toJSON();
            if(jdata["status"].integer != 200){
                error("HTTP POST Error: "~jdata["msg"].str);
            }else{
                assert(jdata["json"]["headers"]["Content-Length"].str == "4096");
            }    
        }

        {
            log("TEST3 ---------------------------------------------------  async http get ");    
            NNGAio a = WebClient.get_async("http://localhost:8081/get", null, &client_handler );
            a.wait();
            log("Async get finished");
        }
        
        {
            log("TEST4 ---------------------------------------------------  async http post with common request ");
            
            int context_value = 123456;
            JSONValue jdata = parseJSON(`{"one": 1, "two": 2, "more": { "three": 3 }}`);
             NNGAio a2 = WebClient.request(
                "POST",
                "http://localhost:8081/post", 
                [
                    "Content-type": "application/json; charset=UTF-8"
                 ], 
                jdata.toString(),
                null,
                &client_handler,
                &error_handler,
                1000.msecs,
                &context_value
                );
            a2.wait();
            log("Async post finished");
            NNGAio a3 = WebClient.request(
                "POST",
                "http://localhost:8081/wrong_path", 
                [
                    "Content-type": "application/json; charset=UTF-8"
                ], 
                jdata.toString(),
                null,
                &client_handler,
                &error_handler,
                1000.msecs,
                &context_value
                );
            a3.wait();
            log("Async post with error finished");
            
             log("...passed");        
        }
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Main"));
    }    

    nng_sleep(1000.msecs);
    log("Bye!");
    return populate_state(11, "Webclient tests");
}



