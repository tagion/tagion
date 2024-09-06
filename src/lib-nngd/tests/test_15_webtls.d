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
import std.process;

import nngd;
import nngtestutil;

static void api_handler1 ( WebData *req, WebData *rep, void* ctx ){
    try{
        thread_attachThis();
        rep.text =  to!string((*req).toJSON("handler1"));
        rep.type =  "text/plain";
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
    } catch(Throwable e) {
        error(dump_exception_recursive(e, "Handler - 1"));
    }
}

static void api_handler2 ( WebData *req, WebData *rep, void* ctx ){
    JSONValue data = parseJSON("{}");
    if(req.method == "GET"){
        data["replyto"] = (*req).toJSON("handler2");
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
    version(withtls){
        int rc;
        const wd = dirName(thisExePath());
        
        NNGTLS tls = NNGTLS(nng_tls_mode.NNG_TLS_MODE_SERVER);    
        
        try {
            
            //tls.set_server_name("localhost");
            tls.set_auth_mode(nng_tls_auth_mode.NNG_TLS_AUTH_MODE_NONE);
            try { tls.set_version(nng_tls_version.NNG_TLS_1_0, nng_tls_version.NNG_TLS_1_0); log("TLS ver 1.0 1.0 ok"); } catch(Throwable e) { log("TLS ver 1.0 1.0 FAIL"); }
            try { tls.set_version(nng_tls_version.NNG_TLS_1_0, nng_tls_version.NNG_TLS_1_1); log("TLS ver 1.0 1.1 ok"); } catch(Throwable e) { log("TLS ver 1.0 1.1 FAIL"); }
            try { tls.set_version(nng_tls_version.NNG_TLS_1_0, nng_tls_version.NNG_TLS_1_2); log("TLS ver 1.0 1.2 ok"); } catch(Throwable e) { log("TLS ver 1.0 1.2 FAIL"); }
            try { tls.set_version(nng_tls_version.NNG_TLS_1_0, nng_tls_version.NNG_TLS_1_3); log("TLS ver 1.0 1.3 ok"); } catch(Throwable e) { log("TLS ver 1.0 1.3 FAIL"); }
            try { tls.set_version(nng_tls_version.NNG_TLS_1_1, nng_tls_version.NNG_TLS_1_1); log("TLS ver 1.1 1.1 ok"); } catch(Throwable e) { log("TLS ver 1.1 1.1 FAIL"); }
            try { tls.set_version(nng_tls_version.NNG_TLS_1_1, nng_tls_version.NNG_TLS_1_2); log("TLS ver 1.1 1.2 ok"); } catch(Throwable e) { log("TLS ver 1.1 1.2 FAIL"); }
            try { tls.set_version(nng_tls_version.NNG_TLS_1_1, nng_tls_version.NNG_TLS_1_3); log("TLS ver 1.1 1.3 ok"); } catch(Throwable e) { log("TLS ver 1.1 1.3 FAIL"); }
            try { tls.set_version(nng_tls_version.NNG_TLS_1_2, nng_tls_version.NNG_TLS_1_2); log("TLS ver 1.2 1.2 ok"); } catch(Throwable e) { log("TLS ver 2.1 1.2 FAIL"); }
            try { tls.set_version(nng_tls_version.NNG_TLS_1_2, nng_tls_version.NNG_TLS_1_3); log("TLS ver 1.2 1.3 ok"); } catch(Throwable e) { log("TLS ver 2.1 1.3 FAIL"); }

            tls.set_cert_key_file(wd~"/../../ssl/certkey.pem", null);
        
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "TLS config"));
        }
        
        try {

            WebApp app = WebApp("myapp", "https://localhost:8089", parseJSON(`{"root_path":"`~wd~`/../../../webapp","static_path":"static"}`), null);
            app.set_tls(&tls);

            app.route("/api/v1/test1/*",&api_handler1);
            app.route("/api/v1/test2/*",&api_handler2,["GET","POST"]);

            app.start();
        
        } catch(Throwable e) {
            error(dump_exception_recursive(e, "Server start"));
        }
        
        log(`
            Consider tests:

            curl -k https://localhost:8089/api/v1/test1
            curl -k https://localhost:8089/api/v1/test2/a/b/c?x=y
            curl -k -X POST -H "Content-Type: application/octet-stream" -d @file.bin https://localhost:8089/api/v1/test2

        `);

        try {

            {
                auto res = executeShell("curl -k -s https://localhost:8089/static | grep -q 'NNG HTTP TEST'");
                assert(res.status == 0, "on static file");
            }

            {
                auto res = executeShell("curl -k -s https://localhost:8089/api/v1/test1/a/b/c/?x=y");
                assert(res.status == 0);
                auto jres = parseJSON(res.output);
                assert(jres["#TAG"].str == "handler1");
                assert(jres["path"][2].str == "test1" );
                assert(jres["param"]["x"].str == "y" );
            }

            {
                auto res = executeShell("curl -k -s https://localhost:8089/api/v1/test2/a/b/c/?x=y");
                assert(res.status == 0);
                auto jres = parseJSON(res.output);
                assert(jres["replyto"]["#TAG"].str == "handler2");
                assert(jres["replyto"]["path"][2].str == "test2" );
                assert(jres["replyto"]["param"]["x"].str == "y" );
            }

            {
                auto drc = executeShell("dd if=/dev/urandom of=file.bin count=1 bs=1048576");
                assert(drc.status == 0);
                auto res = executeShell("curl -k -s -X POST -H \"Content-Type: application/octet-stream\" --data-bin @file.bin https://localhost:8089/api/v1/test2");
                assert(res.status == 0);
                auto jres = parseJSON(res.output);
                assert(jres["datalength"].integer == 1048576);
                assert(jres["datatype"].str == "application/octet-stream" );
            }

        } catch(Throwable e) {
            error(dump_exception_recursive(e, "Endpoint tests"));
        }

    } else {
        log("TLS test to skip...");
    }
   
   return populate_state(15, "TLS webserver tests");
}



