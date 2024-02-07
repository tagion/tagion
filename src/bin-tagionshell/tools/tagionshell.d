module tagion.tools.tagionshell;

import core.time;
import core.memory;
import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.path : setExtension;
import std.file : exists;
import std.format;
import std.getopt;
import std.json;
import std.typecons;
import std.string : representation;
import std.stdio : File, toFile, stderr, stdout, writefln, writeln;
import std.datetime.systime : Clock;
import tagion.basic.Types : Buffer, FileExtension, hasExtension;
import tagion.basic.range : doFront;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.dart.Recorder;
import tagion.services.subscription;
import tagion.Keywords;
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

alias LRUT!(Buffer, TagionBill[]) DartCache;

shared DartCache dcache;
shared static bool abort = false;

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

static double timestamp() {
    auto ts = Clock.currTime().toTimeSpec();
    return ts.tv_sec + ts.tv_nsec / 1e9;
}

void writeit(A...)(A a) {
    writeln(a);
    stdout.flush();
}

enum ExceptionFormat {
    PLAIN,
    HTML
};

string dump_exception_recursive(Throwable ex, string tag = "", ExceptionFormat kind = ExceptionFormat.HTML) {
    string[] res;
    switch (kind) {
    case ExceptionFormat.HTML:
        res ~= format("\r\n<h2>Exception caught in TagionShell %s %s</h2>\r\n", Clock.currTime()
                .toSimpleString(), tag);
        foreach (t; ex) {
            res ~= format("<code>\r\n<h3>%s [%d]: %s </h3>\r\n<pre>\r\n%s\r\n</pre>\r\n</code>\r\n",
                    t.file, t.line, t.message(), t.info);
        }
        break;
    case ExceptionFormat.PLAIN:
    default:
        res ~= format("\r\nException caught in TagionShell %s %s\r\n", Clock.currTime()
                .toSimpleString(), tag);
        foreach (t; ex) {
            res ~= format("%s [%d]: %s \r\n%s\r\n", t.file, t.line, t.message(), t.info);
        }
        break;
    }
    return join(res, "\r\n");
}

