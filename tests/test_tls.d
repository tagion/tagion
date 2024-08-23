import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;

import libnng;


static const string cert =
 "-----BEGIN CERTIFICATE-----\n"
~"MIIDRzCCAi8CFCOIJGs6plMawgBYdDuCRV7UuJuyMA0GCSqGSIb3DQEBCwUAMF8x\n"
~"CzAJBgNVBAYTAlhYMQ8wDQYDVQQIDAZVdG9waWExETAPBgNVBAcMCFBhcmFkaXNl\n"
~"MRgwFgYDVQQKDA9OTkcgVGVzdHMsIEluYy4xEjAQBgNVBAMMCWxvY2FsaG9zdDAg\n"
~"Fw0yMDA1MjMyMzMxMTlaGA8yMTIwMDQyOTIzMzExOVowXzELMAkGA1UEBhMCWFgx\n"
~"DzANBgNVBAgMBlV0b3BpYTERMA8GA1UEBwwIUGFyYWRpc2UxGDAWBgNVBAoMD05O\n"
~"RyBUZXN0cywgSW5jLjESMBAGA1UEAwwJbG9jYWxob3N0MIIBIjANBgkqhkiG9w0B\n"
~"AQEFAAOCAQ8AMIIBCgKCAQEAyPdnRbMrQj9902TGQsmMbG6xTSl9XKbJr55BcnyZ\n"
~"ifsrqA7BbNSkndVw9Qq+OJQIDBTfRhGdG+o9j3h6SDVvIb62fWtwJ5Fe0eUmeYwP\n"
~"c1PKQzOmMFlMYekXiZsx60yu5LeuUhGlb84+csImH+m3NbutInPJcStSq0WfSV6V\n"
~"Nk6DN3535ex66zV2Ms6ikys1vCC434YqIpe1VxUh+IC2widJcLDCxmmJt3TOlx5f\n"
~"9OcKMkxuH4fMAzgjIEpIrUjdb19CGNVvsNrEEB2CShBMgBdqMaAnKFxpKgfzS0JF\n"
~"ulxRGNtpsrweki+j+a4sJXTv40kELkRQS6uB6wWZNjcPywIDAQABMA0GCSqGSIb3\n"
~"DQEBCwUAA4IBAQA86Fqrd4aiih6R3fwiMLwV6IQJv+u5rQeqA4D0xu6v6siP42SJ\n"
~"YMaI2DkNGrWdSFVSHUK/efceCrhnMlW7VM8I1cyl2F/qKMfnT72cxqqquiKtQKdT\n"
~"NDTzv61QMUP9n86HxMzGS7jg0Pknu55BsIRNK6ndDvI3D/K/rzZs4xbqWSSfNfQs\n"
~"fNFBbOuDrkS6/1h3p8SY1uPM18WLVv3GO2T3aeNMHn7YJAKSn+sfaxzAPyPIK3UT\n"
~"W8ecGQSHOqBJJQELyUfMu7lx/FCYKUhN7/1uhU5Qf1pCR8hkIMegtqr64yVBNMOn\n"
~"248fuiHbs9BRknuA/PqjxIDDZTwtDrfVSO/S\n"
~"-----END CERTIFICATE-----\n";

static const string key  =
 "-----BEGIN RSA PRIVATE KEY-----\n"
