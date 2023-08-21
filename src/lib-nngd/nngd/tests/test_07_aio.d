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

extern (C) void scb ( void* p ){
    NNGAio* aio = cast(NNGAio*)p;
    log("Send callback");
    writeln("Send callback fired pointer: ", p);
    int res = aio.result;
    size_t cnt = aio.count;
    writeln("Send callback fired with result: ", res, " : ", cnt );
}

extern (C) void rcb ( void* p ){
    NNGAio* aio = cast(NNGAio*)p;
    log("Receive callback");
    writeln("Receive callback fired pointer: ", p);
    int res = aio.result;
    size_t cnt = aio.count;
    writeln("Receive callback fired with result: ", res, " : ", cnt );

    NNGMessage msg = NNGMessage(0);
    auto rc = aio.get_msg(&msg);
    assert(rc == 0);

    writeln("Received message: ", msg.length, " : ", msg.header_length);
    assert( msg.length == 27 && msg.header_length == 0 );

    auto x = msg.body_trim!string(13); 
        writeln("Received string: ",x);
}


int
main()
{
    int rc;
    string s = "AbAbAgAlAmAgA";

    log("NNGAio test 1: socket level send-receive");

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
    
    NNGAio saio = NNGAio(null, null);
    NNGAio raio = NNGAio(null, null); 
    saio.realloc( &scb, &saio );
    raio.realloc( &rcb, &raio );

    log("AIO allocated");

    saio.timeout = msecs(1000);
    raio.timeout = msecs(1000);

    saio.set_msg(msg2);

    ss.sendaio(saio);

    log("AIO send started");

    sr.receiveaio(raio);
    
    log("AIO receive started");

    
    saio.wait();
    raio.wait();

    log("AIO wait completed");


    nng_sleep(msecs(1000));

    log("...passed");        

    writeln("Bye!");
    return 0;
}



