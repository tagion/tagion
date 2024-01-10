module tagion.tools.tagionshell;

import core.time;
import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.file : exists;
import std.format;
import std.getopt;
import std.json;
import std.string : representation;
import std.stdio : File, stderr, stdout, writefln, writeln;
import std.datetime.systime: Clock;
import tagion.basic.Types : Buffer, FileExtension, hasExtension;
import tagion.basic.range : doFront;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.shell.shelloptions;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions;
import tagion.utils.StdTime : currentTime;
import tagion.wallet.AccountDetails;
import tagion.wallet.SecureWallet;
import tagion.utils.LRUT;

import core.thread;
import nngd.nngd;

mixin Main!(_main, "shell");

alias LRUT!(Buffer, TagionBill) DartCache;

shared DartCache dcache;

long getmemstatus() {
    long sz = -1;
    auto f = File("/proc/self/status", "rt");
    foreach (line; f.byLine) {
        if (line.startsWith("VmRSS")) {
            sz = to!long(line.split()[1]);
            break;
        }
    }
    f.close();
    return sz;
}

void writeit(A...)(A a) {
    writeln(a);
    stdout.flush();
}

string dump_exception_recursive(Throwable t, string tag = ""){
    string[] res;
    res ~= format("\r\n<h2>Exception caught in TagionShell %s %s</h2>\r\n",Clock.currTime().toSimpleString(),tag);
    do {
        res ~= format("<code>\r\n<h3>%s [%d]: %s </h3>\r\n<pre>\r\n%s\r\n</pre>\r\n</code>\r\n",t.file,t.line,t.msg,t.info);
    } while((t = t.next) !is null);
    return join(res, "\r\n");
}    

void dart_worker(ShellOptions opt) {
    int rc;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
    s.recvtimeout = msecs(1000);
    s.subscribe("");
    writeit("DS: subscribed");
    while (true) {
        rc = s.dial(opt.tagion_subscription_addr);
        if (rc == 0)
            break;
    }
    scope (exit) {
        s.close;
    }
    writeit("DS: connected");
    while (true) {
        Document received_doc = s.receive!(immutable(ubyte[]))();
        writeit(format("DS: received %d bytes", received_doc.length));
    }
}

void contract_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    try {
        int rc;
        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != "application/octet-stream") {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }

        const contract_addr = opt.node_contract_addr;

        writeit(format("WH: contract: with %d bytes for %s", req.rawdata.length, contract_addr));
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        s.recvtimeout = msecs(10000);
        writeit(format("WH: contract: trying to dial %s", contract_addr));
        while (true) {
            rc = s.dial(contract_addr);
            if (rc == 0)
                break;
        }
        scope (exit) {
            s.close();
        }
        rc = s.send(req.rawdata);
        if (rc != 0) {
            writeit("contract_handler: send: ", nng_errstr(s.errno));
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "socket error";
            return;
        }
        ubyte[4096] buf;
        size_t len = s.receivebuf(buf, 4096);
        if (len == size_t.max && s.errno != 0) {
            writeit("contract_handler: recv: ", nng_errstr(s.errno));
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "socket error";
            return;
        }
        writeit(format("WH: dart: received %d bytes", len));
        rep.status = (len > 0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT;
        rep.type = "applicaion/octet-stream";
        rep.rawdata = (len > 0) ? buf[0 .. len] : null;
    }catch(Throwable e){
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.msg;
        rep.text = dump_exception_recursive(e, "handler: contract");
        return;
    }
}

import crud = tagion.dart.DARTcrud;