~"MIIEowIBAAKCAQEAyPdnRbMrQj9902TGQsmMbG6xTSl9XKbJr55BcnyZifsrqA7B\n"
~"bNSkndVw9Qq+OJQIDBTfRhGdG+o9j3h6SDVvIb62fWtwJ5Fe0eUmeYwPc1PKQzOm\n"
~"MFlMYekXiZsx60yu5LeuUhGlb84+csImH+m3NbutInPJcStSq0WfSV6VNk6DN353\n"
~"5ex66zV2Ms6ikys1vCC434YqIpe1VxUh+IC2widJcLDCxmmJt3TOlx5f9OcKMkxu\n"
~"H4fMAzgjIEpIrUjdb19CGNVvsNrEEB2CShBMgBdqMaAnKFxpKgfzS0JFulxRGNtp\n"
~"srweki+j+a4sJXTv40kELkRQS6uB6wWZNjcPywIDAQABAoIBAQCGSUsot+BgFCzv\n"
~"5JbWafb7Pbwb421xS8HZJ9Zzue6e1McHNVTqc+zLyqQAGX2iMMhvykKnf32L+anJ\n"
~"BKgxOANaeSVYCUKYLfs+JfDfp0druMGexhR2mjT/99FSkfF5WXREQLiq/j+dxiLU\n"
~"bActq+5QaWf3bYddp6VF7O/TBvCNqBfD0+S0o0wtBdvxXItrKPTD5iKr9JfLWdAt\n"
~"YNAk2QgFywFtY5zc2wt4queghF9GHeBzzZCuVj9QvPA4WdVq0mePaPTmvTYQUD0j\n"
~"GT6X5j9JhqCwfh7trb/HfkmLHwwc62zPDFps+Dxao80+vss5b/EYZ4zY3S/K3vpG\n"
~"f/e42S2BAoGBAP51HQYFJGC/wsNtOcX8RtXnRo8eYmyboH6MtBFrZxWl6ERigKCN\n"
~"5Tjni7EI3nwi3ONg0ENPFkoQ8h0bcVFS7iW5kz5te73WaOFtpkU9rmuFDUz37eLP\n"
~"d+JLZ5Kwfn2FM9HoiSAZAHowE0MIlmmIEXSnFtqA2zzorPQLO/4QlR+VAoGBAMov\n"
~"R0yaHg3qPlxmCNyLXKiGaGNzvsvWjYw825uCGmVZfhzDhOiCFMaMb51BS5Uw/gwm\n"
~"zHxmJjoqak8JjxaQ1qKPoeY1TJ5ps1+TRq9Wzm2/zGqJHOXnRPlqwBQ6AFllAMgt\n"
~"Rlp5uqb8QJ+YEo6/1kdGhw9kZWCZEEue6MNQjxnfAoGARLkUkZ+p54di7qz9QX+V\n"
~"EghYgibOpk6R1hviNiIvwSUByhZgbvxjwC6pB7NBg31W8wIevU8K0g4plbrnq/Md\n"
~"5opsPhwLo4XY5albkq/J/7f7k6ISWYN2+WMsIe4Q+42SJUsMXeLiwh1h1mTnWrEp\n"
~"JbxK69CJZbXhoDe4iDGqVNECgYAjlgS3n9ywWE1XmAHxR3osk1OmRYYMfJv3VfLV\n"
~"QSYCNqkyyNsIzXR4qdkvVYHHJZNhcibFsnkB/dsuRCFyOFX+0McPLMxqiXIv3U0w\n"
~"qVe2C28gRTfX40fJmpdqN/c9xMBJe2aJoClRIM8DCBIkG/HMI8a719DcGrS6iqKv\n"
~"VeuKAwKBgEgD+KWW1KtoSjCBlS0NP8HjC/Rq7j99YhKE6b9h2slIa7JTO8RZKCa0\n"
~"qbuomdUeJA3R8h+5CFkEKWqO2/0+dUdLNOjG+CaTFHaUJevzHOzIjpn+VsfCLV13\n"
~"yupGzHG+tGtdrWgLn9Dzdp67cDfSnsSh+KODPECAAFfo+wPvD8DS\n"
~"-----END RSA PRIVATE KEY-----\n";




static double timestamp()
{
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec/1e9;
}

static void log(A...)(A a){
    writeln(format("%.6f ",timestamp),a);
}





// [1] #begin push-pull test 


