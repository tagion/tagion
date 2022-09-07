module tagion.services.DARTService;

import core.thread;
import std.concurrency;

import p2plib = p2p.node;
import p2p.connection;
import p2p.callback;
import p2p.cgo.c_helper;
import std.getopt;
import std.stdio;
import std.conv;
import std.array;

import tagion.logger.Logger;
import tagion.basic.Types : Buffer, Control;
import tagion.basic.TagionExceptions;

import tagion.utils.Miscellaneous : toHexString, cutHex;
import tagion.dart.DARTFile;
import tagion.dart.DART;

version (unittest)
{
    import tagion.dart.BlockFile : fileId;
}
import tagion.basic.Basic;
import tagion.Keywords;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.dart.DARTSynchronization;
import tagion.dart.Recorder : RecordFactory;

import tagion.services.Options;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document;
import tagion.hibon.HiBON : HiBON;
import tagion.communication.HandlerPool;

import tagion.communication.HiRPC;
import tagion.services.DARTSynchronizeService;

//import tagion.services.MdnsDiscoveryService;
import tagion.gossip.P2pGossipNet : ConnectionPool;
import tagion.gossip.AddressBook : NodeAddress;

alias HiRPCSender = HiRPC.HiRPCSender;
alias HiRPCReceiver = HiRPC.HiRPCReceiver;