static void bullseye_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    try {
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);

        int rc;
        ShellOptions* opt = cast(ShellOptions*) ctx;
        while (true) {
            rc = s.dial(opt.node_dart_addr);
            if (rc == 0)
                break;
        }
        scope (exit) {
            s.close();
        }

        rc = s.send(crud.dartBullseye.toDoc.serialize);
        ubyte[192] buf;
        size_t len = s.receivebuf(buf, buf.length);
        if (len == size_t.max && s.errno != 0) {
            writeit("bullseye_handler: recv: ", nng_errstr(s.errno));
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "socket error";
            return;
        }

        const receiver = HiRPC(null).receive(Document(buf.idup));
        if (!receiver.isResponse) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "response error";
            return;
        }

        const dartindex = parseJSON(receiver.toPretty);

        rep.status = (len > 0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT;
        rep.type = "application/json";
        rep.json = dartindex;
    }catch(Throwable e){
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.msg;
        rep.text = dump_exception_recursive(e, "handler: bullseye");
        return;
    }
}

static void dartcache_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    try {
        int rc;
        size_t nfound = 0, nreceived = 0;
        const size_t buflen = 1048576;
        ubyte[1048576] buf;
        immutable(ubyte)[] docbuf;

        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != "application/octet-stream") {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }

        SecureNet net = new StdSecureNet();
        net.generateKeyPair("very_secret");
        HiRPC hirpc = HiRPC(net);
        Document doc = Document(cast(immutable(ubyte[])) req.rawdata);
        immutable receiver = hirpc.receive(doc);
        auto pkey_doc = receiver.method.params;
        Buffer[] owner_pkeys;
        foreach (owner; pkey_doc[]) {
            owner_pkeys ~= owner.get!Buffer;
        }

        TagionBill[] found_bills;

        TagionBill fnd;
        foreach (owner; owner_pkeys) {
            if (dcache.get(owner, fnd)) {
                found_bills ~= fnd;
            }
        }
        
        nfound = found_bills.length;

        // TODO: merge with previous, check array reducing in foreach
        if (!found_bills.empty) {
            foreach (bill; found_bills) {
                remove!(x => x == bill.owner)(owner_pkeys);
            }
        }

        if (!owner_pkeys.empty) {
            auto dreq = new HiBON;
            dreq = owner_pkeys;

            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
            s.recvtimeout = 60_000.msecs;
            while (true) {
                rc = s.dial(opt.node_dart_addr);
                if (rc == 0)
                    break;
            }
            scope (exit) {
                s.close();
            }

            rc = s.send(cast(ubyte[])(hirpc.search(dreq).toDoc.serialize));

            if (rc != 0) {
                writeit("dart_handler: send: ", nng_errstr(rc));
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "socket error";
                return;
            }

            size_t len = 0, doclen = 0;
            do {
                len = s.receivebuf(buf, buflen);
                if (len == size_t.max && s.errno != 0) {
                    writeit("dart_handler: recv: ", nng_errstr(s.errno));
                    rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                    rep.msg = "socket error";
                    return;
                }
                if (len > buflen) {
                    writeit("dart_handler: recv wrong size: ", len);
                    rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                    rep.msg = "socket error";
                    return;
                }
                writeit(format("WH: dart: received %d bytes", len));
                docbuf ~= buf[0 .. len];
                doclen += len;
            }
            while (len > buflen - 1);

            const repdoc = Document(docbuf);
            immutable repreceiver = hirpc.receive(repdoc);
            TagionBill[] received_bills = repreceiver.response.result[]
                .map!(e => TagionBill(e.get!Document))
                .array;

            foreach (bill; received_bills) {
                dcache.update(cast(Buffer) bill.owner, bill, true);
            }

            nreceived = received_bills.length;

            found_bills ~= received_bills;
        }

        writeit("DARTCACHE STAT: ", nfound, " found, ", nreceived, " received");
        // TODO: remove stat and counters or add it to response

        HiBON params = new HiBON;

        foreach (i, bill; found_bills) {
            params[i] = bill.toHiBON;
        }

        Document response = hirpc.result(receiver, params).toDoc;

        rep.status = (found_bills.length > 0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status
            .NNG_HTTP_STATUS_NO_CONTENT;
        rep.type = "applicaion/octet-stream";
        rep.rawdata = (found_bills.length > 0) ? cast(ubyte[])(response.serialize) : null;

        //writeit("WH: dart: res ", response.toPretty);
    }catch(Throwable e){
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.msg;
        rep.text = dump_exception_recursive(e, "handler: dartcache");
        return;
    }
}

