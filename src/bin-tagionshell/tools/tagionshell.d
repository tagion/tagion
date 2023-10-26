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
import tagion.hibon.HiBONFile : fread, fwrite;

import tagion.script.common;
import tagion.script.TagionCurrency;

import tagion.basic.Types : FileExtension, Buffer, hasExtension;
import tagion.basic.range : doFront;

import tagion.utils.StdTime : currentTime;

import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;

import tagion.tools.wallet.WalletOptions;
import tagion.tools.wallet.WalletInterface;

import tagion.communication.HiRPC;
import tagion.wallet.SecureWallet;
import tagion.wallet.AccountDetails;


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
    s.recvtimeout = msecs(60000);
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

WebData i2p_handler ( WebData req, void* ctx ){
    int rc;
    ShellOptions* opt = cast(ShellOptions*) ctx;
    if(req.type != "application/octet-stream"){
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid data type" };    
        return res;
    }
    writeln(format("WH: invoice2pay: with %d bytes",req.rawdata.length));
 
    WalletOptions options;
    auto wallet_config_file = opt.default_i2p_wallet ~ "/wallet.json";
    if (wallet_config_file.exists) {
        options.load(wallet_config_file);
    }else{
        writeln("i2p: invalid wallet dir");
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid wallet dir" };    
        return res;
    }
    auto wallet_interface = WalletInterface(options);
    SecureWallet!StdSecureNet secure_wallet;
    const wallet_doc = (opt.default_i2p_wallet ~ "/" ~ options.walletfile).fread;
    const pin_doc = (opt.default_i2p_wallet ~ "/" ~ options.devicefile).exists ? (opt.default_i2p_wallet ~ "/" ~ options.devicefile).fread : Document.init;
    if (wallet_doc.isInorder && pin_doc.isInorder) {
        secure_wallet = WalletInterface.StdSecureWallet(wallet_doc, pin_doc);
        secure_wallet.login(opt.default_i2p_wallet_pin);
    }else{
        writeln("i2p: invalid wallet load");
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid wallet load" };    
        return res;
    }   
    if(!secure_wallet.isLoggedin){
        writeln("i2p: invalid wallet login");
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid wallet login" };    
        return res;
    }
    
    Invoice[] invoices;
    invoices ~=  Invoice(Document(cast(immutable(ubyte[]))req.rawdata));

    SignedContract signed_contract;
    TagionCurrency fees;
    secure_wallet.payment(invoices, signed_contract, fees);
    const message = secure_wallet.net.calcHash(signed_contract);
    const contract_net = secure_wallet.net.derive(message);
    const hirpc = HiRPC(contract_net);
    const hirpc_submit = hirpc.submit(signed_contract);
    secure_wallet.account.hirpcs ~= hirpc_submit.toDoc;

    sendSubmitHiRPC(options.contract_address, hirpc_submit, contract_net);

    writeln("i2p: payment sent");   

    WebData res = {
        status: nng_http_status.NNG_HTTP_STATUS_OK, 
        type: "applicaion/octet-stream", rawdata: cast(ubyte[])(hirpc_submit.toDoc.serialize)
    };
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
    string address;

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

    // if (address !is address.init) {
    //     options.shell_uri = address;

    // }

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
    app.route(options.shell_api_prefix~options.i2p_endpoint, &i2p_handler, ["POST"]);

    app.start();

    writeln("\nTagionShell web service\nListening at "
        ~options.shell_uri~"\n\t"
        ~options.shell_api_prefix
        ~options.contract_endpoint
        ~"\t= POST contract hibon\n\t"
        ~options.shell_api_prefix
        ~options.dart_endpoint
        ~"\t\t= POST dart request hibon\n\t"
        ~options.shell_api_prefix
        ~options.i2p_endpoint
        ~"\t= POST invoice-to-pay hibon\n\t"

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
