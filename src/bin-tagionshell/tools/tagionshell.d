module tagion.tools.tagionshell;

import std.array : join;
import std.getopt;
import std.file : exists;
import std.stdio : stderr, writeln, writefln;
import std.json;
import std.exception;
import std.concurrency;
import std.format;
import core.time;

import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.shell.shelloptions;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import nngd.nngd;

mixin Main!(_main, "shell");

void dart_worker( ShellOptions opt ){
    int rc;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
    s.recvtimeout = msecs(1000);
    s.subscribe("");
    writeln("DS: subscribed");
    while(true){
        rc = s.dial(opt.tagion_subscription);
        if(rc == 0)
            break;
        nng_sleep(100.msecs);    
    }
    writeln("DS: connected");
    while(true){
        Document received_doc = s.receive!(immutable(ubyte[]))();
        writeln(format("DS: received %d bytes", received_doc.length));
    }
}


WebData contract_handler ( WebData req, void* ctx ){
    int rc;
    ShellOptions* opt = cast(ShellOptions*) ctx;
    if(req.type != "application/octet-stream"){
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid data type" };    
        return res;
    }
    writeln(format("WH: contract: with %d bytes for %s",req.rawdata.length, opt.tagion_sock_addr));
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    s.recvtimeout = msecs(10000);
    writeln(format("WH: contract: trying to dial %s", opt.tagion_sock_addr));
    while(true){
        rc = s.dial(opt.tagion_sock_addr);
        if(rc == 0)
            break;
    }
    rc = s.send(req.rawdata);
    if(rc != 0){
        writeln("contract_handler: send: ", nng_errstr(s.errno));
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "socket error" };
        return res;
    }        
    ubyte[4096] buf;
    size_t len = s.receivebuf(buf, 4096);
    if(len == size_t.max && s.errno != 0){
        writeln("contract_handler: recv: ", nng_errstr(s.errno));
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "socket error" };
        return res;
    }
    writeln(format("WH: dart: received %d bytes",len));
    s.close(); 
    WebData res = {
        status: (len>0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT, 
        type: "applicaion/octet-stream", rawdata: (len>0) ? buf[0..len] : null 
    };
    return res;
}

WebData dart_handler ( WebData req, void* ctx ){
    int rc;
    ShellOptions* opt = cast(ShellOptions*) ctx;
    if(req.type != "application/octet-stream"){
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid data type" };    
        return res;
    }
    writeln(format("WH: dart: with %d bytes for %s",req.rawdata.length, opt.tagion_dart_sock_addr));
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    s.recvtimeout = msecs(10000);
    writeln(format("WH: dart: trying to dial %s", opt.tagion_dart_sock_addr));
    while(true){
        rc = s.dial(opt.tagion_dart_sock_addr);
        if(rc == 0)
            break;
    }
    rc = s.send(req.rawdata);
    if(rc != 0){
        writeln("dart_handler: send: ", nng_errstr(rc));
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "socket error" };
        return res;
    }        
    writeln(format("WH: dart: sent %d bytes",req.rawdata.length));
    ubyte[4096] buf;
    ubyte[] docbuf;
    size_t len = 0, doclen = 0; 
    do { 
        len = s.receivebuf(buf, 4096);
        if(len == size_t.max && s.errno != 0){
            writeln("dart_handler: recv: ", nng_errstr(s.errno));
            WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "socket error" };
            return res;
        }
        writeln(format("WH: dart: received %d bytes",len));
        docbuf ~= buf[0..len];
        doclen += len;
    }while(len > 4095);    
    s.close(); 
    WebData res = {
        status: (doclen>0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT, 
        type: "applicaion/octet-stream", rawdata: (doclen>0) ? docbuf[0..doclen] : null 
    };
    writeln("WH: dart: res ",res);
    return res;
}


int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    GetoptResult main_args;

    ShellOptions options;

    auto config_file = "shell.json";
    if (config_file.exists) {
        options.load(config_file);
    }
    else {
        options.setDefault;
    }

    try {
        main_args = getopt(args, std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
        );
    }
    catch (GetOptException e) {
        stderr.writeln(e.msg);
        return 1;
    }

    if (version_switch) {
        revision_text.writeln;
        return 0;
    }
    if (main_args.helpWanted) {
        const option_info = format("%s [<option>...] <config.json> <files>", program);

        defaultGetoptPrinter(
                [
                // format("%s version %s", program, REVNO),
                "Documentation: https://tagion.org/",
                "",
                "Usage:",
                format("%s [<option>...] <config.json> <files>", program),
                "",
                "<option>:",

                ].join("\n"),
                main_args.options);
        return 0;
    }

    //auto ds_tid = spawn(&dart_worker, options);


    WebApp app = WebApp("ShellApp", options.shell_uri, parseJSON("{}"), &options);

    app.route(options.shell_api_prefix~options.contract_endpoint, &contract_handler, ["POST"]);
    app.route(options.shell_api_prefix~options.dart_endpoint, &dart_handler, ["POST"]);

    app.start();

    writeln("\nTagionShell web service\nListening at "
        ~options.shell_uri~"\n\t"
        ~options.shell_api_prefix
        ~options.contract_endpoint
        ~"\t= POST contract hibon\n\t"
        ~options.shell_api_prefix
        ~options.dart_endpoint
        ~"\t\t= POST dart request hibon\n"

    );

    while(true)
        nng_sleep(1000.msecs);


    // NNGSocket sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
    // sock.sendtimeout = msecs(1000);
    // sock.sendbuf = 4096;
    // int rc = sock.dial(options.tagion_sock_addr);
    // assert(rc == 0, format("Failed to dial %s", rc));
    // auto hibon = new HiBON();
    // hibon["$test"] = 5;
    // writefln("Buf lenght %s %s", hibon.serialize.length, Document(hibon.serialize).valid);

    // rc = sock.send(hibon.serialize);
    // assert(rc == 0, format("Failed to send %s", rc));

    return 0;
}
