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
import std.range;
import std.string : representation;
import std.stdio : File, toFile, stderr, stdout, writefln, writeln;
import std.datetime.systime : Clock;
import tagion.basic.Types : Buffer, FileExtension, hasExtension;
import tagion.basic.range : doFront;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.crypto.Types : Pubkey;
import tagion.hibon.Document;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONFile : fread, fwrite;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.dart.DARTBasic : DARTIndex, dartKey, dartIndex;
import tagion.dart.Recorder;
import tagion.dart.DART;
import tagion.trt.TRT;
import tagion.services.subscription;
import tagion.Keywords;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.shell.shelloptions;
import tagion.tools.shell.contracts;
import tagion.tools.wallet.WalletInterface;
import tagion.tools.wallet.WalletOptions;
import tagion.utils.StdTime : currentTime;
import tagion.wallet.AccountDetails;
import tagion.wallet.SecureWallet;
import tagion.utils.LRUT;
import core.thread;
import nngd.nngd;

mixin Main!(_main, "shell");

alias LRUT!(DARTIndex, TRTArchive) TRTCache;
alias LRUT!(DARTIndex, Document) IndexCache;

shared TRTCache tcache;
shared IndexCache icache;
shared static bool abort = false;

enum ContentType {
    octet = "application/octet-stream",
    json = "application/json",
    html = "text/html",
}

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
    final switch (kind) {
    case ExceptionFormat.HTML:
        res ~= format("\r\n<h2>Exception caught in TagionShell %s %s</h2>\r\n", Clock.currTime()
                .toSimpleString(), tag);
        foreach (t; ex) {
            res ~= format("<code>\r\n<h3>%s [%d]: %s </h3>\r\n<pre>\r\n%s\r\n</pre>\r\n</code>\r\n",
                    t.file, t.line, t.message(), t.info);
        }
        break;
    case ExceptionFormat.PLAIN:
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
    auto record_factory = RecordFactory(net);
    const hirpc = HiRPC(null);
    s.recvtimeout = msecs(opt.sock_recvtimeout);
    s.subscribe(opt.recorder_subscription_tag);
    s.subscribe(opt.trt_subscription_tag);
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
    writeit("DS: connected");
    while (true) {
        try {
            auto received = s.receive!(immutable(ubyte[]))();
            if (received.empty) {
                continue;
            }
            auto ppos = received.countUntil(0);
            auto topic = cast(string)received[0..ppos];
            const doc = Document(received[ppos + 1 .. $]);
            if (!doc.isInorder(No.Reserved)) {
                continue;
            }
            //writeit(format("RR: %d  %s  %d\n",received.length,topic,doc.length));
            auto receiver = hirpc.receive(doc);
            if (!receiver.isMethod) {
                writeit("DS: Invalid method in document received");
                continue;
            }
            const payload = SubscriptionPayload(receiver.method.params);
            if (opt.dart_subscription_task_prefix.length > 0) {
                if (!payload.task_name.startsWith(opt.dart_subscription_task_prefix)) {
                    continue;
                }
            }
            int k = 0;
            auto recorder = record_factory.recorder(payload.data);
            if(topic.startsWith("recorder")){
                foreach (a; recorder[]) {
                    if (a.filed.isRecord!TagionBill) {
                        if(a.type == Archive.Type.ADD){
                            Document filed = a.filed;
                            icache.update(DARTIndex(a.dart_index), filed, true);
                        }
                        else
                        if(a.type == Archive.Type.REMOVE){
                            icache.remove(a.dart_index);
                        }
                        k++;
                    }
                }
            } else 
            if(topic.startsWith("trt_created")){
                foreach (a; recorder[]) {
                    if (a.filed.isRecord!TRTArchive) {
                        auto archive = TRTArchive(a.filed);
                        tcache.update(DARTIndex(a.dart_index), archive, true);
                        k++;
                    }
                }
            }
            if (k > 0)
                writeit(format("DS: Cache updated in %d objects", k));
        }
        catch (Throwable e) {
            writeit(dump_exception_recursive(e, "worker: dartcache", ExceptionFormat.PLAIN));
            continue;
        }
    }
}


