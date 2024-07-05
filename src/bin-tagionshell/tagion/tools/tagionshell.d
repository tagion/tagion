module tagion.tools.tagionshell;

import core.time;
import core.memory;
import std.algorithm;
import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.path : setExtension, buildPath;
import std.file : exists;
import std.format;
import std.getopt;
import std.json;
import std.typecons;
import std.range;
import std.base64;
import std.string : representation;
import std.stdio : File, toFile, stderr, stdout, writefln, writeln;
import std.datetime.systime : Clock;
import std.digest.crc;
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
import tagion.dart.DARTBasic : DARTIndex, dartKey, dartIndex, Params;
import tagion.dart.Recorder;
import crud = tagion.dart.DARTcrud;
import tagion.logger.subscription;
import tagion.Keywords;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.standardnames;
import tagion.tools.Basic;
import tagion.tools.revision;
import tagion.tools.shell.shelloptions;
import tagion.tools.shell.contracts;
import tagion.tools.wallet.WalletInterface;
import tagion.wallet.request;
import tagion.tools.wallet.WalletOptions;
import tagion.utils.StdTime : currentTime;
import tagion.wallet.AccountDetails;
import tagion.wallet.SecureWallet;
import tagion.utils.LRUT;
import tagion.hashgraphview.EventView;
import tagion.communication.Envelope;
import tagion.tools.dartutil.dartindex;

import core.thread;
import nngd.nngd;

mixin Main!(_main, "shell");

alias IndexCache = LRUT!(DARTIndex, Document);

shared IndexCache tcache;
shared IndexCache icache;

struct ws_device {
    WebSocket *ws;
    void  *ctx;
    string[] topics;
/*    
    this ( WebSocket* _w, void* _c, string[] _t ) {
        ws = ast (shared WebSocket*) _w;
        ctx = cast (shared void* )_c;
        topics = cast ( shared string[] )_t;
    };
*/    
}

alias WSCache = LRUT!(string, ws_device);

shared WSCache ws_devices;

shared static bool abort = false;

enum HTTPMethod {
    GET = "GET",
    POST = "POST",
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
}

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

JSONValue json_dehibonize(JSONValue obj)
{
    if(obj.type() == JSONType.object){
        foreach( string key, val; obj)
        {
            if(val.type() == JSONType.array)
            {
                if(val.array.length == 2 && val.array[0].type() == JSONType.string){
                    auto t = (val.array[0]).str;
                    auto x = val.array[1];
                    if(x.type() == JSONType.integer)
                    {
                        obj[key] = x.integer;
                    }
                    else if(x.type() == JSONType.uinteger)
                    {
                        obj[key] = x.uinteger;
                    }
                    else if (x.type() == JSONType.float_)
                    {
                        obj[key] = x.floating;    
                    }
                    else
                    {
                        if(x.type() != JSONType.string){
                            writeit("##### JERR: ",val);
                        }
                        auto y = x.str;
                        switch(t){
                            case "i32":
                                obj[key] = y.startsWith("0x") ? to!int(y[2..$],16) : to!int(y,10);
                                break;
                            case "u32":
                                obj[key] = y.startsWith("0x") ? to!uint(y[2..$],16) : to!uint(y,10);
                                break;
                            case "i64":
                                if(y == "0x8000000000000000"){
                                    obj[key] = long.max;
                                } else {    
                                    obj[key] = y.startsWith("0x") ? to!long(y[2..$],16) : to!long(y,10);
                                }    
                                break;
                            case "u64":
                                obj[key] = y.startsWith("0x") ? to!ulong(y[2..$],16) : to!ulong(y,10);
                                break;
                            case "f32":
                                if(y.startsWith("0x")){
                                    auto z = to!uint(y[2..$],16);
                                    obj[key] = *cast(float*)&z;
                                }else{
                                    obj[key] = to!float(y);
                                }
                                break;
                            case "f64":
                                if(y.startsWith("0x")){
                                    auto z = to!ulong(y[2..$],16);
                                    obj[key] = *cast(double*)&z;
                                }else{
                                    obj[key] = to!double(y);
                                }
                                break;
                            default:
                                break;
                        }
                    }
                } else {
                    obj[key] = json_dehibonize(val);;
                }
            }
            if(val.type() == JSONType.object)
            {
                obj[key] = json_dehibonize(val);
            }
        }
    } else if (obj.type() == JSONType.array) {
        obj = obj.array.map!( x => json_dehibonize(x) ).array();
    }
    return obj;
}

