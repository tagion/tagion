module tagion.services.DARTSynchronizeService;

import core.thread;
import std.concurrency;
import std.stdio;
import std.conv;

import p2plib = p2p.interfaces;
import p2p.callback;
import p2p.cgo.c_helper;

import tagion.services.Options;
import tagion.logger.Logger;
import tagion.basic.Types : Buffer, Control, Pubkey;
import tagion.utils.Miscellaneous : toHexString, cutHex;
import tagion.dart.Recorder : RecordFactory, Archive;
import tagion.dart.DARTFile;
import tagion.dart.DART;
import tagion.dart.BlockFile : BlockFile;
import tagion.basic.Basic;
import tagion.Keywords;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;

import tagion.dart.DARTSynchronization;
import tagion.tasks.ResponseRequest;

version (unittest) import tagion.dart.BlockFile : fileId;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document;
import tagion.hibon.HiBON : HiBON;
import tagion.communication.HiRPC;
import tagion.script.StandardRecords;
import tagion.communication.HandlerPool;

//import tagion.services.MdnsDiscoveryService;
import tagion.gossip.P2pGossipNet : ConnectionPool; //, ActiveNodeAddressBook;
import tagion.gossip.AddressBook : NodeAddress, addressbook;

import tagion.basic.TagionExceptions;

alias HiRPCSender = HiRPC.HiRPCSender;
alias HiRPCReceiver = HiRPC.HiRPCReceiver;

enum DARTSynchronizeState
{
    WAITING = 1,
    SYNCHRONIZING = 2,
    REPLAYING_JOURNALS = 3,
    REPLAYING_RECORDERS = 4,
    READY = 10,
}

struct ServiceState(T)
{
    mixin StateT!T;
    this(T initial)
    {
        _state = initial;
    }

    void setState(T state)
    {
        if (state != _state)
        {
            _state = state;
            notifyOwner(); //TODO: manualy notify?
        }
    }

    @property T state()
    {
        return _state;
    }

    void notifyOwner()
    {
        send(ownerTid, _state);
    }
}

alias DARTReadRequest = ResponseRequest!(tagion.services.DARTSynchronizeService.stringof);