/*
* query REQ/REP socket once and close it 
*/
int query_socket_once ( string addr, uint timeout, uint delay, uint retries,  ubyte[] request, ref immutable(ubyte)[] reply  ){
    int rc;
    size_t len = 0, doclen = 0, attempts = 0;
    const stime = timestamp();
    NNGMessage msg = NNGMessage(0);
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    s.recvtimeout = msecs(timeout);
    while (true) {
        rc = s.dial(addr);
        if (rc == 0)
            break;
        if(++attempts < retries)
            return cast(int) nng_http_status.NNG_HTTP_STATUS_BAD_GATEWAY;
    }
    scope (exit) {
        s.close();
    }
    rc = s.send(request);
    if(rc != 0)
        return cast(int) nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
    while (true) {
        rc = s.receivemsg(&msg, true);
        if (rc < 0) {
            if (s.errno == nng_errno.NNG_EAGAIN) {
                nng_sleep(msecs(delay));
                auto itime = timestamp();
                if ((itime - stime) * 1000 > timeout) 
                    return cast(int)nng_http_status.NNG_HTTP_STATUS_GATEWAY_TIMEOUT;
                msg.clear();
                continue;
            }
            if (s.errno != 0) 
                return cast(int) nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
            break;
        }
        auto dbuf = msg.body_trim!(ubyte[])(msg.length);
        reply ~= dbuf[0 .. dbuf.length];
        break;
    }
    return 0;
}


/*
*
* NOT to be deprecated with /api/v1, passed to v2
*
*/
void contract_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    try {
        int rc;
        int attempts = 0;
        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != ContentType.octet) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }

        save_rpc(opt, Document(req.rawdata.idup));

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
        while (true) {
            rc = s.receivemsg(&msg, true);
            if (rc < 0) {
                if (s.errno == nng_errno.NNG_EAGAIN) {
                    nng_sleep(msecs(opt.sock_recvdelay));
                    auto itime = timestamp();
                    if ((itime - stime) * 1000 > opt.sock_recvtimeout) {
                        writeit("contract_handler: recv: timeout");
                        rep.status = nng_http_status.NNG_HTTP_STATUS_GATEWAY_TIMEOUT;
                        rep.msg = "socket timeout";
                        return;
                    }
                    msg.clear();
                    continue;
                }
                if (s.errno != 0) {
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
        rep.type = ContentType.octet;
        rep.rawdata = (len > 0) ? buf[0 .. len] : null;
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = ContentType.html;
        rep.msg = e.message().idup;
        rep.text = dump_exception_recursive(e, "handler: contract");
        return;
    }
}


/*
*
* to be deprecated with /api/v1, successor: /api/v2/dart/bullseye
*
*/
static void bullseye_handler(WebData* req, WebData* rep, void* ctx) {
    import crud = tagion.dart.DARTcrud;

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
            rep.type = ContentType.json;
            rep.json = dartindex;
        }
        else {
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = ContentType.octet;
            rep.rawdata = cast(ubyte[]) receiver.serialize;
        }

    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = ContentType.html;
        rep.msg = e.message().idup;
        rep.text = dump_exception_recursive(e, "handler: bullseye.json");
        return;
    }
}