JSONValue json_remap( JSONValue obj, JSONValue map )
{
    JSONValue res = parseJSON("{}");
    foreach( string key, val; obj){
        auto k2 = (key in map) ? map[key].str : key;
        if(val.type() == JSONType.object){
            res[k2] = json_remap(val, map);
        } else {
            res[k2] = val;
        } 
    }
    return res;
}

/* 
 * Params: void function(WebData*, WebData*, ShellOptions*)
 *
 * Returns: An NNG Webhandler function
 */
webhandler handler_helper(alias cb)() {
    return (WebData* req, WebData* rep, void* ctx) {
        try {
            thread_attachThis();
            rt_moduleTlsCtor();
            ShellOptions* opt = cast(ShellOptions*) ctx;
            cb(req, rep, opt);
        } catch(Throwable e) {
            import tagion.utils.Random;
            uint error_id = generateId!uint();
            rep.status = nng_http_status.NNG_HTTP_STATUS_INTERNAL_SERVER_ERROR;
            rep.type = mime_type.HTML;
            rep.text = format!"<!DOCTYPE html>\n<html>\n<body>\nInternal Error<br>\nerror_id %s: %s\n</html>\n</body>"(error_id, e.msg);
            stderr.writefln!"error_id %s\n%s"(error_id, dump_exception_recursive(e, fullyQualifiedName!cb, ExceptionFormat.PLAIN));
        }
    };
}

void dart_worker(ShellOptions opt) {
    int rc;
    int attempts = 0;
    const monitor_map = JSONValue([
        "$m": "mother",
        "$f": "father",
        "$n": "node_id",
        "$a": "altitude",
        "$o": "order",
        "$r": "round",
        "$rec": "round_received",
        "$w": "witness",
        "$famous": "famous",
        "$error": "error",
        "father_less": "father_less"
    ]);
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
    const net = new StdHashNet();
    auto record_factory = RecordFactory(net);
    const hirpc = HiRPC(null);
    s.recvtimeout = msecs(opt.sock_recvtimeout);
    s.subscribe(opt.recorder_subscription_tag);
    s.subscribe(opt.trt_subscription_tag);
    s.subscribe(opt.monitor_subscription_tag);
    writeit("DS: subscribed");
    while (true) {
        rc = s.dial(opt.tagion_subscription_addr);
        if (rc == 0)
            break;
        enforce(++attempts < opt.sock_connectretry, "Couldn`t connect the subscription socket");
    }
    scope (exit) {
        s.close();
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
            JSONValue jdoc;
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
            if(topic.startsWith("recorder")){
                auto recorder = record_factory.recorder(payload.data);
                if(opt.cache_enabled){
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
                }
                jdoc = json_dehibonize(recorder.toJSON);
            } else 
            if(topic.startsWith("trt_created")){
                auto recorder = record_factory.recorder(payload.data);
                if(opt.cache_enabled){
                    auto empty_archive = Document();
                    foreach (a; recorder[]) {
                        if (a.type is Archive.Type.REMOVE) {
                            tcache.update(DARTIndex(a.dart_index), empty_archive, true);
                        } else {
                            Document filed = a.filed;
                            tcache.update(DARTIndex(a.dart_index), filed, true);
                        }
                        k++;
                    }
                }
                jdoc = json_dehibonize(recorder.toJSON);
            }else
            if(topic.startsWith("monitor")){
                auto adoc = EventView(payload.data);
                jdoc = adoc.toJSON;
                jdoc = json_dehibonize(json_remap(jdoc, monitor_map));
            }else{
                writeit("DS: unknown topic: "~topic);
                return;
            }
            // websocket sends json serializations prepended with channel token separated with zero byte
            ws_propagate(topic,jdoc.toString);
            if (k > 0)
                writeit(format("DS: Cache updated in %d objects", k));
        }
        catch (Throwable e) {
            writeit(dump_exception_recursive(e, "worker: dartcache", ExceptionFormat.PLAIN));
            continue;
        }
    }
}


