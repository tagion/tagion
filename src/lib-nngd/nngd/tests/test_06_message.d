import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.regex;

import nngd;
import nngtestutil;


int
main()
{
    int rc;
    string s = "AbAbAgAlAmAgA";

    log("NNGMessage test 1: assembly-disassembly");

    NNGMessage msg1 = NNGMessage(0);
    
    rc = msg1.body_append!ushort(11);  assert(rc == 0);
    rc = msg1.body_append!uint(12);    assert(rc == 0);
    rc = msg1.body_append!ulong(13);   assert(rc == 0);
    rc = msg1.body_prepend(cast(ubyte[])s); assert(rc == 0);
    
    assert( msg1.length == 27 && msg1.header_length == 0 );

    auto x1 = msg1.body_chop!ulong(); 
        assert(x1 == 13);
    auto x2 = msg1.body_chop!uint(); 
        assert(x2 == 12);
    auto x3 = msg1.body_chop!ushort(); 
        assert(x3 == 11);
    auto x4 = msg1.body_trim!(ubyte[])(); 
        string x5 = cast(string)x4;
        assert(x5 == s);
    
    assert( msg1.length == 0 && msg1.header_length == 0 );

    log("...passed");        
    
    log("NNGMessage test 2: send-receive");

    string url = "tcp://127.0.0.1:13003";

    NNGSocket sr = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
    sr.recvtimeout = msecs(1000);
    rc = sr.listen(url);
    assert(rc == 0);
    NNGSocket ss = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
    ss.sendtimeout = msecs(1000);
    ss.sendbuf = 4096;
    rc = ss.dial(url);
    assert(rc == 0);
    
    NNGMessage msg2 = NNGMessage(0);
    rc = msg2.body_append!ushort(11);  assert(rc == 0);
    rc = msg2.body_append!uint(12);    assert(rc == 0);
    rc = msg2.body_append!ulong(13);   assert(rc == 0);
    rc = msg2.body_prepend(cast(ubyte[])s); assert(rc == 0);
    NNGMessage msg3 = NNGMessage(0);
    
    rc = ss.sendmsg(msg2);
    assert(rc == 0);

    rc = sr.receivemsg(&msg3);
    assert(rc == 0);

    assert( msg3.length == 27 && msg3.header_length == 0 );

    auto x6 = msg3.body_trim!string(s.length); 
        assert(x6 == s);


    log("...passed");        

    writeln("Bye!");
    return 0;
}