/*
*
* alternative /api/v1/dart to use /api/v2
* to be deprecated with /api/v1, successor: /api/v2/dart/[read,raw]
*
*/
static void dart_handler_alt(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    rt_moduleTlsCtor();
    try {
        int rc;
        size_t nfound = 0, nreceived = 0, attempts = 0;

        immutable(ubyte)[] docbuf;
        size_t doclen;

        const stime = timestamp();

        const net = new StdHashNet();
        auto record_factory = RecordFactory(net);
        const hirpc = HiRPC(null);

        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != ContentType.octet) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }
        save_rpc(opt, Document(req.rawdata.idup));

        Document doc = Document(cast(immutable(ubyte[])) req.rawdata);

        immutable receiver = hirpc.receive(doc);
        if (!receiver.isMethod) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "Invalid request method";
            return;
        }
        ulong[string] stats = ["idx_found": 0, "idx_fetched": 0, "arch_found": 0, "arch_fetched": 0];
        if (receiver.method.full_name == "trt.dartRead" && opt.cache_enabled) {
            auto doc_dart_indices = receiver.method.params[DART.Params.dart_indices].get!(Document);
            auto owners = doc_dart_indices.range!(DARTIndex[]);
            
            DARTIndex[] itofetch;
            TRTArchive[] ifound;
            TRTArchive ibuf;
            if(opt.cache_enabled){
                foreach(o; owners){
                     if (tcache.get(o, ibuf)) {
                        ifound ~= ibuf;
                     }else{
                        itofetch ~= o;    
                     }
                }
            } else {
                itofetch ~= owners.array;
            }    
            stats["idx_found"] = ifound.length;
            if(!itofetch.empty){
                auto dreq = new HiBON;
                auto dparam = new HiBON;
                dreq = itofetch;
                dparam[DART.Params.dart_indices] = dreq;
                rc = query_socket_once(
                    opt.node_dart_addr,
                    opt.sock_recvtimeout,
                    opt.sock_recvdelay,
                    opt.sock_connectretry,
                    cast(ubyte[])(hirpc.action("trt." ~ DART.Queries.dartRead, dparam).toDoc.serialize),
                    docbuf
                );
                if (rc != 0) {
                    if(rc > 99 && rc < 600){
                        rep.status = cast(nng_http_status)rc;
                        writeit("dart_alt_handler: query: ",rep.status);
                    }else{
                        writeit("dart_alt_handler: query: ", nng_errstr(rc));
                        rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                    }    
                    rep.msg = "socket error";
                    return;
                }
                if (docbuf.empty) {
                    rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                    rep.msg = "No response";
                    return;
                }
                const repdoc = Document(docbuf);
                immutable repreceiver = hirpc.receive(repdoc);
                if (!repreceiver.isResponse){
                    rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                    rep.msg = "Invalid response";
                    return;
                }
                const recorder_doc = repreceiver.message[Keywords.result].get!Document;
                const reprecorder = record_factory.recorder(recorder_doc);
                foreach(a; reprecorder[]
                            .map!(a => a.filed)
                            .filter!(doc => doc.isRecord!TRTArchive)
                            .map!(doc => TRTArchive(doc))){
                    tcache.update(DARTIndex(net.dartIndex(a)), a, true);                                    
                    ifound ~= a;
                }
            }
            stats["idx_fetched"] = ifound.length - stats["idx_found"];
            writeit(stats);
            auto result_recorder = record_factory.recorder;
            foreach (b; ifound.uniq) {
                result_recorder.add(b);
            }
            Document response = hirpc.result(receiver, result_recorder.toDoc).toDoc;
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = ContentType.octet;
            rep.rawdata = cast(ubyte[])(response.serialize);
        } else if (receiver.method.full_name == "dartRead" && opt.cache_enabled) {
            auto doc_dart_indices = receiver.method.params[DART.Params.dart_indices].get!(Document);
            auto ifound = doc_dart_indices.range!(DARTIndex[]);

            DARTIndex[] tofetch;
            Document[] found;
            Document tbuf;
            if(opt.cache_enabled){
                foreach(id; ifound){
                     if (icache.get(id, tbuf)) {
                        found ~= tbuf;
                     }else{
                        tofetch ~= id;    
                     }
                }
            } else {
                tofetch ~= ifound.array;
            }
            stats["arch_found"] = found.length;
            if(!tofetch.empty){
                writeit("INSIDEI TOFETCH DARTREAD");
                auto dreq = new HiBON;
                auto dparam = new HiBON;
                dreq = tofetch;
                dparam[DART.Params.dart_indices] = dreq;
                docbuf.length = 0;
                rc = query_socket_once(
                    opt.node_dart_addr,
                    opt.sock_recvtimeout,
                    opt.sock_recvdelay,
                    opt.sock_connectretry,
                    cast(ubyte[])(hirpc.action(DART.Queries.dartRead, dparam).toDoc.serialize),
                    docbuf
                );
                if (rc != 0) {
                    if(rc > 99 && rc < 600){
                        rep.status = cast(nng_http_status)rc;
                        writeit("dart_handler: query: ",rep.status);
                    }else{
                        writeit("dart_handler: query: ", nng_errstr(rc));
                        rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                    }    
                    rep.msg = "socket error";
                    return;
                }
                if (docbuf.empty) {
                    rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                    rep.msg = "No response";
                    return;
                }
                const repdoc = Document(docbuf);
                immutable repreceiver = hirpc.receive(repdoc);
                if (!repreceiver.isResponse){
                    rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                    rep.msg = "Invalid response";
                    return;
                }
                const recorder_doc = repreceiver.message[Keywords.result].get!Document;
                const reprecorder = record_factory.recorder(recorder_doc);
                foreach(a; reprecorder[]){
                    Document filed = a.filed;
                    icache.update(DARTIndex(a.dart_index), filed, true);
                    found ~= a.filed;
                }
                stats["arch_fetched"] = found.length - stats["arch_found"];
            } 
            writeit(stats);
            auto result_recorder = record_factory.recorder;
            foreach (b; found.uniq) {
                result_recorder.add(b);
            }
            Document response = hirpc.result(receiver, result_recorder.toDoc).toDoc;
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = ContentType.octet;
            rep.rawdata = cast(ubyte[])(response.serialize);
        } else {
            rc = query_socket_once(
                opt.node_dart_addr,
                opt.sock_recvtimeout,
                opt.sock_recvdelay,
                opt.sock_connectretry,
                req.rawdata,
                docbuf
            );
            if (rc != 0) {
                if(rc > 99 && rc < 600){
                    rep.status = cast(nng_http_status)rc;
                    writeit("dart_raw_handler: query: ",rep.status);
                }else{
                    writeit("dart_raw_handler: query: ", nng_errstr(rc));
                    rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                }    
                rep.msg = "socket error";
                return;
            }
            if (docbuf.empty) {
                rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                rep.msg = "No response";
                return;
            }
            doclen = docbuf.length;
            rep.status = (doclen > 0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT;
            rep.type = ContentType.octet;
            rep.rawdata = (doclen > 0) ? docbuf.dup[0 .. doclen] : null;
        }
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = ContentType.html;
        rep.msg = e.message().idup;
        rep.text = dump_exception_recursive(e, "handler: dart");
        return;
    }
}