void dart_worker(ShellOptions opt) {
    int rc;
    int attempts = 0;
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
    NNGSocket r = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    const net = new StdHashNet();
    s.recvtimeout = msecs(opt.sock_recvtimeout);
    s.subscribe(opt.recorder_subscription_tag);
    r.recvtimeout = msecs(opt.sock_recvtimeout);
    writeit("DS: subscribed");
    while (true) {
        rc = s.dial(opt.tagion_subscription_addr);
        if (rc == 0)
            break;
        enforce(++attempts < opt.sock_connectretry, "Couldn`t connect the subscription socket");
    }
    while (true) {
        rc = r.dial(opt.node_dart_addr);
        if (rc == 0)
            break;
        enforce(++attempts < opt.sock_connectretry, "Couldn`t connect the kernel socket");
    }
    scope (exit) {
        s.close();
        r.close();
    }
    auto record_factory = RecordFactory(net);
    const hirpc = HiRPC(null);
    writeit("DS: connected");
    while (true) {
        try {
            auto received = s.receive!(immutable(ubyte[]))();
            if (received.empty) {
                continue;
            }
            const doc = Document(received[received.countUntil(0) + 1 .. $]);
            if (!doc.isInorder(No.Reserved)) {
                continue;
            }
            auto receiver = hirpc.receive(doc);
            if (!receiver.isMethod) {
                writeit("DS: Invalid method in document received");
                continue;
            }
            const payload = SubscriptionPayload(receiver.method.params);
            if (opt.recorder_subscription_task_prefix.length > 0) {
                if (!payload.task_name.startsWith(opt.recorder_subscription_task_prefix)) {
                    continue;
                }
            }
            auto recorder = record_factory.recorder(payload.data);
            Buffer[] affected_owners, tofetch;
            TagionBill[][Buffer] toadd, toremove;
            foreach (a; recorder[]) {
                if (a.filed.isRecord!TagionBill) {
                    auto t = a.type;
                    auto b = TagionBill(a.filed);
                    auto o = cast(Buffer) b.owner;
                    affected_owners ~= o;
                    if (t == Archive.Type.ADD) {
                        toadd[o] ~= b;
                    }
                    else if (t == Archive.Type.REMOVE) {
                        toremove[o] ~= b;
                    }
                }
            }
            int k = 0;
            if (!affected_owners.empty) {
                foreach (o; affected_owners) {
                    TagionBill[] bucket;
                    if (dcache.get(o, bucket)) {
                        if (o in toremove) {
                            foreach (b; toremove[o]) {
                                remove!(x => x == b)(bucket);
                                k++;
                            }
                        }
                        if (o in toadd) {
                            foreach (b; toadd[o]) {
                                bucket ~= b;
                                k++;
                            }
                        }
                        dcache.update(o, bucket, true);
                    }
                    else {
                        tofetch ~= o;
                    }
                }
                if (!tofetch.empty) {
                    const size_t buflen = 1048576;
                    ubyte[1048576] buf;
                    immutable(ubyte)[] docbuf;
                    size_t len = 0, doclen = 0;
                    auto dreq = new HiBON;
                    dreq = tofetch;
                    rc = r.send(cast(ubyte[])(hirpc.search(dreq).toDoc.serialize));
                    if (rc != 0) {
                        writeit("ERROR: dart_worker: req send: ", nng_errstr(rc));
                        continue;
                    }
                    do {
                        len = r.receivebuf(buf, buflen);
                        if (len == size_t.max && s.errno != 0) {
                            writeit("ERROR: dart_worker: recv: ", nng_errstr(s.errno));
                            continue;
                        }
                        if (len > buflen) {
                            writeit("ERROR: dart_worker: recv wrong size: ", len);
                            continue;
                        }
                        docbuf ~= buf[0 .. len];
                        doclen += len;
                    }
                    while (len > buflen - 1);
                    const repdoc = Document(docbuf);
                    immutable repreceiver = hirpc.receive(repdoc);
                    TagionBill[] received_bills = repreceiver.response.result[]
                        .map!(e => TagionBill(e.get!Document))
                        .array;
                    TagionBill[][Buffer] tocache;
                    foreach (bill; received_bills) {
                        tocache[cast(Buffer) bill.owner] ~= bill;
                        k++;
                    }
                    foreach (owner; tocache.keys) {
                        dcache.update(owner, tocache[owner], true);
                    }
                }
            }
            if (k > 0)
                writeit(format("DS: Cache updated in %d bills", k));
        }
        catch (Throwable e) {
            writeit(dump_exception_recursive(e, "worker: dartcache", ExceptionFormat.PLAIN));
            continue;
        }
    }
}

void contract_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    try {
        int rc;
        int attempts = 0;
        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != "application/octet-stream") {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }

        const contract_addr = opt.node_contract_addr;

        writeit(format("WH: contract: with %d bytes for %s", req.rawdata.length, contract_addr));
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        s.recvtimeout = msecs(opt.sock_recvtimeout * 6);
        writeit(format("WH: contract: trying to dial %s", contract_addr));
        while (true) {
            rc = s.dial(contract_addr);
            if (rc == 0)
                break;
            enforce(++attempts < opt.sock_connectretry, "Couldn`t connect the kernel socket");
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
        const stime = timestamp();
        NNGMessage msg = NNGMessage(0);
        ubyte[] buf;
        size_t len = 0;
        while(true){
            rc = s.receivemsg(&msg, true);
            if(rc < 0){
                if(s.errno == nng_errno.NNG_EAGAIN){
                    nng_sleep(msecs(opt.sock_recvdelay));
                    auto itime = timestamp();
                    if((itime - stime) * 1000 > opt.sock_recvtimeout){
                        writeit("contract_handler: recv: timeout");
                        rep.status = nng_http_status.NNG_HTTP_STATUS_GATEWAY_TIMEOUT;
                        rep.msg = "socket timeout";
                        return;
                    }
                    msg.clear();
                    continue;
                }
                if(s.errno != 0){
                    writeit("contract_handler: recv: ", nng_errstr(s.errno));
                    rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                    rep.msg = "socket error";
                    return;
                }
                writeit("contract_handler: recv: empty response");
                break;
            }
            len = msg.length; 
            buf = msg.body_trim!(ubyte[])(msg.length);
            break;
        }
        rep.status = (len > 0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT;
        rep.type = "applicaion/octet-stream";
        rep.rawdata = (len > 0) ? buf[0 .. len] : null;
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.message().idup;
        rep.text = dump_exception_recursive(e, "handler: contract");
        return;
    }
}

