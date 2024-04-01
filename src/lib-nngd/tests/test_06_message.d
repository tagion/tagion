import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.regex;
import std.exception;
import std.file;
import std.random;

import nngd;
import nngtestutil;


int
main()
{
    int rc;
    string s = "AbAbAgAlAmAgA";

    log("NNGMessage test 1: assembly-disassembly");

    NNGMessage msg1 = NNGMessage(0);
    
    rc = msg1.body_append!ushort(11);  enforce(rc == 0);
    rc = msg1.body_append!uint(12);    enforce(rc == 0);
    rc = msg1.body_append!ulong(13);   enforce(rc == 0);
    rc = msg1.body_prepend(cast(ubyte[])s); enforce(rc == 0);
    
    enforce( msg1.length == 27 && msg1.header_length == 0 );

    auto x1 = msg1.body_chop!ulong(); 
        enforce(x1 == 13);
    auto x2 = msg1.body_chop!uint(); 
        enforce(x2 == 12);
    auto x3 = msg1.body_chop!ushort(); 
        enforce(x3 == 11);
    auto x4 = msg1.body_trim!(ubyte[])(); 
        string x5 = cast(string)x4;
        enforce(x5 == s);
    
    enforce( msg1.length == 0 && msg1.header_length == 0 );

    log("...passed");        
    
    log("NNGMessage test 2: send-receive");

    string url = "tcp://127.0.0.1:13003";

    NNGSocket sr = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
    sr.recvtimeout = msecs(1000);
    rc = sr.listen(url);
    enforce(rc == 0);
    NNGSocket ss = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
    ss.sendtimeout = msecs(1000);
    ss.sendbuf = 4096;
    rc = ss.dial(url);
    enforce(rc == 0);
    
    NNGMessage msg2 = NNGMessage(0);
    rc = msg2.body_append!ushort(11);  enforce(rc == 0);
    rc = msg2.body_append!uint(12);    enforce(rc == 0);
    rc = msg2.body_append!ulong(13);   enforce(rc == 0);
    rc = msg2.body_prepend(cast(ubyte[])s); enforce(rc == 0);
    NNGMessage msg3 = NNGMessage(0);
    
    rc = ss.sendmsg(msg2);
    enforce(rc == 0);

    rc = sr.receivemsg(&msg3);
    enforce(rc == 0);

    enforce( msg3.length == 27 && msg3.header_length == 0 );

    auto x6 = msg3.body_trim!string(s.length); 
        enforce(x6 == s);

    log("NNGMessage test 3: realloc");

    NNGMessage *msg4 = new NNGMessage(0);
    
    ubyte[] data = cast(ubyte[])("/dev/urandom".read(8192));
    auto rnd = Random(to!int(timestamp));
    ulong k;
    for(auto i=0; i<128; i++){
        k = uniform(0,8192,rnd);
        msg4.clear();
        msg4.body_append(data[0..k]);
        enforce(msg4.length == k);
    }        

    log("...passed");        

    writeln("Bye!");
    return 0;
}