/*
*
* /api/v2/dart/[raw]
* /api/v2/dart/read
* /api/v2/dart/checkread
* /api/v2/dart/bullseye
*
*/

static void dart_handler_v2(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    rt_moduleTlsCtor();
    try {
        int rc;
        immutable(ubyte)[] docbuf;
        const net = new StdHashNet();
        auto record_factory = RecordFactory(net);
        const hirpc = HiRPC(null);
        
        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != ContentType.octet) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }
        
        save_rpc(opt, Document(req.rawdata.idup));
        
        auto subjects = req.path[(opt.shell_api_prefix_v2 ~ opt.dart_endpoint).split("/").length-1..$];
        auto subject = ( subjects.empty ) ? "raw" : subjects[0];
        
        Document doc = (req.rawdata.length > 0) ? Document(cast(immutable(ubyte[])) req.rawdata) : Document.init;
        
        switch(subject){
            case "raw":
                rc = query_socket_once(
                    opt.node_dart_addr,
                    opt.sock_recvtimeout,
                    opt.sock_recvdelay,
                    opt.sock_connectretry,
                    req.rawdata,
                    docbuf
                );
                if (rc != 0) {
                    if(rc > 99 && rc < 600){
                        rep.status = cast(nng_http_status)rc;
                        writeit("dart_raw_handler: query: ",rep.status);
                    }else{
                        writeit("dart_raw_handler: query: ", nng_errstr(rc));
                        rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                    }    
                    rep.msg = "socket error";
                    return;
                }
                if (docbuf.empty) {
                    rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                    rep.msg = "No response";
                    return;
                }
                auto doclen = docbuf.length;
                rep.status = (doclen > 0) ? nng_http_status.NNG_HTTP_STATUS_OK : nng_http_status.NNG_HTTP_STATUS_NO_CONTENT;
                rep.type = ContentType.octet;
                rep.rawdata = (doclen > 0) ? docbuf.dup[0 .. doclen] : null;
                break;
            case "read":
            case "checkread":
                immutable receiver = hirpc.receive(doc);
                if (!receiver.isMethod) {
                    rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                    rep.msg = "Invalid request method";
                    return;
                }
                auto doc_dart_indices = receiver.method.params[DART.Params.dart_indices].get!(Document);
                auto idx = doc_dart_indices.range!(DARTIndex[]);
                DARTIndex[] tofetch;
                Document[] found;
                Document tbuf;
                foreach(id; idx){
                     if (icache.get(id, tbuf)) {
                        found ~= tbuf;
                     }else{
                        tofetch ~= id;    
                     }
                }
                writeit(format("found %s in cache, requested %s", found.length, tofetch.length));
                if(!tofetch.empty){
                    auto dreq = new HiBON;
                    auto dparam = new HiBON;
                    dreq = tofetch;
                    dparam[DART.Params.dart_indices] = dreq;
                    rc = query_socket_once(
                        opt.node_dart_addr,
                        opt.sock_recvtimeout,
                        opt.sock_recvdelay,
                        opt.sock_connectretry,
                        (subject == "read") 
                            ? cast(ubyte[])(hirpc.action(DART.Queries.dartRead, dparam).toDoc.serialize)
                            : cast(ubyte[])(hirpc.action(DART.Queries.dartCheckRead, dparam).toDoc.serialize),
                        docbuf
                    );
                    if (rc != 0) {
                        if(rc > 99 && rc < 600){
                            rep.status = cast(nng_http_status)rc;
                            writeit("dart_handler: query: ",rep.status);
                        }else{
                            writeit("dart_handler: query: ", nng_errstr(rc));
                            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                        }    
                        rep.msg = "socket error";
                        return;
                    }
                    if (docbuf.empty) {
                        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                        rep.msg = "No response";
                        return;
                    }
                    const repdoc = Document(docbuf);
                    immutable repreceiver = hirpc.receive(repdoc);
                    if (repreceiver.isResponse){
                        const recorder_doc = repreceiver.message[Keywords.result].get!Document;
                        const reprecorder = record_factory.recorder(recorder_doc);
                        foreach(a; reprecorder[]){
                            Document filed = a.filed;
                            icache.update(DARTIndex(a.dart_index), filed, true);
                            found ~= a.filed;
                        }
                    }
                }
                HiBON params = new HiBON;
                foreach (i, b; found) {
                    params[i] = b;
                }
                Document response = hirpc.result(receiver, params).toDoc;
                rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                rep.type = ContentType.octet;
                rep.rawdata = cast(ubyte[])(response.serialize);
                break;
            case "bullseye":
                import crud = tagion.dart.DARTcrud;
                rc = query_socket_once(
                    opt.node_dart_addr,
                    opt.sock_recvtimeout,
                    opt.sock_recvdelay,
                    opt.sock_connectretry,
                    cast(ubyte[])crud.dartBullseye.toDoc.serialize,
                    docbuf
                );
                if (rc != 0) {
                    if(rc > 99 && rc < 600){
                        rep.status = cast(nng_http_status)rc;
                        writeit("dart_handler: query: ",rep.status);
                    }else{
                        writeit("dart_handler: query: ", nng_errstr(rc));
                        rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                    }    
                    rep.msg = "socket error";
                    return;
                }
                if (docbuf.empty) {
                    rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                    rep.msg = "No response";
                    return;
                }

                const repreceiver = HiRPC(null).receive(Document(docbuf.idup));

                if (!repreceiver.isResponse) {
                    rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                    rep.msg = "response error";
                    return;
                }

                if (req.path[$ - 1].hasExtension("json")) {
                    const dartindex = parseJSON(repreceiver.toPretty);
                    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                    rep.type = ContentType.json;
                    rep.json = dartindex;
                }
                else {
                    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                    rep.type = ContentType.octet;
                    rep.rawdata = cast(ubyte[]) repreceiver.serialize;
                }
                break;
            default:    
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "Invalid subject";
        }
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = ContentType.html;
        rep.msg = e.message().idup;
        rep.text = dump_exception_recursive(e, "handler: dartv2");
        return;
    }
}