import crud = tagion.dart.DARTcrud;

HiRPC.Receiver get_bullseye(string dart_addr) {
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);

    int rc;
    int attempts = 0;

    while (true) {
        rc = s.dial(dart_addr);
        if (rc == 0)
            break;
        enforce(++attempts < 32, "Couldn`t connect the subscription socket"); // TODO: consider sharing opt
    }
    scope (exit) {
        s.close();
    }

    rc = s.send(crud.dartBullseye.toDoc.serialize);
    ubyte[192] buf;
    size_t len = s.receivebuf(buf, buf.length);
    if (len == size_t.max && s.errno != 0) {
        return HiRPC.Receiver.init;
    }

    const receiver = HiRPC(null).receive(Document(buf.idup));
    return receiver;
}

static void bullseye_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    try {
        int attempts = 0;

        ShellOptions* opt = cast(ShellOptions*) ctx;

        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);

        int rc;
        while (true) {
            rc = s.dial(opt.node_dart_addr);
            if (rc == 0)
                break;
            enforce(++attempts < opt.sock_connectretry, "Couldn`t connect the kernel socket");
        }
        scope (exit) {
            s.close();
        }

        rc = s.send(crud.dartBullseye.toDoc.serialize);
        ubyte[192] buf;
        size_t len = s.receivebuf(buf, buf.length);
        if (len == size_t.max && s.errno != 0) {
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

        if (req.path[$ - 1].hasExtension("json")) {
            const dartindex = parseJSON(receiver.toPretty);
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = "application/json";
            rep.json = dartindex;
        }
        else {
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = "application/octet-stream";
            rep.rawdata = cast(ubyte[]) receiver.serialize;
        }

    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.message().idup;
        rep.text = dump_exception_recursive(e, "handler: bullseye.json");
        return;
    }
}

