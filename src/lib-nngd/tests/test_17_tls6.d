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
import std.exception;

import nngd;
import nngtestutil;

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


const NSTEPS = 9;

void sender_worker(string url)
{
    int k = 0;
    string line;
    int rc;
    thread_attachThis();
    rt_moduleTlsCtor();
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
    s.sendtimeout = msecs(1000);
    s.sendbuf = 4096;
    
    rc = s.dialer_create(url);
    if(rc != 0){
        error("Dialer create: %s", nng_errstr(rc));        
    }    

    NNGTLS tls = NNGTLS(nng_tls_mode.NNG_TLS_MODE_CLIENT);
    tls.set_ca_chain(cert);
    tls.set_server_name("localhost");
    tls.set_auth_mode(nng_tls_auth_mode.NNG_TLS_AUTH_MODE_NONE);

    log(tls.toString());

    rc = s.dialer_set_tls(&tls);
    if(rc != 0){
        error("Dialer set TLS: %s", nng_errstr(rc));        
    }    

    while(1){
        log("SS: to dial...");
        rc = s.dialer_start();
        if(rc == 0) break;
        error("SS: Dial error: %s", nng_errstr(rc));
        if(rc == nng_errno.NNG_ECONNREFUSED){
            nng_sleep(msecs(100));
            continue;
        }
        enforce(rc == 0);
    }

    log(nngtest_socket_properties(s,"sender"));
    while(1){
        line = format(">MSG:%d DBL:%d TRL:%d<",k,k*2,k*3);
        if(k > NSTEPS) line = "END";
        auto buf = cast(ubyte[])line.dup;
        rc = s.send!(ubyte[])(buf);
        enforce(rc == 0);
        log("SS sent: ",k," : ",line);
        k++;
        nng_sleep(msecs(500));
        if(k > NSTEPS + 1) break;
    }
    log(" SS: bye!");
}


void receiver_worker(string url)
{
    int rc;
    ubyte[4096] buf;
    size_t sz = buf.length;
    thread_attachThis();
    rt_moduleTlsCtor();
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PULL);
    s.recvtimeout = msecs(1000);
    
    rc = s.listener_create(url);
    if(rc != 0){
        error("Listener create: %s", rc);        
    }    

    NNGTLS tls = NNGTLS(nng_tls_mode.NNG_TLS_MODE_SERVER);
    tls.set_auth_mode(nng_tls_auth_mode.NNG_TLS_AUTH_MODE_NONE);
    tls.set_own_cert(cert, key);

    log(tls.toString());

    rc = s.listener_set_tls(&tls);
    if(rc != 0){
        error("Listener set TLS: %s", rc);        
    }    

    rc = s.listener_start();
    log("RR: listening");
    enforce(rc == 0);
    bool _ok = false;
    int k = 0;
    log(nngtest_socket_properties(s,"receiver"));
    while(1){
        if(k++ > NSTEPS + 3) break;
        sz = s.receivebuf(buf, buf.length);
        if(sz < 0 || sz == size_t.max){
            error("REcv error: " ~ nng_errstr(s.errno));
            continue;
        }
        auto str = cast(string)buf[0..sz];
        log("RR: GOT["~(to!string(sz))~"]: >"~str~"<");
        if(str == "END"){
            _ok = true;
            break;
        }    
    }
    if(!_ok){
        error("Test stopped without normal end.");
    }
    log(" RR: bye!");
}


int main()
{
    log("Hello NNGD!");
    log("TLS+TCP6 push-pull test with byte buffers");

    string server_uri = "tls+tcp6://[::]:31217";
    string client_uri = "tls+tcp6://[::1]:31217";

    auto tid01 = spawn(&receiver_worker, server_uri);
    Thread.sleep(100.msecs);
    auto tid02 = spawn(&sender_worker, client_uri);
    thread_joinAll();

    return populate_state(17, "TLS+TCP6 encrypted push-pull socket pair");
}