void dartServiceTask(Net : SecureNet)(
    immutable(Options) opts,
    shared(p2plib.Node) node,
    shared(Net) master_net,
    immutable(DART.SectorRange) sector_range) nothrow
{
    try
    {
        scope (success)
        {
            ownerTid.prioritySend(Control.END);
        }

        setOptions(opts);
        immutable task_name = opts.dart.task_name;
        auto pid = opts.dart.protocol_id;
        log.register(task_name);

        log("-----Start DART service-----");
        bool stop = false;
        void handleControl(Control ts)
        {
            with (Control) switch (ts)
            {
            case STOP:
                log("Kill dart service");
                stop = true;
                break;
            default:
                log.error("Bad Control command %s", ts);
            }
        }

        const is_active_node = opts.port == opts.dart.subs.master_port;
        Tid subscribe_handler_tid;
        if (is_active_node)
        {
            log("Handling for subscription");
            node.listen(
                opts.dart.subs.protocol_id,
                &StdHandlerCallback,
                opts.dart.subs.master_task_name,
                opts.dart.subs.host.timeout.msecs,
                cast(uint) opts.dart.subs.host.max_size);
            subscribe_handler_tid = spawn(&subscibeHandler, opts);
        }
        scope (exit)
        {
            if (is_active_node)
            {
                node.closeListener(opts.dart.subs.protocol_id);
                send(subscribe_handler_tid, Control.STOP);
                receiveOnly!Control;
            }
        }

        node.listen(pid, &StdHandlerCallback, task_name,
            opts.dart.host.timeout.msecs, cast(uint) opts.dart.host.max_size);
        scope (exit)
        {
            node.closeListener(pid);
        }

        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))(
            opts.dart.host.timeout.msecs);

        auto dart_sync_tid = locate(opts.dart.sync.task_name);

        auto net = new Net();
        net.derive(opts.dart.task_name, master_net);

        auto hirpc = HiRPC(net);
        auto empty_hirpc = HiRPC(null);
        //hirpc.net = net;

        auto requestPool = new StdHandlerPool!(ResponseHandler, uint)(
            opts.dart.commands.read_timeout.msecs);

        pragma(msg, "fixme(cbr): shared address book should be used instead of local address book");
        NodeAddress[string] node_addrses;

        void dartHiRPC(string taskName, immutable(HiRPC.Sender) sender)
        {
            /// Note use to be (string taskName, Buffer data) {

            log("DS: Received request from service: %s", taskName);

            immutable receiver = empty_hirpc.receive(sender);
            //immutable method = receiver.method.name; ;

            void readDART()
            {
                scope doc_fingerprints = receiver.method.params[DARTFile.Params.fingerprints].get!(
                    Document);
                scope fingerprints = doc_fingerprints.range!(Buffer[]);
                alias bufArr = Buffer[];
                bufArr[NodeAddress] remote_fp_requests;
                Buffer[] local_fp;
                fpIterator: foreach (fp; fingerprints)
                {
                    const rims = DART.Rims(fp);
                    if (sector_range.inRange(rims))
                    {
                        local_fp ~= fp;
                        continue fpIterator;
                    }
                    else
                    {
                        foreach (address, fps; remote_fp_requests)
                        {
                            if (address.sector.inRange(rims))
                            {
                                fps ~= fp;
                                remote_fp_requests[address] = fps;
                                continue fpIterator;
                            }
                        }
                        foreach (id, address; node_addrses)
                        {
                            if (address.sector.inRange(rims))
                            {
                                remote_fp_requests[address] = [fp];
                                continue fpIterator;
                            }
                        }
                    }
                    throw new TagionException("No address for fp");
                }
                // auto recorder=dart.loads(local_fp, DARTFile.Recorder.Archive.Type.ADD);
                auto rs = cast(ResponseHandler)(new ReadRequestHandler(array(fingerprints),
                        hirpc, taskName, receiver));
                // if(local_fp.length>0){
                //     requestPool.setResponse(ResponseHandler.Response!uint(hrpc_id, empty_hirpc.result(receiver, recorder.toHiBON).toHiBON(net).serialize));
                // }
                requestPool.add(receiver.method.id, rs);
                Buffer requestData(HiRPC hirpc, bufArr fps)
                {
                    auto params = new HiBON;
                    auto params_fingerprints = new HiBON;
                    foreach (i, b; fps)
                    {
                        if (b.length !is 0)
                        {
                            params_fingerprints[i] = b;
                        }
                    }
                    params[DARTFile.Params.fingerprints] = params_fingerprints;
                    const request = hirpc.dartRead(params, receiver.method.id);
                    return request.toDoc.serialize;
                }

                if (remote_fp_requests.length > 0)
                {
                    import std.array;

                    foreach (addr, fps; remote_fp_requests)
                    {
                        auto stream = node.connect(addr.address,
                            addr.is_marshal, [opts.dart.sync.protocol_id]);
                        // connectionPool.add(stream.Identifier, stream);
                        stream.listen(&StdHandlerCallback, task_name,
                            opts.dart.sync.host.timeout.msecs, opts.dart.sync.host.max_size);
                        immutable foreign_data = requestData(hirpc, fps);
                        stream.writeBytes(foreign_data);
                    }
                }
                if (local_fp.length > 0)
                {
                    immutable foreign_data = requestData(empty_hirpc, local_fp);
                    dart_sync_tid.send(opts.dart.task_name, foreign_data);
                }
            }

            void modifyDART()
            { //TODO: not implemented yet
                //HiRPC.check_element!Document(receiver.params, DARTFile.Params.recorder);
                auto mrh = cast(ResponseHandler)(new ModifyRequestHandler(hirpc,
                        taskName, receiver));
                requestPool.add(receiver.method.id, mrh);
                dart_sync_tid.send(sender);
            }

            if (receiver.method.name == DART.Quries.dartRead)
            {
                readDART();
            }
            else if (receiver.method.name == DART.Quries.dartModify)
            {
                modifyDART();
            }
        }

        enum recorder_hrpc_id = 1;
        log("sending live");
        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            pragma(msg, "fixme(alex): 1000.msecs shoud be an option");
            receiveTimeout(
                1000.msecs,
                &handleControl,
                (Response!(ControlCode.Control_Connected) resp) {
                log("DS: Client Connected key: %d", resp.key);
                connectionPool.add(resp.key, resp.stream, true);
            },
                (Response!(ControlCode.Control_Disconnected) resp) {
                log("DS: Client Disconnected key: %d", resp.key);
                connectionPool.close(cast(void*) resp.key);
            },
                (Response!(ControlCode.Control_RequestHandled) resp) {
                log("DS: response received");

                scope (exit)
                {
                    if (resp.stream !is null)
                    {
                        destroy(resp.stream);
                    }
                }
                auto doc = Document(resp.data);
                auto message_doc = doc[Keywords.message].get!Document;
                void closeConnection()
                {
                    log("DSS: Forced close connection");
                    connectionPool.close(resp.key);
                }

                auto response = ResponseHandler.Response!uint(message_doc[Keywords.id].get!uint,
                    resp.data);
                requestPool.setResponse(response);

            },
                (immutable(RecordFactory.Recorder) recorder) { //TODO: change to HiRPC
                log("DS: received recorder");
                if (subscribe_handler_tid != Tid.init)
                {
                    send(subscribe_handler_tid, recorder);
                }
                // auto params=new HiBON;
                // params[DARTFile.Params.recorder]=recorder.toHiBON;
                auto request = empty_hirpc.dartModify(recorder, recorder_hrpc_id); //TODO: remove out of range archives
                auto request_data = request.toDoc.serialize;
                auto dstid = locate(opts.dart.sync.task_name);
                if (dstid != Tid.init)
                {
                    send(dstid, task_name, request_data); //TODO: => handle for the bullseye from dart
                }
                else
                {
                    log("Cannot locate DART synchronize service");
                }
            },
                (Buffer data, bool flag) {
                auto doc = Document(data);
                auto message_doc = doc[Keywords.message].get!Document;
                const hirpc_id = message_doc[Keywords.id].get!uint;
                if (hirpc_id != recorder_hrpc_id)
                {
                    auto response = ResponseHandler.Response!uint(hirpc_id, data);
                    requestPool.setResponse(response);
                }
                else
                {
                    auto result_doc = message_doc[Keywords.result].get!Document;
                    auto bullseye = result_doc[DARTFile.Params.bullseye].get!Buffer;
                    log(bullseye.cutHex);
                }
            },
                &dartHiRPC, /+
                    (string taskName, Buffer data) {
                log("DS: Received request from service: %s", taskName);
                const doc = Document(data);
                immutable sender = empty_hirpc.sender(doc);
                auto receiver = empty_hirpc.receive(doc);
                const message_doc = doc[Keywords.message].get!Document;
                const hrpc_id = message_doc[Keywords.id].get!uint;

                const method = message_doc[Keywords.method].get!string;

                void readDART() {
                    scope doc_fingerprints = receiver.method.params[DARTFile.Params.fingerprints].get!(
                        Document);
                    scope fingerprints = doc_fingerprints.range!(Buffer[]);
                    alias bufArr = Buffer[];
                    bufArr[NodeAddress] remote_fp_requests;
                    Buffer[] local_fp;
                    fpIterator: foreach (fp; fingerprints) {
                        const rims = DART.Rims(fp);
                        if (sector_range.inRange(rims)) {
                            local_fp ~= fp;
                            continue fpIterator;
                        }
                        else {
                            foreach (address, fps; remote_fp_requests) {
                                if (address.sector.inRange(rims)) {
                                    fps ~= fp;
                                    remote_fp_requests[address] = fps;
                                    continue fpIterator;
                                }
                            }
                            foreach (id, address; node_addrses) {
                                if (address.sector.inRange(rims)) {
                                    remote_fp_requests[address] = [fp];
                                    continue fpIterator;
                                }
                            }
                        }
                        throw new TagionException("No address for fp");
                    }
                    // auto recorder=dart.loads(local_fp, DARTFile.Recorder.Archive.Type.ADD);
                    auto rs = cast(ResponseHandler)(new ReadRequestHandler(array(fingerprints),
                        hirpc, taskName, receiver));
                    // if(local_fp.length>0){
                    //     requestPool.setResponse(ResponseHandler.Response!uint(hrpc_id, empty_hirpc.result(receiver, recorder.toHiBON).toHiBON(net).serialize));
                    // }
                    requestPool.add(hrpc_id, rs);
                    Buffer requestData(HiRPC hirpc, bufArr fps) {
                        auto params = new HiBON;
                        auto params_fingerprints = new HiBON;
                        foreach (i, b; fps) {
                            if (b.length !is 0) {
                                params_fingerprints[i] = b;
                            }
                        }
                        params[DARTFile.Params.fingerprints] = params_fingerprints;
                        const request = hirpc.dartRead(params, hrpc_id);
                        return request.toDoc.serialize;
                    }

                    if (remote_fp_requests.length > 0) {
                        import std.array;

                        foreach (addr, fps; remote_fp_requests) {
                            auto stream = node.connect(addr.address,
                                addr.is_marshal, [opts.dart.sync.protocol_id]);
                            // connectionPool.add(stream.Identifier, stream);
                            stream.listen(&StdHandlerCallback, task_name,
                                opts.dart.sync.host.timeout.msecs, opts.dart.sync.host.max_size);
                            immutable foreign_data = requestData(hirpc, fps);
                            stream.writeBytes(foreign_data);
                        }
                    }
                    if (local_fp.length > 0) {
                        immutable foreign_data = requestData(empty_hirpc, local_fp);
                        dart_sync_tid.send(opts.dart.task_name, foreign_data);
                    }
                }

                void modifyDART() { //TODO: not implemented yet
                    //HiRPC.check_element!Document(receiver.params, DARTFile.Params.recorder);
                    auto mrh = cast(ResponseHandler)(new ModifyRequestHandler(hirpc,
                        taskName, receiver));
                    requestPool.add(hrpc_id, mrh);
                    dart_sync_tid.send(sender);
                }

                if (method == DART.Quries.dartRead) {
                    readDART();
                }
                else if (method == DART.Quries.dartModify) {
                    modifyDART();
                }
            },
+/
                //                    (NodeAddress[string] update) { node_addrses = update; },
                (immutable(TaskFailure) t) { stop = true; ownerTid.send(t); },
            );
            requestPool.tick();
        }
    }
    catch (Throwable e)
    {
        fatal(e);
    }
}