/*
*
* /api/v2/trt/[read]
*
*/
static void trt_handler(WebData* req, WebData* rep, void* ctx) {
    thread_attachThis();
    rt_moduleTlsCtor();
    try {
        int rc;
        immutable(ubyte)[] docbuf;

        const net = new StdHashNet();
        auto record_factory = RecordFactory(net);
        const hirpc = HiRPC(null);
        
        ShellOptions* opt = cast(ShellOptions*) ctx;
        if (req.type != ContentType.octet) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }

        save_rpc(opt, Document(req.rawdata.idup));

        Document doc = Document(cast(immutable(ubyte[])) req.rawdata);
        immutable receiver = hirpc.receive(doc);
        if (!receiver.isMethod) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "Invalid request method";
            return;
        }
        
        auto subjects = req.path[(opt.shell_api_prefix_v2 ~ opt.dart_endpoint).split("/").length-1..$];
        auto subject = ( subjects.empty ) ? "read" : subjects[0];
       

        switch( subject ){
            case "read":
                auto doc_dart_indices = receiver.method.params[DART.Params.dart_indices].get!(Document);
                auto owner_pkeys = doc_dart_indices.range!(DARTIndex[]);

                DARTIndex[] tofetch;
                TRTArchive[] found;
                TRTArchive tbuf;
                foreach(o; owner_pkeys){
                     if (tcache.get(o, tbuf)) {
                        found ~= tbuf;
                     }else{
                        tofetch ~= o;    
                     }
                }
                writeit("FOUND ", found.length);
                writeit("Fetched ", tofetch.length);
                if(!tofetch.empty){
                    auto dreq = new HiBON;
                    auto dparam = new HiBON;
                    dreq = tofetch;
                    dparam[DART.Params.dart_indices] = dreq;
                    rc = query_socket_once(
                        opt.node_dart_addr,
                        opt.sock_recvtimeout,
                        opt.sock_recvdelay,
                        opt.sock_connectretry,
                        cast(ubyte[])(hirpc.action("trt." ~ DART.Queries.dartRead, dparam).toDoc.serialize),
                        docbuf
                    );
                    if (rc != 0) {
                        if(rc > 99 && rc < 600){
                            rep.status = cast(nng_http_status)rc;
                            writeit("trt_handler: query: ",rep.status);
                        }else{
                            writeit("trt_handler: query: ", nng_errstr(rc));
                            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                        }    
                        rep.msg = "socket error";
                        return;
                    }
                    if (docbuf.empty) {
                        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
                        rep.msg = "No response";
                        return;
                    }
                    const repdoc = Document(docbuf);
                    immutable repreceiver = hirpc.receive(repdoc);
                    if (repreceiver.isResponse){
                        const recorder_doc = repreceiver.message[Keywords.result].get!Document;
                        const reprecorder = record_factory.recorder(recorder_doc);
                        foreach(a; reprecorder[]
                                    .map!(a => a.filed)
                                    .filter!(doc => doc.isRecord!TRTArchive)
                                    .map!(doc => TRTArchive(doc))){
                            tcache.update(DARTIndex(net.dartIndex(a)), a, true);                                    
                            found ~= a;
                        }
                    }
                }
                auto result_recorder = record_factory.recorder;
                foreach (b; found.uniq) {
                    result_recorder.add(b);
                }
                Document response = hirpc.result(receiver, result_recorder.toDoc).toDoc;
                rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                rep.type = ContentType.octet;
                rep.rawdata = cast(ubyte[])(response.serialize);
                break;
            default:    
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "Invalid subject";
        }
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = ContentType.html;
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
        if (req.type != ContentType.octet) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
            rep.msg = "invalid data type";
            return;
        }

        save_rpc(opt, Document(req.rawdata.idup));

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

        auto receiver = sendSubmitHiRPC(options.contract_address, hirpc_submit, hirpc);
        wallet_interface.save(false);

        writeit("i2p: payment sent");

        //dfmt off
        const wallet_update_switch = WalletInterface.Switch(
            update : true,
            sendkernel: true);
        //dfmt on

        wallet_interface.operate(wallet_update_switch, []);

        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        rep.type = ContentType.octet;
        rep.rawdata = cast(ubyte[])(receiver.toDoc.serialize);
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = ContentType.html;
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
        rep.type = ContentType.json;
        rep.json = data;
    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = ContentType.html;
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
                rep.type = ContentType.json;
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
                        ["Content-type": ContentType.octet]);
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
                rep.type = ContentType.json;
                rep.json = parseJSON(format(`{"test": "%s", "passed": "ok", "result":{"count": %d}}`, reqpath[0], cnt));
                break;
            default:
                break;
            }
        }

        if (rep.status != nng_http_status.NNG_HTTP_STATUS_OK) {
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = ContentType.html;
            rep.text = "<h2>The requested test couldn`t be processed</h2>\n\r<pre>\n\r" ~ to!string(
                    reqpath) ~ "\r\n" ~ rep.msg ~ "\r\n" ~ rep.text ~ "\n\r</pre>\n\r";
        }

    }
    catch (Throwable e) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_SERVICE_UNAVAILABLE;
        rep.type = ContentType.html;
        rep.msg = e.message().idup;
        rep.text = dump_exception_recursive(e, "handler: selftest");
        return;
    }
}

