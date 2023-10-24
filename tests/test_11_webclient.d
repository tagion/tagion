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

import nngd;
import nngtestutil;

static void client_handler ( WebData *res, void* ctx ){
    log("===> Client handler:");
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
    
    WebClient c = WebClient("");
    NNGAio a = c.get_async("http://httpbin.org/get", null, &client_handler );
    a.wait();
    log("...passed");        

    writeln("Bye!");
    return 0;
}



