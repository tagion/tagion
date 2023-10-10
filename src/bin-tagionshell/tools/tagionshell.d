module tagion.tools.tagionshell;

import std.array : join;
import std.getopt;
import std.file : exists;
import std.stdio : stderr, writeln, writefln;
import core.time;

import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.shell.shelloptions;
import tagion.actor;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import nngd.nngd;

mixin Main!(_main, "shell");

WebData contract_handler ( WebData req, void* ctx ){
    int rc;
    ShellOptions* opt = cast(ShellOptions*) ctx;
    if(req.type != "application/octet-stream"){
        WebData res = { status: nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST, msg: "invalid data type" };    
        return res;
    }
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    s.recvtimeout = msecs(30000);
    rc = s.dial(opt.tagion_sock_addr);
    enforce(rc==0, "contract_handler: socket dial");
    rc = s.send(req.rawdata);
    enforce(rc==0, "contract_handler: send");
    ubyte[4096] buf;
    size_t len = s.receivebuf(buf, 4096);
    s.close(); 
    WebData res = {status: nng_http_status.NNG_HTTP_STATUS_OK, type: "applicaion/octet-stream", rawdata: buf[0..len].idup };
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

    WebApp app = WebApp("ContractProxy", options.contract_endpoint, parseJSON("{}"), &options);

    app.route("/api/v1/contract", &contract_handler, ["POST"]);

    app.start();

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