void ws_propagate(string topic, string msg){
    ws_device d;
    foreach(sid; ws_devices.keys()){
        if(ws_devices.get(sid,d)){
            if(count!"b.startsWith(a)"(d.topics, topic) > 0){
                WebSocket *ws = cast(WebSocket*)d.ws;
                    if(ws != null && ! ws.closed)
                        ws.send(cast(ubyte[])(topic~"\0"~msg));
            }
        }
    }        
}

void ws_on_connect(WebSocket *ws, void *ctx){
    writeit("ws: connect");
    Thread.sleep(500.msecs);
    auto sid = ws.sid;
    writeit("WS: ONCONNECT: ", sid);
    if(ws_devices.contains(sid)){
        writeit("Already cached socket: ", sid);
        return;
    }
    auto d = ws_device(ws, ctx, []);
    ws_devices.add(sid,d);
    writeit("WS: D0");
}

void ws_on_close(WebSocket *ws, void *ctx){
    auto sid = ws.sid;
    writeit("WS: ONCLOSE: ", sid);
    if( ws_devices.contains(sid)){
        ws_devices.remove(sid);
    }
}

void ws_on_error(WebSocket *ws, int err, void *ctx){
    writeit("WS: ONERROR: ", err);
}

void ws_on_message(WebSocket *ws, ubyte[] data, void *ctx){
    auto sid = ws.sid;
    string msg = cast(immutable(char[]))data;
    writeit("WS MSG: ",sid," : ",msg);
    ws_device d;
    if(ws_devices.get(sid,d)){
        auto sa = msg.split("\0");
        if(sa[0] == "subscribe"){
            if(!d.topics.canFind(sa[1])){
                d.topics ~= sa[1];
                ws_devices.update(sid,d);
            }    
        }else if(sa[0] == "unsubscribe"){
            if(d.topics.canFind(sa[1])){
                d.topics = d.topics.remove!(x => x == sa[1]);
                ws_devices.update(sid,d);
            }                
        }else{
            writeit("WS: MSG: Invalid topic: ", sa);
        }
   }
}