static void dart_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    rt_moduleTlsCtor();
    try {
        int rc;
        size_t nfound = 0, nreceived = 0, attempts = 0;
        bool usecache = true;
        immutable(ubyte)[] docbuf;
        size_t doclen;

        const stime = timestamp();
        NNGMessage msg = NNGMessage(0);

        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != "application/octet-stream") {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }

        if (req.path[$ - 1] == "nocache")
            usecache = false;
        
        SecureNet net = new StdSecureNet();
        net.generateKeyPair("very_secret");
        HiRPC hirpc = HiRPC(net);
        Document doc = Document(cast(immutable(ubyte[])) req.rawdata);

        immutable receiver = hirpc.receive(doc);
        if (!receiver.isMethod) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "Invalid request method";
            return;
        }

        if (receiver.method.name == "search") {
            auto pkey_doc = receiver.method.params;
            Buffer[] owner_pkeys;
            foreach (owner; pkey_doc[]) {
                owner_pkeys ~= owner.get!Buffer;
            }
            TagionBill[] found_bills;
            Buffer[] found_owners;
            if (usecache) {
                TagionBill[] fnd;
                foreach (owner; owner_pkeys) {
                    if (dcache.get(owner, fnd)) {
                        found_bills ~= fnd;
                        found_owners ~= owner;
                    }
                }
            }
            nfound = found_bills.length;
            // TODO: merge with previous, check array reducing in foreach
            if (!found_owners.empty) {
                foreach (owner; found_owners) {
                    remove!(x => x == owner)(owner_pkeys);
                }
            }
            if (!owner_pkeys.empty) {
                auto dreq = new HiBON;
                dreq = owner_pkeys;
                NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
                s.recvtimeout = msecs(opt.sock_recvtimeout);
                while (true) {
                    rc = s.dial(opt.node_dart_addr);
                    if (rc == 0)
                        break;
                    enforce(++attempts < opt.sock_connectretry, "Couldn`t connect the kernel socket");
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
                while (true) {
                    rc = s.receivemsg(&msg, true);
                    if (rc < 0) {
                        if (s.errno == nng_errno.NNG_EAGAIN) {
                            nng_sleep(msecs(opt.sock_recvdelay));
                            auto itime = timestamp();
                            if ((itime - stime) * 1000 > opt.sock_recvtimeout) {
                                writeit("dart_handler: recv: timeout");
                                rep.status = nng_http_status.NNG_HTTP_STATUS_GATEWAY_TIMEOUT;
                                rep.msg = "socket timeout";
                                return;
                            }
                            msg.clear();
                            continue;
                        }
                        if (s.errno != 0) {
                            writeit("dart_handler: recv: ", nng_errstr(s.errno));
                            rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                            rep.msg = "socket error";
                            return;
                        }
                        writeit("dart_handler: recv: empty response");
                        break;
                    }
                    auto buf = msg.body_trim!(ubyte[])(msg.length);
                    writeit(format("WH: dart: received %d bytes", buf.length));
                    docbuf ~= buf[0 .. buf.length];
                    doclen += docbuf.length;
                    break;
                }
                if (docbuf.empty) {
                    rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                    rep.msg = "No response";
                    return;
                }
                const repdoc = Document(docbuf);
                immutable repreceiver = hirpc.receive(repdoc);
                TagionBill[] received_bills = repreceiver.response.result[]
                    .map!(e => TagionBill(e.get!Document))
                    .array;
                if (usecache) {
                    TagionBill[][Buffer] tocache;
                    foreach (bill; received_bills) {
                        tocache[cast(Buffer) bill.owner] ~= bill;
                    }
                    foreach (owner; tocache.keys) {
                        dcache.update(owner, tocache[owner], true);
                    }
                }
                nreceived = received_bills.length;
                found_bills ~= received_bills;
            }
            writeit("DART STAT: ", nfound, " found, ", nreceived, " received");
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
        }
        else {
            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
            s.recvtimeout = msecs(opt.sock_recvtimeout);
            while (true) {
                rc = s.dial(opt.node_dart_addr);
                if (rc == 0)
                    break;
                enforce(++attempts < opt.sock_connectretry, "Couldn`t connect the kernel socket");
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
            while (true) {
                rc = s.receivemsg(&msg, true);
                if (rc < 0) {
                    if (s.errno == nng_errno.NNG_EAGAIN) {
                        nng_sleep(msecs(opt.sock_recvdelay));
                        auto itime = timestamp();
                        if ((itime - stime) * 1000 > opt.sock_recvtimeout) {
                            writeit("dart_handler: recv: timeout");
                            rep.status = nng_http_status.NNG_HTTP_STATUS_GATEWAY_TIMEOUT;
                            rep.msg = "socket timeout";
                            return;
                        }
                        msg.clear();
                        continue;
                    }
                    if (s.errno != 0) {
                        writeit("dart_handler: recv: ", nng_errstr(s.errno));
                        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                        rep.msg = "socket error";
                        return;
                    }
                    writeit("dart_handler: recv: empty response");
                    break;
                }
                auto buf = msg.body_trim!(ubyte[])(msg.length);
                writeit(format("WH: dart: received %d bytes", buf.length));
                docbuf ~= buf[];
                doclen = docbuf.length;
                break;
            }
            rep.status = (doclen > 0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT;
            rep.type = "applicaion/octet-stream";
            rep.rawdata = (doclen > 0) ? docbuf.dup[0 .. doclen] : null;
        }
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.message().idup;
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

        //writeit(signed_contract.toPretty);

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
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.message().idup;
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
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.message().idup;
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
        auto localpath = (opt.shell_api_prefix ~ opt.selftest_endpoint).split("/")[1 .. $];
        auto dpath = req.path.split(localpath);
        string[] reqpath;
        if (dpath.length == 2) {
            reqpath = dpath[1].dup;
        }

        rep.status = nng_http_status.NNG_HTTP_STATUS_NOT_IMPLEMENTED;

        if (reqpath.length > 0) {
            switch (reqpath[0]) {
            case "bullseye":
                WebData hrep = WebClient.get(uri ~ opt.bullseye_endpoint ~ ".json", null);
                if (hrep.status != nng_http_status.NNG_HTTP_STATUS_OK) {
                    rep.status = hrep.status;
                    rep.msg = hrep.msg;
                    rep.text = hrep.text;
                    break;
                }
                JSONValue jdata = hrep.json;
                enforce(jdata["$@"].str == "HiRPC", "Test: bullseye: parse result");
                enforce("bullseye" in jdata["$msg"]["result"], "Test: bullseye: parse result");
                auto res = jdata["$msg"]["result"]["bullseye"][1].str;
                rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                rep.type = "application/json";
                rep.json = parseJSON(`{"test": "bullseye", "passed": "ok", "result":{"bullseye":"` ~ res ~ `"}}`);
                break;
            case "dart":
                enum update_tag = "update";
                const update_net = wallet_interface.secure_wallet.net.derive(
                        wallet_interface.secure_wallet.net.calcHash(
                        update_tag.representation));
                const hirpc = HiRPC(update_net);
                const hreq = wallet_interface.secure_wallet.getRequestUpdateWallet(hirpc);
                WebData hrep = WebClient.post(uri ~ opt.dart_endpoint,
                        cast(ubyte[])(hreq.serialize),
                        ["Content-type": "application/octet-stream"]);
                if (hrep.status != nng_http_status.NNG_HTTP_STATUS_OK) {
                    rep.status = hrep.status;
                    rep.msg = hrep.msg;
                    rep.text = hrep.text;
                    break;
                }
                Document doc = Document(cast(immutable(ubyte[])) hrep.rawdata);
                JSONValue jdata = doc.toJSON();
                enforce(jdata["$@"].str == "HiRPC", "Test: dart(cache): parse result");
                enforce("result" in jdata["$msg"], "Test: dart(cache): parse result");
                auto cnt = jdata["$msg"]["result"].array.length;
                rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                rep.type = "application/json";
                rep.json = parseJSON(format(`{"test": "%s", "passed": "ok", "result":{"count": %d}}`, reqpath[0], cnt));
                break;
            default:
                break;
            }
        }

        if (rep.status != nng_http_status.NNG_HTTP_STATUS_OK) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = "text/html";
            rep.text = "<h2>The requested test couldn`t be processed</h2>\n\r<pre>\n\r" ~ to!string(
                    reqpath) ~ "\r\n" ~ rep.msg ~ "\r\n" ~ rep.text ~ "\n\r</pre>\n\r";
        }

    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = "text/html";
        rep.msg = e.message().idup;
        rep.text = dump_exception_recursive(e, "handler: selftest");
        return;
    }
}