void dartSynchronizeServiceTask(Net : SecureNet)(
    immutable(Options) opts,
    shared(p2plib.NodeI) node,
    shared(Net) master_net,
    immutable(DART.SectorRange) sector_range) nothrow
{
    try
    {
        scope (success)
        {
            ownerTid.prioritySend(Control.END);
        }
        const task_name = opts.dart.sync.task_name;
        log.register(task_name);

        auto state = ServiceState!DARTSynchronizeState(DARTSynchronizeState.WAITING);
        auto pid = opts.dart.sync.protocol_id;
        log("-----Start DART Sync service-----");
        version (unittest)
        {
            immutable filename = opts.dart.path.length == 0
                ? fileId!(DART)(opts.dart.name).fullpath : opts.dart.path;
        }
        else
        {
            immutable filename = opts.dart.path;
        }
        if (opts.dart.initialize)
        {
            enum BLOCK_SIZE = 0x80;
            DART.create(filename, BLOCK_SIZE);
        }
        log("DART file created with filename: %s", filename);

        auto net = new Net();
        net.derive(task_name, master_net);
        DART dart = new DART(net, filename, sector_range.from_sector, sector_range.to_sector);
        log("DART initialized with angle: %s", sector_range);

        dart.dump;
        log("DART bullseye: %s", dart.fingerprint.cutHex);

        scope (exit)
        {
            node.closeListener(pid);
        }
        bool stop;
        void handleControl(Control ts)
        {
            with (Control) switch (ts)
            {
            case STOP:
                log("Kill dart synchronize service");
                stop = true;
                break;
            default:
                log.error("Bad Control command %s", ts);
            }
        }

        void recorderReplayFunc(const(RecordFactory.Recorder) recorder) @safe
        {
            dart.modify(recorder);
        }

        auto journalReplayFiber = new ReplayPool!string((string journal) => dart.replay(journal));
        auto recorderReplayFiber = new ReplayPool!(immutable(RecordFactory.Recorder))(
            &recorderReplayFunc);

        auto connectionPool = new shared(ConnectionPoolT)(
            opts.dart.sync.host.timeout.msecs);
        auto sync_factory = new P2pSynchronizationFactory(
            dart, opts.port, node,
            connectionPool, opts.dart, net.pubkey);
        auto syncPool = new DARTSynchronizationPool!(StdHandlerPool!(ResponseHandler, uint))(dart.sectors,
            journalReplayFiber, opts.dart);
        bool request_handling = false;
        // auto discoveryTid = spawn(&mdnsDiscoveryService, node, opts);
        // receiveOnly!Control;
        scope (exit)
        {
            log("exit scope: call stop");
            // discoveryTid.prioritySend(Control.STOP);
            // receiveOnly!Control;
            syncPool.stop;
        }
        log("SYNC: %s", opts.dart.synchronize);
        if (opts.dart.synchronize)
        {
            state.setState(DARTSynchronizeState.WAITING);
        }
        else
        {
            state.setState(DARTSynchronizeState.READY);
        }

        const hrpc = HiRPC(net);
        const empty_hirpc = HiRPC(null);

        auto subscription = ActiveNodeSubscribtion!Net(opts);
        //
        // Handles HiPRC for the DART
        //
        void dartHiPRC(string taskName, immutable(HiRPC.Sender) sender)
        {
            //            log("DSS: Received request from service: %s %d", taskName, data.length);
            Document loadAll(HiRPC hirpc)
            {
                return Document(dart.loadAll().serialize);
            }

            void sendResult(Buffer result)
            {
                auto tid = locate(taskName);
                if (tid !is Tid.init)
                {
                    log("sending response back, %s", taskName);
                    send(tid, result);
                }
                else
                {
                    log("couldn't locate task: %s", taskName);
                }
            }

            //            const doc = Document(data);
            const receiver = empty_hirpc.receive(sender);
            if (receiver.supports!DART)
            {
                log("receiver: %s", receiver.toDoc.toJSON);
                const request = dart(receiver, false);
                const tosend = request.toDoc.serialize;
                sendResult(tosend);
            }
            else
            {
                // auto epoch = receiver.params["epoch"].get!int;
                //                log("received: %s", doc.toJSON);
                auto owners_doc = receiver.method.params["owners"].get!Document;
                Buffer[] owners;
                foreach (owner; owners_doc[])
                {
                    owners ~= owner.get!Buffer;
                }
                // log("epoch: %d, owner: %s", epoch, owner);
                auto result_doc = loadAll(hrpc);
                StandardBill[] bills;
                foreach (archive_doc; result_doc[])
                {
                    auto archive = new Archive(net, archive_doc.get!Document);
                    //auto data_doc = Document(archive.data);
                    log("%s", archive.filed.toJSON);
                    if (!StandardBill.isRecord(archive.filed))
                        continue;
                    log("is standardbill");
                    const bill = StandardBill(archive.filed);

                    // if (archive.filed.hasMember("$type")){
                    //     if (archive.filed["$type"].get!string == "BIL"){
                    //         auto bill = StandardBill(archive.filed);
                    import std.algorithm : canFind;

                    // log("bill.owner: %s, owner: %s", bill.owner, owner);
                    if (owners.canFind(bill.owner))
                    {
                        log("owners found");
                        bills ~= bill;
                    }
                    // }
                    // }
                }
                HiBON params = new HiBON;
                foreach (i, bill; bills)
                {
                    params[i] = bill.toHiBON;
                }
                auto response = empty_hirpc.result(receiver, params);
                sendResult(response.toDoc.serialize);
            }
        }

        void dartRead(immutable(DARTReadRequest)* resp, Buffer[][] fingerprints) @trusted
        {
            import std.algorithm : joiner;

            immutable result = cast(immutable)(dart.loads(fingerprints.joiner, Archive.Type.NONE));
            resp.reply(result);
        }

        log("send live");
        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            const tick_timeout = state.checkState(DARTSynchronizeState.REPLAYING_JOURNALS,
                DARTSynchronizeState.REPLAYING_RECORDERS)
                ? opts.dart.sync.reply_tick_timeout.msecs : opts.dart.sync.tick_timeout.msecs;
            receiveTimeout(tick_timeout, &handleControl,
                (immutable(RecordFactory.Recorder) recorder) {
                log("DSS: recorder received");
                recorderReplayFiber.insert(recorder);
            }, (Response!(ControlCode.Control_Connected) resp) {
                log("DSS: Client Connected key: %d", resp.key);
                connectionPool.add(resp.key, resp.stream, true);
            }, (Response!(ControlCode.Control_Disconnected) resp) {
                log("DSS: Client Disconnected key: %d", resp.key);
                connectionPool.close(cast(void*) resp.key);
            }, (Response!(ControlCode.Control_RequestHandled) resp) {
                // log("DSS: Received request from p2p: %s", resp.key);
                scope (exit)
                {
                    if (resp.stream !is null)
                    {
                        destroy(resp.stream);
                    }
                }
                const doc = Document(resp.data);
                //auto message_doc = doc[Keywords.message].get!Document;
                const received = hrpc.receive(doc);

                void closeConnection()
                {
                    log("DSS: Forced close connection");
                    connectionPool.close(resp.key);
                }

                void serverHandler()
                {
                    if (received.method.name == DART.Quries.dartModify)
                    { //Not allowed
                        closeConnection();
                    }
                    auto request = dart(received);
                    connectionPool.send(resp.key, request.toDoc.serialize);
                }

                if (received.isMethod && state.checkState(DARTSynchronizeState.READY))
                { //TODO: to switch
                    serverHandler();
                }
                else if (!received.isMethod && state.checkState(DARTSynchronizeState.SYNCHRONIZING))
                {
                    syncPool.setResponse(resp);
                }
                else
                {
                    closeConnection();
                }

            },
                &dartHiPRC,
                &dartRead, // version(none) {
                (string taskName, Buffer data) {
                log("DSS: Received request from service: %s %d", taskName, data.length);
                Document loadAll(HiRPC hirpc)
                {
                    return Document(dart.loadAll().serialize);
                }

                void sendResult(Buffer result)
                {
                    auto tid = locate(taskName);
                    if (tid != Tid.init)
                    {
                        log("sending response back, %s", taskName);
                        send(tid, result);
                    }
                    else
                    {
                        log("couldn't locate task: %s", taskName);
                    }
                }

                const doc = Document(data);
                const receiver = empty_hirpc.receive(doc);
                if (receiver.supports!DART)
                {
                    log("receiver: %s", receiver.toDoc.toJSON);
                    const request = dart(receiver, false);
                    const tosend = request.toDoc.serialize;
                    sendResult(tosend);
                }
                else
                {
                    // auto epoch = receiver.params["epoch"].get!int;
                    log("received: %s", doc.toJSON);
                    auto owners_doc = receiver.method.params["owners"].get!Document;
                    Buffer[] owners;
                    foreach (owner; owners_doc[])
                    {
                        owners ~= owner.get!Buffer;
                    }
                    // log("epoch: %d, owner: %s", epoch, owner);
                    auto result_doc = loadAll(hrpc);
                    StandardBill[] bills;
                    foreach (archive_doc; result_doc[])
                    {
                        auto archive = new Archive(net, archive_doc.get!Document);
                        //auto data_doc = Document(archive.data);
                        log("%s", archive.filed.toJSON);
                        if (!StandardBill.isRecord(archive.filed))
                            continue;
                        log("is standardbill");
                        const bill = StandardBill(archive.filed);

                        // if (archive.filed.hasMember("$type")){
                        //     if (archive.filed["$type"].get!string == "BIL"){
                        //         auto bill = StandardBill(archive.filed);
                        import std.algorithm : canFind;

                        // log("bill.owner: %s, owner: %s", bill.owner, owner);
                        if (owners.canFind(bill.owner))
                        {
                            log("owners found");
                            bills ~= bill;
                        }
                        // }
                        // }
                    }
                    HiBON params = new HiBON;
                    foreach (i, bill; bills)
                    {
                        params[i] = bill.toHiBON;
                    }
                    auto response = empty_hirpc.result(receiver, params);
                    sendResult(response.toDoc.serialize);
                }
            }, //     (ActiveNodeAddressBook update) {
                //         //node_addrses = cast(NodeAddress[Pubkey]) update.data;
                //     log.warning("Should be removed ActiveNodeAddressBook update (the AddressBook is shoud be used instead)");
                // },
                (immutable(TaskFailure) t) { stop = true; ownerTid.send(t); }, // (immutable(Throwable) t) {
                //     //log.fatal(t.msg);
                //     stop=true;
                //     ownerTid.send(t);
                // }

                

            );
            // try {
            connectionPool.tick();
            if (opts.dart.synchronize)
            {
                syncPool.tick();
                if (!addressbook.isReady)
                {
                    log("addressbook.length=%d syncPool.isReady =%s state=%s sync_state=%s",
                        addressbook.numOfActiveNodes, syncPool.isReady, syncPool.state, syncPool
                            .sync_state);
                }
                if (addressbook.numOfNodes > 0 && syncPool.isReady)
                {
                    pragma(msg, "fixme(cbr): sync_factory.setNodeTable(addressbook._data) has been removed");
                    log.trace("syncPool.start active %d isReady %s", addressbook.numOfActiveNodes, addressbook
                            .isReady);

                    //                        sync_factory.setNodeTable(addressbook._data);
                    syncPool.start(sync_factory);
                    state.setState(DARTSynchronizeState.SYNCHRONIZING);
                }
                if (syncPool.isOver)
                {
                    log.trace("syncPool.stop active %d isReady %s", addressbook.numOfActiveNodes, addressbook
                            .isReady);
                    syncPool.stop;
                    // log("Start replay journals with: %d journals", journalReplayFiber.count);
                    state.setState(DARTSynchronizeState.REPLAYING_JOURNALS);
                }
                if (syncPool.isError)
                {
                    pragma(msg, "fixme(cbr): isError sync_factory.setNodeTable(addressbook._data) has been removed");
                    log("syncPool Error handling active %d isReady %s", addressbook.numOfActiveNodes, addressbook
                            .isReady);
                    //                        sync_factory.setNodeTable(addressbook._data);
                    syncPool.start(sync_factory);
                    state.setState(DARTSynchronizeState.SYNCHRONIZING); //TODO: remove if notification not needed
                }
            }
            if (state.checkState(DARTSynchronizeState.REPLAYING_JOURNALS))
            {
                if (!journalReplayFiber.isOver)
                {
                    journalReplayFiber.execute;
                }
                else
                {
                    journalReplayFiber.clear();
                    // log("Start replay recorders with: %d recorders", recorders.length);
                    connectionPool.closeAll();
                    state.setState(DARTSynchronizeState.REPLAYING_RECORDERS);
                }
            }
            if (state.checkState(DARTSynchronizeState.REPLAYING_RECORDERS))
            {
                if (!recorderReplayFiber.isOver)
                {
                    recorderReplayFiber.execute;
                }
                else
                {
                    subscription.stop();
                    recorderReplayFiber.clear();
                    dart.dump(true);
                    log("DART generated: bullseye: %s", dart.fingerprint.toHexString);
                    state.setState(DARTSynchronizeState.READY);
                }
            }
            if (state.checkState(DARTSynchronizeState.READY) && !request_handling)
            {
                node.listen(pid, &StdHandlerCallback, cast(string) task_name,
                    opts.dart.sync.host.timeout.msecs,
                    cast(uint) opts.dart.sync.host.max_size);
                request_handling = true;
            }
            // catch (Throwable t) {
            //     stop = true;
            //     fatal(t);
            // }
        }
    }
    catch (Throwable t)
    {
        fatal(t);
    }
}