static void dart_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    try {
        int rc;
        const size_t buflen = 1048576;
        ubyte[1048576] buf;
        ubyte[] docbuf;
        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != "application/octet-stream") {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }

        const dart_addr = opt.node_dart_addr;

        writeit(format("WH: dart: with %d bytes for %s", req.rawdata.length, dart_addr));
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        s.recvtimeout = 60_000.msecs;
        while (true) {
            rc = s.dial(dart_addr);
            if (rc == 0)
                break;
        }
        scope (exit) {
            s.close();
        }
        rc = s.send(req.rawdata);
        if (rc != 0) {
            writeit("dart_handler: error on send: ", nng_errstr(rc));
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "socket error";
            return;
        }
        writeit(format("WH: dart: sent %d bytes", req.rawdata.length));
        size_t len = 0, doclen = 0;
        do {
            len = s.receivebuf(buf, buflen);
            if (len == size_t.max && s.errno != 0) {
                writeit("dart_handler: error on recv: ", nng_errstr(s.errno));
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "socket error";
                return;
            }
            if (len > buflen) {
                writeit("dart_handler: recv wrong size: ", len);
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "socket error";
                return;
            }
            writeit(format("WH: dart: received %d bytes", len));
            docbuf ~= buf[0 .. len];
            doclen += len;
        }
        while (len > buflen - 1);
        rep.status = (doclen > 0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT;
        rep.type = "applicaion/octet-stream";
        rep.rawdata = (doclen > 0) ? docbuf[0 .. doclen] : null;
    }catch(Throwable e){
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.msg;
        rep.text = dump_exception_recursive(e, "handler: dart");
        return;
    }
}

static void i2p_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    rt_moduleTlsCtor();
    try {
        int rc;
        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != "application/octet-stream") {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }
        writeit(format("WH: invoice2pay: with %d bytes", req.rawdata.length));

        WalletOptions options;
        auto wallet_config_file = opt.default_i2p_wallet;
        if (wallet_config_file.exists) {
            options.load(wallet_config_file);
        }
        else {
            writeit("i2p: invalid wallet config: " ~ opt.default_i2p_wallet);
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid wallet config";
            return;
        }
        auto wallet_interface = WalletInterface(options);

        if (!wallet_interface.load) {
            writeit("i2p: Wallet does not exist");
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "wallet does not exist";
            return;
        }
        const flag = wallet_interface.secure_wallet.login(opt.default_i2p_wallet_pin);
        if (!flag) {
            writeit("i2p: Wallet wrong pincode");
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "Faucet invalid pin code";
            return;
        }

        if (!wallet_interface.secure_wallet.isLoggedin) {
            writeit("i2p: invalid wallet login");
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid wallet login";
            return;
        }

        writeit("Before creating of invoices");

        Document[] requests_to_pay;
        requests_to_pay ~= Document(cast(immutable(ubyte[])) req.rawdata);
        TagionBill[] to_pay;
        import tagion.hibon.HiBONRecord;

        foreach (doc; requests_to_pay) {
            if (doc.valid != Document.Element.ErrorCode.NONE) {
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "invalid document: ";
                writeln("i2p: invalid document");
                return;
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
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "invalid faucet request";
                return;
            }
        }

        writeit(to_pay[0].toPretty);

        SignedContract signed_contract;
        TagionCurrency fees;
        const payment_status = wallet_interface.secure_wallet.createPayment(to_pay, signed_contract, fees);
        if (!payment_status.value) {
            writeit("i2p: faucet is empty");
            rep.status = nng_http_status.NNG_HTTP_STATUS_INTERNAL_SERVER_ERROR;
            rep.msg = format("faucet createPayment error: %s", payment_status.msg);
            return;
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
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        rep.type = "applicaion/octet-stream";
        rep.rawdata = cast(ubyte[])(receiver.toDoc.serialize);
    }catch(Throwable e){
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.msg;
        rep.text = dump_exception_recursive(e, "handler: i2p");
        return;
    }
}

