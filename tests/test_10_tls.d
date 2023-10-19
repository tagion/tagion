import std.stdio;
import std.conv;
import std.string;
import std.concurrency;
import core.thread;
import std.datetime.systime;
import std.uuid;
import std.regex;
import std.json;

import nngd;
import nngtestutil;

static WebData api_handler1 ( WebData req, void* ctx ){
    WebData rep = {
        text: "REPLY TO: "~to!string(req),
        type: "text/plain",
        status: nng_http_status.NNG_HTTP_STATUS_OK
    };
    return rep;
}

static WebData api_handler2 ( WebData req, void* ctx ){
    JSONValue data = parseJSON("{}");
    if(req.method == "GET"){
        data["replyto"] = "REPLY TO: "~to!string(req);
        WebData rep = {
            json: data,
            type: "application/json",
            status: nng_http_status.NNG_HTTP_STATUS_OK
        };
        return rep;
    }
    if(req.method == "POST"){
        data["datalength"] = req.rawdata.length;
        data["datatype"] = req.type;
        WebData rep = {
            json: data,
            type: "application/json",
            status: nng_http_status.NNG_HTTP_STATUS_OK
        };
        return rep;
    }
    return WebData();
}


int
main()
{
    int rc;
    string wd = thisExePath();

    WebApp app = WebApp("myapp", "https://localhost:8081", parseJSON(`{"root_path":"`~wd~`/../../webapp","static_path":"static"}`), null);
    
    WebTLS tls = WebTLS(nng_tls_mode.NNG_TLS_MODE_SERVER);    
    tls.set_server_name("localhost");
    tls.set_cert_key_file(wd~"/../ssl/../cert.pem", wd~"/../../ssl/key.pem");

    app.set_tls(tls);

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