void test1_sender( string url ){
    nng_dialer d;
    nng_tls_config *cfg;    
    nng_socket sock;
    nng_sockaddr sa;
    string s;
    int rc;
    rc = nng_push0_open(&sock);
    assert(rc == 0);
    log( " SS: created");
    rc = nng_socket_set_ms(sock,toStringz(NNG_OPT_SENDTIMEO),1000);
    assert(rc == 0);
    rc = nng_socket_set_int(sock,toStringz(NNG_OPT_SENDBUF),4096);
    assert(rc == 0);
    log( " SS: dialing");
    
    int auth_mode = nng_tls_auth_mode.NNG_TLS_AUTH_MODE_OPTIONAL;
    
    rc = nng_dialer_create(&d, sock, toStringz(url));
    assert(rc == 0);

    rc = nng_dialer_set_int(d, toStringz(NNG_OPT_TLS_AUTH_MODE), nng_tls_auth_mode.NNG_TLS_AUTH_MODE_NONE);
    assert(rc == 0);

    rc = nng_tls_config_alloc(&cfg, nng_tls_mode.NNG_TLS_MODE_CLIENT);
    assert(rc == 0);
    
    rc = nng_tls_config_ca_chain(cfg, toStringz(cert), null);
    assert(rc == 0);

    rc = nng_tls_config_server_name(cfg, toStringz("localhost"));
    assert(rc == 0);

    rc = nng_tls_config_auth_mode(cfg, nng_tls_auth_mode.NNG_TLS_AUTH_MODE_REQUIRED);
    assert(rc == 0);

    rc = nng_tls_config_own_cert(cfg, toStringz(cert), toStringz(key), null);
    assert(rc == 0);
    
    rc = nng_dialer_set_ptr(d, toStringz(NNG_OPT_TLS_CONFIG), cfg); // ???
    assert(rc == 0);

    while(1){
        rc = nng_dialer_start(d, 0);        
        if(rc != 0){
            if(rc == nng_errno.NNG_ECONNREFUSED || rc == nng_errno.NNG_EAGAIN){
                log("SS: retry");
                continue;
            }
        }
        break;
    }
    assert(rc == 0);
    log( " SS: connected");
    int k = 0;
    while(k < 10){
        s = (k==0) ? "<START>" : ((k==9) ? "<END>" : format(">MSG:%d DBL:%d TRL:%d<",k,k*2,k*3));
        auto buf = cast(ubyte[])s.dup;
        rc = nng_send(sock, ptr(buf), s.length+1, 0);
        log("SS sent: ",k," : ",s);
        k++;
        nng_msleep(500);
    }
    log(" SS: bye!");
}

void test1_receiver( string url ){
    nng_tls_config *cfg;    
    nng_listener l;
    nng_socket sock;
    ubyte[4096] buf;
    size_t sz;
    int rc = 0;
    
    int auth_mode = nng_tls_auth_mode.NNG_TLS_AUTH_MODE_OPTIONAL;

    foreach(i;0..4095) buf[i] = 0;
    
    rc = nng_pull0_open(&sock);
    assert(rc == 0);
    log( " RR: created");
    
    rc = nng_listener_create(&l, sock, toStringz(url));
    assert(rc == 0);    

    rc = nng_tls_config_alloc(&cfg, nng_tls_mode.NNG_TLS_MODE_SERVER);
    assert(rc == 0);

    rc = nng_tls_config_own_cert(cfg, toStringz(cert), toStringz(key), null);
    assert(rc == 0);
    
    rc = nng_listener_set_ptr(l, toStringz(NNG_OPT_TLS_CONFIG), cfg); // ???
    assert(rc == 0);

    switch (auth_mode) {
        case nng_tls_auth_mode.NNG_TLS_AUTH_MODE_REQUIRED:
        case nng_tls_auth_mode.NNG_TLS_AUTH_MODE_OPTIONAL:
            rc = nng_tls_config_ca_chain(cfg, toStringz(cert), null);
            assert(rc == 0);
            break;
        default:
            break;
    }
    rc = nng_tls_config_auth_mode(cfg, cast(nng_tls_auth_mode)auth_mode);
    assert(rc == 0);
        
    rc = nng_listener_start(l, 0);
    assert(rc == 0);
    
    rc = nng_socket_set_ms(sock,toStringz(NNG_OPT_RECVTIMEO),1000);
    assert(rc == 0);
    
    log( " RR: listen");
    while(1){
        sz = 4096;
        rc = nng_recv(sock, ptr(buf), &sz, 0);
        if(rc != 0){
            if(rc == nng_errno.NNG_ETIMEDOUT){
                log( " RR: waiting");
                continue;
            }
            if(rc == nng_errno.NNG_EAGAIN){
                log( " RR: interrupted");
                continue;
            }
        }
        assert(rc == 0);
        log( " RR: got bytes:",sz);
        auto s = cast(string)buf[0..sz-1];
        log( " RR: received: ", s);
        if(s == "<END>") break;
    }
    log( " RR: bye!");
}


// [1] #end push-pull test 


int main()
{
    writeln("Hello LIBNNG!");
    
    string uri = "tls+tcp://127.0.0.1:31200";

    writeln("// ERROR TEST");
    for(auto i=1; i<32; i++ ){
        writeln("ERROR: ",i,"  =  ",nng_errstr(i));
    }

    // -- [1] push-pull TLS test
        writeln("\n<TEST01>");
            writeln("TEST01 -------------------- simple push-pull on " ~ uri);
            auto tid01 = spawn(&test1_sender, uri);
            auto tid02 = spawn(&test1_receiver, uri);
            //nng_msleep(50);
            //nng_msleep(2000);
            thread_joinAll();
        writeln("</TEST01>\n");
        


    return 0;
}