static void sysinfo_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    try {
        JSONValue data = parseJSON("{}");
        data["memsize"] = getmemstatus();
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        rep.type = "application/json";
        rep.json = data;
    }catch(Throwable e){
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.msg;
        rep.text = dump_exception_recursive(e, "handler: sysinfo");
        return;
    }
}

static void selftest_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    rt_moduleTlsCtor();
    try {
        int rc;
        ShellOptions* opt = cast(ShellOptions*) ctx;
        WalletOptions options;
        auto wallet_config_file = opt.default_i2p_wallet;
        if (wallet_config_file.exists) {
            options.load(wallet_config_file);
        }
        else {
            writeit("selftest: invalid I2P wallet config: " ~ opt.default_i2p_wallet);
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid wallet config";
            return;
        }
        auto wallet_interface = WalletInterface(options);
        if (!wallet_interface.load) {
            writeit("selftest: Wallet does not exist");
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "wallet does not exist";
            return;
        }
        const flag = wallet_interface.secure_wallet.login(opt.default_i2p_wallet_pin);
        if (!flag) {
            writeit("selftest: Wallet wrong pincode");
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "Faucet invalid pin code";
            return;
        }
        if (!wallet_interface.secure_wallet.isLoggedin) {
            writeit("selftest: invalid wallet login");
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid wallet login";
            return;
        }
        
        string uri = opt.shell_uri ~ opt.shell_api_prefix;
        auto localpath = (opt.shell_api_prefix~opt.selftest_endpoint).split("/")[1..$];
        auto dpath = req.path.split(localpath);
        string[] reqpath;
        if(dpath.length == 2){
            reqpath = dpath[1].dup;
        }
        
        rep.status = nng_http_status.NNG_HTTP_STATUS_NOT_IMPLEMENTED;

        if(reqpath.length > 0){    
            switch(reqpath[0]){
                case "bullseye":
                    WebData hrep = WebClient.get(uri ~ opt.bullseye_endpoint, null);
                    if(hrep.status != nng_http_status.NNG_HTTP_STATUS_OK){
                        rep.status = hrep.status;
                        rep.msg = hrep.msg;
                        rep.text = hrep.text;
                        break;
                    }
                    JSONValue jdata = hrep.json;
                    enforce(jdata["$@"].str == "HiRPC","Test: bullseye: parse result");
                    enforce("bullseye" in jdata["$msg"]["result"],"Test: bullseye: parse result");
                    auto res = jdata["$msg"]["result"]["bullseye"][1].str;
                    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                    rep.type = "application/json";
                    rep.json = parseJSON(`{"test": "bullseye", "passed": "ok", "result":{"bullseye":"`~res~`"}}`);
                    break;
                case "dart":
                case "dartcache":
                    enum update_tag = "update";
                    const update_net = wallet_interface.secure_wallet.net.derive(
                        wallet_interface.secure_wallet.net.calcHash(
                            update_tag.representation));
                    const hirpc = HiRPC(update_net);
                    const hreq = wallet_interface.secure_wallet.getRequestUpdateWallet(hirpc);
                    WebData hrep = WebClient.post(uri ~ ((reqpath[0] == "dart") ? opt.dart_endpoint : opt.dartcache_endpoint), 
                        cast(ubyte[])(hreq.serialize), 
                        ["Content-type": "application/octet-stream"]);
                    if(hrep.status != nng_http_status.NNG_HTTP_STATUS_OK){
                        rep.status = hrep.status;
                        rep.msg = hrep.msg;
                        rep.text = hrep.text;
                        break;
                    }
                    Document doc = Document(cast(immutable(ubyte[])) hrep.rawdata);
                    JSONValue jdata = doc.toJSON();
                    enforce(jdata["$@"].str == "HiRPC","Test: dart(cache): parse result");
                    enforce("result" in jdata["$msg"], "Test: dart(cache): parse result");
                    auto cnt = jdata["$msg"]["result"].array.length;
                    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                    rep.type = "application/json";
                    rep.json = parseJSON(format(`{"test": "%s", "passed": "ok", "result":{"count": %d}}`,reqpath[0],cnt));
                    break;
                default:
                    break;
            }
        }
        
        if(rep.status != nng_http_status.NNG_HTTP_STATUS_OK){
           rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
           rep.type = "text/html";
           rep.text = "<h2>The requested test couldn`t be processed</h2>\n\r<pre>\n\r" ~ to!string(reqpath) ~ "\n\r</pre>\n\r";
        }

    }catch(Throwable e){
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.msg;
        rep.text = dump_exception_recursive(e, "handler: selftest");
        return;
    }
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    GetoptResult main_args;

    ShellOptions options;

    long sz, isz;

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

    // hardcode just for test - TODO: move to options
    immutable uint dcache_size = 4096;
    immutable double dcache_ttl = 30.0;

    dcache = new shared(DartCache)(null, dcache_size, dcache_ttl);

    //auto ds_tid = spawn(&dart_worker, options);

    writeit("\nTagionShell web service\nListening at "
            ~ options.shell_uri ~ "\n\t"
            ~ options.shell_api_prefix
                ~ options.contract_endpoint
                ~ "\t= POST contract hibon\n\t"
            ~ options.shell_api_prefix
                ~ options.dart_endpoint
                ~ "\t\t= POST dart request hibon\n\t"
            ~ options.shell_api_prefix
                ~ options.i2p_endpoint
                ~ "\t= POST invoice-to-pay hibon\n\t"
            ~ options.shell_api_prefix
                ~ options.bullseye_endpoint
                ~ "\t= GET dart bullseye hibon\n\t"
            ~ options.shell_api_prefix
                ~ options.sysinfo_endpoint
                ~ "\t\t= GET system info\n\t"
            ~ options.shell_api_prefix
                ~ options.selftest_endpoint ~ "/<enpoint>"
                ~ "\t= GET self test results\n\t"
                ~ "\t== /bullseye \t- test bullseye endpoint\n\t"
                ~ "\t== /dart \t- test dart request endpoint\n\t"
                ~ "\t== /dartcache \t- test dart cache endpoint\n\t"


    );

    isz = getmemstatus();