private struct ActiveNodeSubscribtion(Net : HashNet)
{
    protected Tid handlerTid;
    protected shared(p2plib.RequestStreamI) stream;
    protected bool subscribed;
    @disable this();
    // protected Net net;
    @property bool isSubscribed()
    {
        return subscribed;
    }

    protected immutable(Options) opts;
    this(immutable(Options) opts)
    {
        this.opts = opts;
    }

    version (none) void tryToSubscribe(NodeAddress[Pubkey] node_addreses, shared(p2plib.NodeI) node)
    {
        bool subscribeTo(NodeAddress address)
        {
            try
            {
                stream = node.connect(address.address, address.is_marshal,
                    opts.dart.subs.protocol_id);
                auto taskName = opts.dart.subs.slave_task_name;
                handlerTid = spawn(&handleSubscription, taskName);
                receiveOnly!Control;
                stream.listen(&StdHandlerCallback, taskName,
                    opts.dart.subs.host.timeout.msecs, opts.dart.subs.host.max_size);
                return true;
            }
            catch (Exception e)
            {
                log("subscribe error: %s", e);
            }
            return false;
        }
        // writeln("looking for master node");

        foreach (node_id, node_address; node_addreses)
        { //TODO: should be random
            // writefln("master port: %d \tport: %d", opts.dart.subs.master_port, node_address.port);
            if (!opts.dart.master_from_port || node_address.port == opts.dart.subs.master_port)
            {
                log("master node found");
                if (subscribeTo(node_address))
                {
                    subscribed = true;
                    return;
                }
            }
            log("Master not found");
        }
    }

