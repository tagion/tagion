module tagion.tools.tagionshell;

import std.array : join;
import std.getopt;
import std.file : exists;
import std.stdio : stdout, stderr, writeln, writefln;
import std.json;
import std.exception;
import std.concurrency;
import std.format;
import std.conv;
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
import core.thread;

mixin Main!(_main, "shell");

static void writeit(A...)(A a){
    writeln(a);
    stdout.flush();
}



void dart_worker( ShellOptions opt ){
    int rc;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
    s.recvtimeout = msecs(1000);
    s.subscribe("");
    writeit("DS: subscribed");
    while(true){
        rc = s.dial(opt.tagion_subscription);
        if(rc == 0)
            break;
        nng_sleep(100.msecs);    
    }
    writeit("DS: connected");
    while(true){
        Document received_doc = s.receive!(immutable(ubyte[]))();
        writeit(format("DS: received %d bytes", received_doc.length));
    }
}


WebData contract_handler ( WebData req, void* ctx ){
    int rc;
    ShellOptions* opt = cast(ShellOptions*) ctx;
    if(req.type != "application/octet-stream"){
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid data type" };    
        return res;
    }
    writeit(format("WH: contract: with %d bytes for %s",req.rawdata.length, opt.tagion_sock_addr));
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    s.recvtimeout = msecs(10000);
    writeit(format("WH: contract: trying to dial %s", opt.tagion_sock_addr));
    while(true){
        rc = s.dial(opt.tagion_sock_addr);
        if(rc == 0)
            break;
    }
    rc = s.send(req.rawdata);
    if(rc != 0){
        writeit("contract_handler: send: ", nng_errstr(s.errno));
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "socket error" };
        return res;
    }        
    ubyte[4096] buf;
    size_t len = s.receivebuf(buf, 4096);
    if(len == size_t.max && s.errno != 0){
        writeit("contract_handler: recv: ", nng_errstr(s.errno));
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "socket error" };
        return res;
    }
    writeit(format("WH: dart: received %d bytes",len));
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
    writeit(format("WH: dart: with %d bytes for %s",req.rawdata.length, opt.tagion_dart_sock_addr));
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    s.recvtimeout = msecs(60000);
    writeit(format("WH: dart: trying to dial %s", opt.tagion_dart_sock_addr));
    while(true){
        rc = s.dial(opt.tagion_dart_sock_addr);
        if(rc == 0)
            break;
    }
    rc = s.send(req.rawdata);
    if(rc != 0){
        writeit("dart_handler: send: ", nng_errstr(rc));
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "socket error" };
        return res;
    }        
    writeit(format("WH: dart: sent %d bytes",req.rawdata.length));
    ubyte[4096] buf;
    ubyte[] docbuf;
    size_t len = 0, doclen = 0; 
    do { 
        len = s.receivebuf(buf, 4096);
        if(len == size_t.max && s.errno != 0){
            writeit("dart_handler: recv: ", nng_errstr(s.errno));
            WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "socket error" };
            return res;
        }
        writeit(format("WH: dart: received %d bytes",len));
        docbuf ~= buf[0..len];
        doclen += len;
    }while(len > 4095);    
    s.close(); 
    WebData res = {
        status: (doclen>0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT, 
        type: "applicaion/octet-stream", rawdata: (doclen>0) ? docbuf[0..doclen] : null 
    };
    writeit("WH: dart: res ",res);
    return res;
}

WebData i2p_handler ( WebData req, void* ctx ){

    thread_attachThis();
    rt_moduleTlsCtor();

    scope(exit){
        thread_detachThis();
        rt_moduleTlsDtor();
    }
    
    int rc;
    ShellOptions* opt = cast(ShellOptions*) ctx;
    if(req.type != "application/octet-stream"){
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid data type" };    
        return res;
    }
    writeit(format("WH: invoice2pay: with %d bytes",req.rawdata.length));
 
    WalletOptions options;
    auto wallet_config_file = opt.default_i2p_wallet;
    if (wallet_config_file.exists) {
        options.load(wallet_config_file);
    }else{
        writeit("i2p: invalid wallet config: " ~ opt.default_i2p_wallet);
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid wallet config" };    
        return res;
    }
    auto wallet_interface = WalletInterface(options);

    if (!wallet_interface.load) {
        writeit("i2p: Wallet does not exist");
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "wallet does not exist" };    
        return res;
    }
    const flag = wallet_interface.secure_wallet.login(opt.default_i2p_wallet_pin);
    if (!flag) {
        writeit("i2p: Wallet wrong pincode");
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "Faucet invalid pin code" };    
        return res;
    }

    if(!wallet_interface.secure_wallet.isLoggedin){
        writeit("i2p: invalid wallet login");
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid wallet login" };    
        return res;
    }
    
    writeit("Before creating of invoices");

    Document[] requests_to_pay;
    requests_to_pay ~= Document(cast(immutable(ubyte[]))req.rawdata);
    TagionBill[] to_pay;
    import tagion.hibon.HiBONRecord;
    
    foreach (doc; requests_to_pay) {
        if (doc.valid != Document.Element.ErrorCode.NONE){
            WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid document: " };    
            writeln("i2p: invalid document");
            return res;
        }
        if (doc.isRecord!TagionBill) {
            to_pay ~= TagionBill(doc);
        }
        else if (doc.isRecord!Invoice) {
            import tagion.utils.StdTime : currentTime;

            auto read_invoice = Invoice(doc);
            to_pay ~= TagionBill(read_invoice.amount, currentTime, read_invoice.pkey, Buffer.init);
        }
        else {
            WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid faucet request" };    
            return res;
        }
    }

    writeit(to_pay[0].toPretty);

    SignedContract signed_contract;
    TagionCurrency fees;
    const payment_status = wallet_interface.secure_wallet.createPayment(to_pay, signed_contract, fees);
    if (!payment_status.value) {
        writeit("i2p: faucet is empty");
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_INTERNAL_SERVER_ERROR, msg: format("faucet createPayment error: %s", payment_status.msg)};
        return res;
    }

    writeit(signed_contract.toPretty);
    
    const message = wallet_interface.secure_wallet.net.calcHash(signed_contract);
    const contract_net = wallet_interface.secure_wallet.net.derive(message);
    const hirpc = HiRPC(contract_net);
    const hirpc_submit = hirpc.submit(signed_contract);
    wallet_interface.secure_wallet.account.hirpcs ~= hirpc_submit.toDoc;

    auto receiver = sendSubmitHiRPC(options.contract_address, hirpc_submit, contract_net);
    wallet_interface.save(false);

    writeit("i2p: payment sent");   
    WebData res = {
        status: nng_http_status.NNG_HTTP_STATUS_OK, 
        type: "applicaion/octet-stream", rawdata: cast(ubyte[])(receiver.toDoc.serialize)
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
        stderr.writeit(e.msg);
        return 1;
    }

    // if (address !is address.init) {
    //     options.shell_uri = address;

    // }

    if (version_switch) {
        revision_text.writeit;
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

    writeit("\nTagionShell web service\nListening at "
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
