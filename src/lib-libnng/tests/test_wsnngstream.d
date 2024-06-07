import std.stdio;
import std.conv;
import std.file;
import std.path;
import std.string;
import std.json;
import std.concurrency;
import std.exception;
import core.thread;
import std.datetime.systime;
import core.stdc.stdlib : exit;

import libnng;

shared string _WD;

static double timestamp()
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static void log(A...)(A a){
    writeln(format("%.6f ",timestamp),a);
}



int main()
{
    int rc;
    
    const uri = "ws://0.0.0.0:8098/wtest";

    nng_stream_listener *l;
    nng_aio *ac; 
    nng_aio *am;
    nng_stream *s;
    nng_iov iov;
    ubyte[4096] buf;
    
    JSONValue jdata;

    int i, k;


    rc = nng_stream_listener_alloc(&l, uri.toStringz());
    enforce(rc==0, "e5");


    rc = nng_stream_listener_set_bool(l, toStringz(NNG_OPT_WS_RECV_TEXT), true);
    enforce(rc==0, "e6");
    rc = nng_stream_listener_set_bool(l, toStringz(NNG_OPT_WS_SEND_TEXT), true);
    enforce(rc==0, "e6");


    rc = nng_stream_listener_listen(l);
    enforce(rc==0, "e7");
    
    rc = nng_aio_alloc( &ac, null, null );
    enforce(rc==0, "e1");

    rc = nng_aio_alloc( &am, null, null );
    enforce(rc==0, "e2");

    nng_aio_set_timeout( ac, 15000 );
    nng_aio_set_timeout( am, 15000 );

    nng_stream_listener_accept(l, ac);
    
    nng_aio_wait(ac);
    rc = nng_aio_result(ac);
    if(rc != 0){
        log("e9 resuult ", rc);
        nng_aio_finish(ac, rc);
        return 1;
    }

    s = cast(nng_stream*)nng_aio_get_output(ac, 0);
    enforce(s != null, "e10");
    
    nng_aio_finish(ac, 0);
    
    k = 0;
    while(true){
        log("ITER: ", k);
        

        iov.iov_buf = buf.ptr;
        iov.iov_len = 4096;
        rc = nng_aio_set_iov(am, 1, &iov);
        enforce(rc==0, "e11");
        log("WAIT FOR DATA");
        nng_stream_recv(s, am);
        
        nng_aio_wait(am);
        rc = nng_aio_result(am);
        if(rc != 0){
            log("e12 result ", rc);
            nng_aio_finish(am, rc);
            continue;
        }
        
        auto sz = nng_aio_count(am);
        log("RECV: [", sz, "]");

        auto rs = cast(string)(buf[0..sz].dup);

        log("RECV: ", rs);

        for(i=0; i<8; i++){
            jdata = parseJSON("{}");
            jdata["time"] = timestamp();
            jdata["index"] = i;
            jdata["request"] = rs;

            auto js = jdata.toString();
            buf[0..js.length] = cast(ubyte[])js[0..js.length];
            iov.iov_len = js.length;
            rc = nng_aio_set_iov(am, 1, &iov);
            enforce(rc==0, "e13");

            nng_stream_send(s, am);
            nng_aio_wait(am);
            rc = nng_aio_result(am);
            if(rc != 0){
                log("e14 resuult ", rc);
                nng_aio_finish(am, rc);
                break; 
            }
            

            log(format("SENT[%d]: %d ", i, js.length));
        }   
        k++;
    }
    nng_aio_finish(am, 0);
    return 0;
}