/*
* query REQ/REP socket once and close it 
*/
int query_socket_once(string addr, uint timeout, uint delay, uint retries,  const ubyte[] request, out immutable(ubyte)[] reply) {
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
* /api/v1/hirpc
*
*/
const hirpc_handler = handler_helper!hirpc_handler_impl;
void hirpc_handler_impl(WebData* req, WebData* rep, ShellOptions* opt) {
    int rc;
    writeit("hirpc handler start");
    immutable(ubyte)[] docbuf;
    size_t doclen;

    const net = new StdHashNet();
    auto record_factory = RecordFactory(net);
    const hirpc = HiRPC(null);

    if (req.type != mime_type.BINARY) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
        rep.msg = "invalid data type";
        return;
    }
    
    const epack = Envelope(cast(immutable)req.rawdata);
    const rawbuf = (!epack.errorstate && epack.header.isValid()) ? epack.toData() : req.rawdata;
    Document doc = Document(cast(immutable(ubyte[]))rawbuf);
    save_rpc(opt, doc);

    bool cache_enabled = opt.cache_enabled && req.path[$-1] == "nocache";

    immutable receiver = hirpc.receive(doc);
    if (!receiver.isMethod) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
        rep.msg = "HIRPC: Invalid request method";
        return;
    }

    ulong[string] stats = [ "requests": 0, "tofetch": 0 ];
    
    string method = receiver.method.name;
    /* string method = opt.cache_enabled ? receiver.method.name : "unprocessed"; */

    writeit("HIRPC: got method: " ~ method);

    string sockaddr = opt.node_dart_addr;
    uint recvtimeout = opt.sock_recvtimeout;
    uint recvdelay = opt.sock_recvdelay;
    uint connectretry = opt.sock_connectretry;

    switch(method){
        case "dartRead":
            if(!cache_enabled) {
                goto default;
            }
            auto entity_cache = (receiver.method.entity == "trt")
                ? tcache 
                : icache;

            auto indices = receiver
                .method
                .params[Params.dart_indices]
                .get!(Document)
                .range!(DARTIndex[]);

            DARTIndex[] itofetch;
            Document[] ifound;
            Document ibuf;
            stats["idx_found"] = 0;
            stats["idx_fetched"] = 0;
            // Find which indices are missing from the cache
            foreach(idx; indices){
                 stats["requests"]++;
                 if (entity_cache.get(idx, ibuf)) {
                    ifound ~= ibuf;
                 }else{
                    itofetch ~= idx;   
                    stats["tofetch"]++;
                 }
            }
            stats["idx_found"] = ifound.length;

            if(!itofetch.empty) {
                const full_method = receiver.method.full_name;
                const sender = crud.dartIndexCmd(full_method, itofetch);
                // Fetch archives not in cache
                rc = query_socket_once(
                    opt.node_dart_addr,
                    opt.sock_recvtimeout,
                    opt.sock_recvdelay,
                    opt.sock_connectretry,
                    cast(ubyte[])sender.toDoc.serialize,
                    docbuf
                );
                if (rc != nng_errno.NNG_OK) {
                    if(rc > 99 && rc < 600) {
                        rep.status = cast(nng_http_status)rc;
                        writeit("hirpc_handler: ", full_method, " query: ", rep.status);
                    } else {
                        writeit("hirpc_handler: ", full_method, " query: ", nng_errstr(rc));
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

                // Add missing archives to cache including non existent ones
                Document empty_doc;
                foreach(a; reprecorder[]) {
                    Document filed = a.filed;
                    entity_cache.update(a.dart_index, filed, true);
                    ifound ~= filed;
                    itofetch = itofetch.remove!(x => x == a.dart_index);
                }
                foreach(idx; itofetch) {
                    entity_cache.update(idx, empty_doc, true);
                }
            }
            stats["idx_fetched"] = ifound.length - stats["idx_found"];

            auto result_recorder = record_factory.recorder;
            const empty_doc = Document();
            foreach (b; ifound.filter!(a => a !is empty_doc).uniq) {
                result_recorder.add(b);
            }
            Document response = hirpc.result(receiver, result_recorder.toDoc).toDoc;
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = mime_type.BINARY;
            rep.rawdata = cast(ubyte[])(response.serialize);
            return;
        case "submit":
            sockaddr = opt.node_contract_addr;
            // Not Sure if this is needed. Submit should be a faster request, since it doesn't retrieve any data from the system.
            recvtimeout = opt.sock_recvtimeout * 6;
            break;
        default:
            sockaddr = opt.node_dart_addr;
            break;
    } // switch method
    
    rc = query_socket_once(
        sockaddr, // TODO: clarify if it is a common socket for all hirpc and maybe rename it
        recvtimeout,
        recvdelay,
        connectretry,
        rawbuf,
        docbuf
    );
    if (rc != 0) {
        if(rc > 99 && rc < 600){
            rep.status = cast(nng_http_status)rc;
            writeit("hirpc_handler: query: ",rep.status);
        }else{
            writeit("hirpc_handler: query: ", nng_errstr(rc));
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
    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
    rep.type = mime_type.BINARY;
    rep.rawdata = (doclen > 0) ? docbuf.dup[0 .. doclen] : null;

    writeit("STATS: ", stats);
}



// ---------------- non-hirpc handlers


const bullseye_handler = handler_helper!bullseye_handler_impl;
void bullseye_handler_impl(WebData* req, WebData* rep, ShellOptions* opt) {
    int attempts = 0;

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

    switch(req.path[$ - 1]) {
        case "json":
            const dartindex = parseJSON(receiver.toPretty);
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = mime_type.JSON;
            rep.json = dartindex;
            break;
        case "hibon":
        default:
            rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            rep.type = mime_type.BINARY;
            rep.rawdata = cast(ubyte[]) receiver.serialize;
            break;
    }
}


const i2p_handler = handler_helper!i2p_handler_impl;
void i2p_handler_impl(WebData* req, WebData* rep, ShellOptions* opt) {
    int rc;
    if (req.type != mime_type.BINARY) {
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

    auto receiver = sendKernelHiRPC(options.contract_address, hirpc_submit, hirpc);
    wallet_interface.save(false);

    writeit("i2p: payment sent");

    //dfmt off
    const wallet_update_switch = WalletInterface.Switch(
        update : true,
        sendkernel: true);
    //dfmt on

    wallet_interface.operate(wallet_update_switch, []);

    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
    rep.type = mime_type.BINARY;
    rep.rawdata = cast(ubyte[])(receiver.toDoc.serialize);
}

const sysinfo_handler = handler_helper!sysinfo_handler_impl;
void sysinfo_handler_impl(WebData* req, WebData* rep, ShellOptions* opt) {
    JSONValue data = parseJSON("{}");
    data["memsize"] = getmemstatus();
    if(opt.cache_enabled){
        data["cache"] = parseJSON("{}");
        data["cache"]["index"] = tcache.length;
        data["cache"]["archive"] = icache.length;
    }    
    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
    rep.type = mime_type.JSON;
    rep.json = data;
}

const selftest_handler = handler_helper!selftest_handler_impl;
void selftest_handler_impl(WebData* req, WebData* rep, ShellOptions* opt) {
    int rc;
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
            WebData hrep = WebClient.get(uri ~ opt.bullseye_endpoint ~ "/json", null);
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
            rep.type = mime_type.JSON;
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
                    ["Content-type": mime_type.BINARY]);
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
            rep.type = mime_type.JSON;
            rep.json = parseJSON(format(`{"test": "%s", "passed": "ok", "result":{"count": %d}}`, reqpath[0], cnt));
            break;
        default:
            break;
        }
    }

    if (rep.status != nng_http_status.NNG_HTTP_STATUS_OK) {
        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
        rep.type = mime_type.HTML;
        rep.text = "<h2>The requested test couldn`t be processed</h2>\n\r<pre>\n\r" ~ to!string(
                reqpath) ~ "\r\n" ~ rep.msg ~ "\r\n" ~ rep.text ~ "\n\r</pre>\n\r";
    }
}

const lookup_handler = handler_helper!lookup_handler_impl;
void lookup_handler_impl(WebData* req, WebData* rep, ShellOptions* opt) {
    string query_subject = req.path[$ - 2];
    writeit("2B64: ",req.path[$ - 1]);
    string query_str = cast(immutable(char)[])(Base64.decode(req.path[$ - 1]));
    NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
    int rc;
    int attempts = 0;
    while (true) {
        rc = s.dial(opt.node_dart_addr);
        if (rc == 0)
            break;
        enforce(++attempts < opt.sock_connectretry, "Couldn`t connect the kernel socket");
    }
    scope (exit) {
        s.close();
    }
    switch(query_subject){
        case "dart":
            DARTIndex drtindex = hash_net.dartIndexDecode(query_str);
            rc = s.send(crud.dartRead([drtindex]).toDoc.serialize);
            ubyte[4096] buf;
            size_t len = s.receivebuf(buf, buf.length);
            if (len == size_t.max && s.errno != 0) {
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "socket error";
                return;
            }
            const receiver = HiRPC(null).receive(Document(buf.idup[0..len]));
            const jresult = receiver.result.toJSON;
            rep.type = mime_type.JSON;
            rep.json = jresult;
            break;
        case "trt":    
            DARTIndex drtindex = hash_net.dartIndexDecode(query_str);
            rc = s.send(crud.trtdartRead([drtindex]).toDoc.serialize);
            ubyte[4096] buf;
            size_t len = s.receivebuf(buf, buf.length);
            if (len == size_t.max && s.errno != 0) {
                rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                rep.msg = "socket error";
                return;
            }
            const receiver = HiRPC(null).receive(Document(buf.idup[0..len]));
            const jresult = receiver.result.toJSON;
            rep.type = mime_type.JSON;
            rep.json = jresult;
            break;
        case "transaction":
            rep.type = mime_type.JSON;
            rep.json = JSONValue(["error": "not implemented yet"]);
            break;
        case "record":
            rep.type = mime_type.JSON;
            rep.json = JSONValue(["error": "not implemented yet"]);
            break;
        default:
            rep.type = mime_type.JSON;
            rep.json = JSONValue(["error": "unknown subject"]);
            break;
    }
    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
}

void versioninfo_handler(WebData* req, WebData* rep, void* _) nothrow {
    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
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
            "Documentation: https://docs.tagion.org/",
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
        tcache = new shared(IndexCache)(null, cast(immutable) options.dartcache_size, cast(immutable) options
                .dartcache_ttl_msec);
        icache = new shared(IndexCache)(null, cast(immutable) options.dartcache_size, cast(immutable) options
                .dartcache_ttl_msec);
    }
    auto ds_tid = spawn(&dart_worker, options);

    if(!options.ws_pub_uri.empty){
        //auto ws_tid = spawn(&ws_worker, options);
        ws_devices = new shared(WSCache)(null, 512, 0); // TODO: hardcoded session cache size -> options
        WebSocketApp wsa = WebSocketApp(options.ws_pub_uri, &ws_on_connect, &ws_on_close, &ws_on_error, &ws_on_message, cast(void*)&options );
        wsa.start();
    }
    


    Appender!string help_text;

    void add_v1_route(ref WebApp _app, string endpoint, webhandler handler, HTTPMethod[] methods, string description, string[string] variations = string[string].init) {
        _app.route(options.shell_api_prefix ~ endpoint, handler, cast(string[])methods);
        help_text ~= format!"\t%-25s= %s %s\n"(options.shell_api_prefix ~ endpoint, methods, description);
        foreach(k, v; variations) {
            _app.route(options.shell_api_prefix ~ endpoint ~ k, handler, cast(string[])methods);
            help_text ~= format!"\t\t== %-15s - %s\n"(k, v);
        }
    }

    isz = getmemstatus();

appoint:

    WebApp app = WebApp("ShellApp", options.shell_uri, parseJSON(`{"root_path":"`~options.webroot~`","static_path":"`~options.webstaticdir~`"}`), &options);

    help_text ~= ("TagionShell web service\n");
    help_text ~= ("Listening at " ~ options.shell_uri ~ "\n\n");
    add_v1_route(app, options.i2p_endpoint, i2p_handler, [HTTPMethod.POST], "invoice-to-pay hibon");
    add_v1_route(app, options.bullseye_endpoint, bullseye_handler, [HTTPMethod.GET], "the dart bullseye", [
        "/json": "Result in json format",
        "/hibon": "Result in hibon format",
    ]);
    add_v1_route(app, options.sysinfo_endpoint, sysinfo_handler, [HTTPMethod.GET], "system info");
    add_v1_route(app, options.version_endpoint, &versioninfo_handler, [HTTPMethod.GET], "network version info");
    add_v1_route(app, options.hirpc_endpoint, hirpc_handler, [HTTPMethod.POST], "Any HiRPC call", [
        "/nocache": "Avoid using the cache on dartRead methods"
    ]);
    add_v1_route(app, options.contract_endpoint, hirpc_handler, [HTTPMethod.POST], "contract hibon");
    add_v1_route(app, options.dart_endpoint, hirpc_handler, [HTTPMethod.POST], "dartCrud methods", [
        "/nocache": "Avoid using the cache on dartRead methods"
    ]);
    add_v1_route(app, options.selftest_endpoint, selftest_handler, [HTTPMethod.GET], "self test results", [
        "/bullseye": "test bullseye endpoint",
        "/dart": "test dart request endpoint",
    ]);
    add_v1_route(app, options.lookup_endpoint~"/*", lookup_handler, [HTTPMethod.GET], "lookup by ID");

    writeit(help_text.data);
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
