import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.random;
import std.exception;


import nngd;

/*

to test web api with binary post data
consider address = http://127.0.0.1:8080/api/v1/hirpc
and file contains hibon request

*/


int main(string[] argv)
{
    if(argv.length < 3){
        writefln("Usage: %s <address> <request file> [n=5]", argv[0]);
        return 1;
    }           
    
    auto address = argv[1];

    auto f = File(argv[2], "r");
    auto doc = f.rawRead(new ubyte[4096]);
    f.close();

    writeln(doc);
    
    int n = 5;

    if(argv.length > 3){
        n = to!int(argv[3]);
    }

    for(auto i = 0; i<n; i++){
        writeln("Turn ", i);
        auto rep = WebClient.post(address, doc, [
            "Content-type": "application/octet-stream"
        ], 3000.msecs);
        writeln(rep.toString());
        Thread.sleep(1000.msecs);
    }

    return 0;
}