appoint:

    WebApp app = WebApp("ShellApp", options.shell_uri, parseJSON(`{"root_path":"/tmp/webapp","static_path":"static"}`), &options);

    app.route(options.shell_api_prefix ~ options.sysinfo_endpoint, &sysinfo_handler, ["GET"]);
    app.route(options.shell_api_prefix ~ options.bullseye_endpoint, &bullseye_handler, ["GET"]);
    app.route(options.shell_api_prefix ~ options.contract_endpoint, &contract_handler, ["POST"]);
    app.route(options.shell_api_prefix ~ options.dart_endpoint, &dart_handler, ["POST"]);
    app.route(options.shell_api_prefix ~ options.dartcache_endpoint, &dartcache_handler, ["POST"]);
    app.route(options.shell_api_prefix ~ options.i2p_endpoint, &i2p_handler, ["POST"]);
    app.route(options.shell_api_prefix ~ options.selftest_endpoint ~ "/*", &selftest_handler, ["GET"]);

    app.start();

    while (true) {
        nng_sleep(2000.msecs);
        version (none) {
            sz = getmemstatus();
            writeln("mem: ", sz);
            if (sz > isz * 2) {
                writeln("Reset app!");
                app.stop;
                destroy(app);
                goto appoint;
            }
        }

    }

    return 0;
}
