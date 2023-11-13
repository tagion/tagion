import core.thread;
import nngd;
import nngtestutil;
import std.concurrency;
import std.conv;
import std.datetime.systime;
import std.exception;
import std.file;
import std.json;
import std.path;
import std.regex;
import std.stdio;
import std.string;
import std.uuid;

static void client_handler ( WebData *res, void* ctx ){
    log("===> Client handler:");
    writeln(res.toString());
    stdout.flush();
}   

static void error_handler ( WebData *res, void* ctx ){
    log("===> Error handler:");
    writeln(res.toString());
    stdout.flush();
}   


int
main()
{
    int rc;
    const wd = dirName(thisExePath());
    
    ubyte[] data = cast(ubyte[])(wd~"/../../data.bin").read;

    
    log("TEST1 ---------------------------------------------------  simple http get ");
    
    WebData rep1 = WebClient.get("http://httpbin.org/get", null);

    writeln(rep1.toString());
    stdout.flush();
    
    
    log("TEST2 ---------------------------------------------------  simple http post ");
    
    WebData rep2 = WebClient.post("http://httpbin.org/post", data, ["Content-type": "application/octet-stream"]);

    writeln(rep2.toString());
    stdout.flush();

    log("TEST3 ---------------------------------------------------  async http get ");
    
    NNGAio a1 = WebClient.get_async("http://httpbin.org/get", null, &client_handler );
    a1.wait();
    log("Async get finished");
    
    
    log("TEST4 ---------------------------------------------------  async http post with common request ");
    
    int context_value = 123456;
    JSONValue jdata = parseJSON(`{"one": 1, "two": 2, "more": { "three": 3 }}`);
    NNGAio a2 = WebClient.request(
        "POST",
        "http://httpbin.org/post", 
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
        "http://httpbin.org/wrong_path", 
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
    nng_sleep(3000.msecs);

    writeln("Bye!");
    return 0;
}