void versioninfo_handler(WebData* req, WebData* rep, void* ctx) {
    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
    rep.type = "text/html";
    rep.text = imported!"tagion.tools.revision".revision_text;
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    GetoptResult main_args;

    ShellOptions options;

    long sz, isz;

    auto default_shell_config_filename = "shell".setExtension(FileExtension.json);
    const user_config_file = args.countUntil!(file => file.hasExtension(FileExtension.json) && file.exists);
    auto config_file = (user_config_file < 0) ? default_shell_config_filename : args[user_config_file];

    if (config_file.exists) {
        try {
            options.load(config_file);
        }
        catch(Exception e) {
            stderr.writefln("Error loading config file %s, %s", config_file, e.msg);
            return 1;
        }
    }
    else {
        options = ShellOptions.defaultOptions;
    }

    try {
        main_args = getopt(args, std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
        );
    }
    catch (GetOptException e) {
        stderr.writeit(e.message().idup);
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

    dcache = new shared(DartCache)(null, cast(immutable) options.dartcache_size, cast(immutable) options
            .dartcache_ttl_msec);

    auto ds_tid = spawn(&dart_worker, options);

    writeit("\nTagionShell web service\nListening at "
            ~ options.shell_uri ~ "\n\t"
            ~ options.shell_api_prefix
            ~ options.contract_endpoint
            ~ "\t= POST contract hibon\n\t"
            ~ options.shell_api_prefix
            ~ options.dart_endpoint ~ "/[nocache]"
            ~ "\t\t= POST dart request hibon (depending on the method send raw request or use cache for pkeys)\n\t"
            ~ options.shell_api_prefix
            ~ options.i2p_endpoint
            ~ "\t= POST invoice-to-pay hibon\n\t"
            ~ options.shell_api_prefix
            ~ options.bullseye_endpoint ~ ".hibon"
            ~ "\t= GET dart bullseye json\n\t"
            ~ options.shell_api_prefix
            ~ options.bullseye_endpoint ~ ".json"
            ~ "\t= GET dart bullseye hibon\n\t"
            ~ options.shell_api_prefix
            ~ options.sysinfo_endpoint
            ~ "\t\t= GET system info\n\t"
            ~ options.shell_api_prefix
            ~ options.version_endpoint
            ~ "\t\t= GET network version info\n\t"
            ~ options.shell_api_prefix
            ~ options.selftest_endpoint ~ "/<enpoint>"
            ~ "\t= GET self test results\n\t"
            ~ "\t== /bullseye \t- test bullseye endpoint\n\t"
            ~ "\t== /dart \t- test dart request endpoint\n\t"

    );

    isz = getmemstatus();



appoint:

    WebApp app = WebApp("ShellApp", options.shell_uri, parseJSON(`{"root_path":"/tmp/webapp","static_path":"static"}`), &options);

    app.route(options.shell_api_prefix ~ options.sysinfo_endpoint, &sysinfo_handler, ["GET"]);
    app.route(options.shell_api_prefix ~ options.bullseye_endpoint, &bullseye_handler, ["GET"]);
    app.route(options.shell_api_prefix ~ options.bullseye_endpoint ~ ".json", &bullseye_handler, ["GET"]);
    app.route(options.shell_api_prefix ~ options.bullseye_endpoint ~ ".hibon", &bullseye_handler, ["GET"]);
    app.route(options.shell_api_prefix ~ options.contract_endpoint, &contract_handler, ["POST"]);
    app.route(options.shell_api_prefix ~ options.dart_endpoint, &dart_handler, ["POST"]);
    app.route(options.shell_api_prefix ~ options.dart_endpoint ~ "/nocache", &dart_handler, ["POST"]);
    app.route(options.shell_api_prefix ~ options.i2p_endpoint, &i2p_handler, ["POST"]);
    app.route(options.shell_api_prefix ~ options.selftest_endpoint ~ "/*", &selftest_handler, ["GET"]);
    app.route(options.shell_api_prefix ~ options.version_endpoint, &versioninfo_handler, ["GET"]);

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
        if (abort) {
            writeln("Shell aborting");
            app.stop;
            destroy(app);
            return 0;
        }

    }

    return 0;
}
