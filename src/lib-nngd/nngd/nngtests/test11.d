module nngd.nngtests.test11;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.conv;
import std.datetime.systime;
import std.algorithm;
import std.string;
import std.uuid;
import std.file;
import std.path;
import std.regex;
import std.base64;
import std.process;
import core.thread;
import core.thread.osthread;
import nngd;

const _testclass = "nngd.nngtests.nng_test11_webclient";

struct mycontext {
    int intval;
    void* ptrval;
};

@trusted class nng_test11_webclient : NNGTest {
    
    this(Args...)(auto ref Args args) { 
        super(args);
    }    

    override string[] run(){
    try {    
        log("NNG test 09: WebApp");

        int rc;
        auto self_ = self;
        
        auto wd = nngtest_mkassert();
        enforce(wd !is null && wd.exists, "Error creating assert dir");
        auto drc = executeShell("dd if=/dev/urandom of="~wd~"/data.bin count=1 bs=4096");
        assert(drc.status == 0);
        
        WebApp app = WebApp("myapp", "http://localhost:13011", parseJSON(`{"root_path":"`~wd~`/webapp","static_path":"static"}`), &self_);
        
        app.route("/get",&server_get_handler,["GET"]);
        app.route("/post",&server_post_handler,["POST"]);

        app.start();
            
        ubyte[] data = cast(ubyte[])(wd~"/data.bin").read;
        
        mycontext context;
        context.intval = 12345;
        context.ptrval = cast(void*)&self_;
        

        {
            log("TEST1 ---------------------------------------------------  simple http get ");
            WebData rep = WebClient.get("http://localhost:13011/get", null);
            auto jdata = rep.toJSON();
            if(jdata["status"].integer != 200){
                error("HTTP GET Error: "~jdata["msg"].str);
            }else{
                assert(jdata["datasize"].uinteger == 68);
                assert(jdata["length"].uinteger == 68);
            }
            log("---");
        }
        
        {
            log("TEST2 ---------------------------------------------------  simple http post ");    
            WebData rep = WebClient.post("http://localhost:13011/post", data, ["Content-type": "application/octet-stream"]);
            auto jdata = rep.toJSON();
            if(jdata["status"].integer != 200){
                error("HTTP POST Error: "~jdata["msg"].str);
            }else{
                assert(jdata["json"]["headers"]["Content-Length"].str == "4096");
            }    
            log("---");
        }

        {
            log("TEST3 ---------------------------------------------------  async http get ");    
            NNGAio a = WebClient.get_async("http://localhost:13011/get", null, &client_handler, 30000.msecs, &context );
            log("d1");
            a.wait();
            log("Async get finished");
            log("---");
        }
        
        {
            log("TEST4 ---------------------------------------------------  async http post with common request ");
            
            JSONValue jdata = parseJSON(`{"one": 1, "two": 2, "more": { "three": 3 }}`);
            NNGAio a2 = WebClient.request(
                "POST",
                "http://localhost:13011/post", 
                [
                    "Content-type": "application/json; charset=UTF-8"
                 ], 
                jdata.toString(),
                null,
                &client_handler,
                &error_handler,
                1000.msecs,
                &context
                );
            a2.wait();
            log("Async post finished");
            NNGAio a3 = WebClient.request(
                "POST",
                "http://localhost:13011/wrong_path", 
                [
                    "Content-type": "application/json; charset=UTF-8"
                ], 
                jdata.toString(),
                null,
                &client_handler,
                &error_handler,
                1000.msecs,
                &context
                );
            a3.wait();
            log("Async post with error finished");
            log("---");
        }

        nngtest_rmassert(wd);
        log(_testclass ~ ": Bye!");      
    } catch(Throwable e) {
        nngtest_error(dump_exception_recursive(e, "MAIN"));
    }    
        return [];
    }

    static void client_handler ( WebData *res, void* ctx ){
        try{
            thread_attachThis();
            auto cnt = *(cast(mycontext*)ctx);
            auto obj = cast(nng_test11_webclient*)cnt.ptrval;
            obj.log("===> Client handler:");
            auto jdata = res.toJSON();
            if(ctx is null){
                assert(jdata["length"].uinteger == 67);
            }else{
                assert(cnt.intval == 123456);
                assert(jdata["json"]["data"].str == "{\"more\":{\"three\":3},\"one\":1,\"two\":2}");
            }    
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Client handler"));
        }    
    }   

    static void error_handler ( WebData *res, void* ctx ){
        try{
            thread_attachThis();
            auto cnt = cast(mycontext*)ctx;
            auto obj = cast(nng_test11_webclient*)cnt.ptrval;
            obj.log("===> Error handler:");
            auto jdata = res.toJSON();
            assert(jdata["length"].uinteger == 369);
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "Error handler"));
        }    
    }   


    static void server_get_handler ( WebData *req, WebData *rep, void* ctx ){
        try{
            thread_attachThis();
            auto obj = cast(nng_test11_webclient*)ctx;
            rep.type =  "application/json";
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            JSONValue jdata = parseJSON("{}");
            jdata["uri"] = req.rawuri;
            jdata["headers"] = JSONValue(req.headers);
            rep.json = jdata;
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "GET handler"));
        }        
    }

    static void server_post_handler ( WebData *req, WebData *rep, void* ctx ){
        try{
            thread_attachThis();
            auto obj = cast(nng_test11_webclient*)ctx;
            rep.type =  "application/json";
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.json = parseJSON("{}");
            rep.json["uri"] = req.rawuri;
            rep.json["headers"] = JSONValue(req.headers);
            if(req.type.startsWith("application/json")){
                rep.json["data"] = JSONValue(cast(string)req.rawdata.dup);
            }            
        } catch(Throwable e) {
            nngtest_error(dump_exception_recursive(e, "POST handler"));
        }        
    }

    
}