private void subscibeHandler(immutable(Options) opts)
{
    log.register(opts.dart.subs.master_task_name);
    auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))(
        opts.dart.subs.host.timeout.msecs);
    bool stop = false;

    void handleControl(Control ts)
    {
        with (Control) switch (ts)
        {
        case STOP:
            log("Kill dart service");
            stop = true;
            break;
        default:
            log.error("Bad Control command %s", ts);
        }
    }

    do
    {
        pragma(msg, "fixme(alex): 1000.msecs shoud be an option");
        receiveTimeout(1000.msecs, &handleControl,
            (Response!(ControlCode.Control_Connected) resp) {
            log("DS-subs: Client Connected key: %d", resp.key);
            connectionPool.add(resp.key, resp.stream, true);
        },
            (Response!(ControlCode.Control_Disconnected) resp) {
            log("DS-subs: Client Disconnected key: %d", resp.key);
            connectionPool.close(resp.key);
        },
            (immutable(RecordFactory.Recorder) recorder) { //TODO: change to HiRPC
            log("DS-subs: received recorder");
            connectionPool.broadcast(recorder.toDoc.serialize); //+save to journal etc..
            // if not ready/started => send error
            // if(dartSyncTid != Tid.init){
            //     send(dartSyncTid, recorder);
            // }
        },);
        connectionPool.tick();
    }
    while (!stop);
}
