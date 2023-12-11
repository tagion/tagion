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

static void api_handler1 ( WebData *req, WebData *rep, void* ctx ){
    rep.text =  "REPLY TO: "~to!string(req);
    rep.type =  "text/plain";
    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
}

static void api_handler2 ( WebData *req, WebData *rep, void* ctx ){
    JSONValue data = parseJSON("{}");
    if(req.method == "GET"){
        data["replyto"] = "REPLY TO: "~to!string(req);
        rep.json = data;
        rep.type = "application/json";
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        return;
    }
    if(req.method == "POST"){
        if(req.type == "application/octet-stream"){
            data["datalength"] = req.rawdata.length;
            data["datatype"] = req.type;
            rep.json = data,
            rep.type = "application/json",
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            return;
        }else{
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "Invalid request";
            return;
        }
    }
}


int
main()
{
    int rc;
    const wd = dirName(thisExePath());

    WebApp app = WebApp("myapp", "https://localhost:8081", parseJSON(`{"root_path":"`~wd~`/../../webapp","static_path":"static"}`), null);
    
    version(withtls){
        WebTLS tls = WebTLS(nng_tls_mode.NNG_TLS_MODE_SERVER);    
        tls.set_server_name("localhost");
        tls.set_auth_mode(nng_tls_auth_mode.NNG_TLS_AUTH_MODE_NONE);
        tls.set_version(nng_tls_version.NNG_TLS_1_0, nng_tls_version.NNG_TLS_1_3);
        writeln(wd~"/../../ssl/cert.crt");
        tls.set_cert_key_file(wd~"/../../ssl/cert.crt", wd~"/../../ssl/key.key");
        app.set_tls(tls);
    }

    app.route("/api/v1/test1",&api_handler1);
    app.route("/api/v1/test2/*",&api_handler2,["GET","POST"]);

    app.start();
    
    writeln(`
        Consider tests:

        curl https://localhost:8081/api/v1/test1
        curl https://localhost:8081/api/v1/test2/a/b/c?x=y
        curl -X POST -H "Content-Type: application/octet-stream" -d @file.bin https://localhost:8081/api/v1/test2

    `);


    while(true){
        nng_sleep(1000.msecs);
    }

    log("...passed");        

    writeln("Bye!");
    return 0;
}