    void stop()
    {
        log("Stop subscription");
        if (subscribed && handlerTid !is Tid.init)
        {
            send(handlerTid, Control.STOP);
            // receiveOnly!Control;
        }
    }

    protected static void handleSubscription(string taskName)
    { //TODO: moveout
        scope (exit)
        {
            log("exit handleSubscription");
            // ownerTid.prioritySend(Control.END);
        }
        auto net = new Net;
        log.register(taskName);
        auto stop = false;
        ownerTid.send(Control.LIVE);

        auto manufactor = RecordFactory(net);
        while (!stop)
        {
            receive((Control cntrl) {
                if (cntrl == Control.STOP)
                {
                    stop = true;
                }
            },
                (Response!(ControlCode.Control_Disconnected) resp) {
                writeln("Subscribe Disconnected key: ", resp.key);
            }, (
                    Response!(ControlCode.Control_RequestHandled) response) {
                writeln("Subscribe recorder received");
                auto doc = Document(response.data);
                immutable recorder = cast(immutable) manufactor.recorder(doc);
                send(ownerTid, recorder);
            });
        }
    }
}

/+
Error: constructor
tagion.dart.DARTSynchronization.P2pSynchronizationFactory.this(
    DART dart,
    shared(Node) node,
    shared(ConnectionPool!(shared(Stream), ulong)) connection_pool,
    immutable(Options) opts,
    immutable(Typedef!(immutable(ubyte)[], null, "PUBKEY")) pkey)


    DART,
    shared(Node),
    shared(ConnectionPool!(shared(Stream), ulong)),
    immutable(Options),
    Typedef!(immutable(ubyte)[], null, "PUBKEY"))
+/

/+
     cannot pass argument `connectionPool` of type
shared(tagion.gossip.P2pGossipNet.ConnectionPool!(shared(Stream), ulong))
     to parameter
shared(p2p.connection.ConnectionPool!(shared(Stream), ulong)) connection_pool
+/