void versioninfo_handler(WebData* req, WebData* rep, void* ctx) {
    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
    rep.type = ContentType.html;
    rep.text = imported!"tagion.tools.revision".revision_text;
}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    GetoptResult main_args;

    ShellOptions options;
    bool override_switch;

    long sz, isz;

    auto default_shell_config_filename = "shell".setExtension(FileExtension.json);
    const user_config_file = args.countUntil!(file => file.hasExtension(FileExtension.json) && file.exists);
    auto config_file = (user_config_file < 0) ? default_shell_config_filename : args[user_config_file];

    if (config_file.exists) {
        try {
            options.load(config_file);
        }
        catch (Exception e) {
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
                "O|override", "Override the config file", &override_switch,
        );
    }
    catch (GetOptException e) {
        stderr.writeit(e.message().idup);
        return 1;
    }

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

    if (override_switch) {
        options.save(config_file);
        writefln("Config file written to %s", config_file);
        return 0;
    }

    if(options.cache_enabled) {
        tcache = new shared(TRTCache)(null, cast(immutable) options.dartcache_size, cast(immutable) options
                .dartcache_ttl_msec);
        icache = new shared(IndexCache)(null, cast(immutable) options.dartcache_size, cast(immutable) options
                .dartcache_ttl_msec);
        auto ds_tid = spawn(&dart_worker, options);
    }


    writeit("\nTagionShell web service\nListening at "
            ~ options.shell_uri ~ "\n\t"
            ~ options.shell_api_prefix
            ~ options.contract_endpoint
            ~ "\t= POST contract hibon\n\t"
            ~ options.shell_api_prefix
            ~ options.dart_endpoint ~ "/[nocache]"
            ~ "\t= POST dart request hibon (depending on the method send raw request or use cache for pkeys)\n\t"
            ~ options.shell_api_prefix
            ~ options.i2p_endpoint
            ~ "\t= POST invoice-to-pay hibon\n\t"
            ~ options.shell_api_prefix
            ~ options.bullseye_endpoint ~ ".hibon"
            ~ "\t= GET dart bullseye json\n\t"
            ~ options.shell_api_prefix
            ~ options.bullseye_endpoint ~ ".json"
            ~ "\t= GET dart bullseye hibon\n\t"
            ~ options.shell_api_prefix_v2
            ~ "/trt" ~ "/<subject>"
            ~ "\t\t= POST TRT request hibon list of public key indices()\n\t"
            ~ "\t\t== /read \t- collect DART indices for specific owners\n\t"
            ~ options.shell_api_prefix_v2
            ~ "/dart" ~ "/<subject>"
            ~ "\t\t= POST DART request hibon list of dart indices()\n\t"
            ~ "\t\t== /[raw] \t- proxy request as is\n\t"
            ~ "\t\t== /read \t- collect bills by indices\n\t"
            ~ "\t\t== /checkread \t- check and collect bills by indices\n\t"
            ~ "\t\t== /bullseye.[hibin,json] \t- get bullseye\n\t"
            ~ options.shell_api_prefix
            ~ options.sysinfo_endpoint
            ~ "\t\t= GET system info\n\t"
            ~ options.shell_api_prefix
            ~ options.version_endpoint
            ~ "\t\t= GET network version info\n\t"
            ~ options.shell_api_prefix
            ~ options.selftest_endpoint ~ "/<endpoint>"
            ~ " = GET self test results\n\t"
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
    app.route(options.shell_api_prefix ~ options.dart_endpoint, &dart_handler_alt, ["POST"]);
    app.route(options.shell_api_prefix ~ options.dart_endpoint ~ "/nocache", &dart_handler_alt, ["POST"]);
    app.route(options.shell_api_prefix_v2 ~ options.trt_endpoint, &trt_handler, ["POST"]);
    app.route(options.shell_api_prefix_v2 ~ options.trt_endpoint ~ "/read", &trt_handler, ["POST"]);
    app.route(options.shell_api_prefix_v2 ~ options.dart_endpoint, &dart_handler_v2, ["POST"]);
    app.route(options.shell_api_prefix_v2 ~ options.dart_endpoint ~ "/raw", &dart_handler_v2, ["POST"]);
    app.route(options.shell_api_prefix_v2 ~ options.dart_endpoint ~ "/read", &dart_handler_v2, ["POST"]);
    app.route(options.shell_api_prefix_v2 ~ options.dart_endpoint ~ "/checkread", &dart_handler_v2, ["POST"]);
    app.route(options.shell_api_prefix_v2 ~ options.dart_endpoint ~ "/bullseye", &dart_handler_v2, ["GET"]);
    app.route(options.shell_api_prefix_v2 ~ options.dart_endpoint ~ "/bullseye.json", &dart_handler_v2, ["GET"]);
    app.route(options.shell_api_prefix_v2 ~ options.dart_endpoint ~ "/bullseye.hibon", &dart_handler_v2, ["GET"]);
    app.route(options.shell_api_prefix ~ options.i2p_endpoint, &i2p_handler, ["POST"]);
    app.route(options.shell_api_prefix ~ options.selftest_endpoint ~ "/*", &selftest_handler, ["GET"]);
    app.route(options.shell_api_prefix ~ options.version_endpoint, &versioninfo_handler, ["GET"]);

    app.start();

    if (options.save_rpcs_enable) {
        import tagion.actor;
        import tagion.tools.shell.contracts;

        _spawn!(RPCSaver)(options.save_rpcs_task);
    }

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
