/// Handles the synchronization with other DART's
module tagion.prior_services.DARTSynchronizeService;

import core.thread;
import std.concurrency;
import std.stdio;
import std.conv;

import p2plib = p2p.interfaces;
import p2p.callback;
import p2p.cgo.c_helper;

import tagion.prior_services.Options;
import tagion.logger.Logger;
import tagion.basic.Types : Buffer, Control;
import tagion.crypto.Types : Pubkey;
import tagion.utils.Miscellaneous : toHexString, cutHex;
import tagion.dart.Recorder : RecordFactory, Archive;
import tagion.dart.DARTFile;
import tagion.dart.DART;
import tagion.dart.BlockFile : BlockFile, BLOCK_SIZE;
import tagion.basic.basic;
import tagion.Keywords;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;

import tagion.prior_services.DARTSynchronization;
import tagion.prior_services.ResponseRequest;
import tagion.dart.DARTBasic : DARTIndex;

version (unittest) import tagion.dart.BlockFile : fileId;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document;
import tagion.hibon.HiBON : HiBON;
import tagion.communication.HiRPC;
import tagion.script.prior.StandardRecords;
import tagion.communication.HandlerPool;

//import tagion.prior_services.MdnsDiscoveryService;
import tagion.gossip.P2pGossipNet : ConnectionPool; //, ActiveNodeAddressBook;
import tagion.gossip.AddressBook : NodeAddress, addressbook;

import tagion.basic.tagionexceptions;
import tagion.actor.exceptions;
import tagion.dart.DARTRim;
import std.typecons;

alias HiRPCSender = HiRPC.HiRPCSender;
alias HiRPCReceiver = HiRPC.HiRPCReceiver;

enum DARTSynchronizeState {
    WAITING = 1,
    SYNCHRONIZING = 2,
    REPLAYING_JOURNALS = 3,
    REPLAYING_RECORDERS = 4,
    READY = 10,
}

struct ServiceState(T) {
    mixin StateT!T;
    this(T initial) {
        _state = initial;
    }

    void setState(T state) {
        if (state != _state) {
            _state = state;
            notifyOwner(); //TODO: manualy notify?
        }
    }

    @property T state() {
        return _state;
    }

    void notifyOwner() {
        send(ownerTid, _state);
    }
}

alias DARTReadRequest = ResponseRequest!(tagion.prior_services.DARTSynchronizeService.stringof);

void dartSynchronizeServiceTask(Net : SecureNet)(
        immutable(Options) opts,
        shared(p2plib.NodeI) node,
        shared(Net) master_net,
        immutable(SectorRange) sector_range) nothrow {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }
        const task_name = opts.dart.sync.task_name;
        log.register(task_name);

        auto state = ServiceState!DARTSynchronizeState(DARTSynchronizeState.WAITING);
        auto pid = opts.dart.sync.protocol_id;
        version (unittest) {
            immutable filename = opts.dart.path.length == 0
                ? fileId!(DART)(opts.dart.name).fullpath : opts.dart.path;
        }
        else {
            immutable filename = opts.dart.path;
        }
        auto net = new Net();
        if (opts.dart.initialize) {
            DART.create(filename, net, BLOCK_SIZE);
        }
        log("DART file created with filename: %s", filename);

        net.derive(task_name, master_net);
        DART dart = new DART(net, filename, sector_range.from_sector, sector_range.to_sector);
        log("DART initialized with angle: %s", sector_range);

        dart.dump;
        log("DART bullseye: %s", dart.fingerprint.cutHex);

        scope (exit) {
            node.closeListener(pid);
        }
        bool stop;
        void handleControl(Control ts) {
            with (Control) switch (ts) {
            case STOP:
                log("Kill dart synchronize service");
                stop = true;
                break;
            default:
                log.error("Bad Control command %s", ts);
            }
        }

        void recorderReplayFunc(const(RecordFactory.Recorder) recorder) @safe {
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
        scope (exit) {
            log("exit scope: call stop");
            // discoveryTid.prioritySend(Control.STOP);
            // receiveOnly!Control;
            syncPool.stop;
        }
        if (opts.dart.synchronize) {
            state.setState(DARTSynchronizeState.WAITING);
        }
        else {
            state.setState(DARTSynchronizeState.READY);
        }

        const hrpc = HiRPC(net);
        const empty_hirpc = HiRPC(null);

        auto subscription = ActiveNodeSubscribtion!Net(opts);
        //
        // Handles HiPRC for the DART
        //
        void dartHiPRC(string taskName, immutable(HiRPC.Sender) sender) {
            Document loadAll(HiRPC hirpc) {
                return Document(dart.loadAll().serialize);
            }

            void sendResult(Buffer result) {
                auto tid = locate(taskName);
                if (tid !is Tid.init) {
                    send(tid, result);
                }
                else {
                    log.warning("Couldn't locate task: %s", taskName);
                }
            }

            const receiver = empty_hirpc.receive(sender);
            if (receiver.supports!DART) {
                const request = dart(receiver, false);
                const tosend = request.toDoc.serialize;
                sendResult(tosend);
            }
            else {
                auto owners_doc = receiver.method.params["owners"].get!Document;
                Buffer[] owners;
                foreach (owner; owners_doc[]) {
                    owners ~= owner.get!Buffer;
                }
                auto result_doc = loadAll(hrpc);
                StandardBill[] bills;
                foreach (archive_doc; result_doc[]) {
                    auto archive = new Archive(net, archive_doc.get!Document);
                    if (!StandardBill.isRecord(archive.filed))
                        continue;
                    const bill = StandardBill(archive.filed);

                    import std.algorithm : canFind;

                    if (owners.canFind(bill.owner)) {
                        bills ~= bill;
                    }
                }
                HiBON params = new HiBON;
                foreach (i, bill; bills) {
                    params[i] = bill.toHiBON;
                }
                auto response = empty_hirpc.result(receiver, params);
                sendResult(response.toDoc.serialize);
            }
        }

        void dartRead(immutable(DARTReadRequest)* resp, DARTIndex[][] fingerprints) @trusted {
            import std.algorithm : joiner;

            immutable result = cast(immutable)(dart.loads(fingerprints.joiner, Archive.Type.NONE));
            resp.reply(result);
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            const tick_timeout = state.checkState(DARTSynchronizeState.REPLAYING_JOURNALS,
                    DARTSynchronizeState.REPLAYING_RECORDERS)
                ? opts.dart.sync.reply_tick_timeout.msecs : opts.dart.sync.tick_timeout.msecs;
            receiveTimeout(tick_timeout, &handleControl,
                    (immutable(RecordFactory.Recorder) recorder) { recorderReplayFiber.insert(recorder); }, (
                    Response!(ControlCode.Control_Connected) resp) { connectionPool.add(resp.key, resp.stream, true); }, (
                    Response!(ControlCode.Control_Disconnected) resp) { connectionPool.close(cast(void*) resp.key); }, (
                    Response!(ControlCode.Control_RequestHandled) resp) {
                scope (exit) {
                    if (resp.stream !is null) {
                        destroy(resp.stream);
                    }
                }
                const doc = Document(resp.data);
                const received = hrpc.receive(doc);

                void closeConnection() {
                    connectionPool.close(resp.key);
                }

                void serverHandler() {
                    if (received.method.name == DART.Queries.dartModify) { //Not allowed
                        closeConnection();
                    }
                    auto request = dart(received);
                    connectionPool.send(resp.key, request.toDoc.serialize);
                }

                if (received.isMethod && state.checkState(DARTSynchronizeState.READY)) { //TODO: to switch
                    serverHandler();
                }
                else if (!received.isMethod && state.checkState(DARTSynchronizeState.SYNCHRONIZING)) {
                    syncPool.setResponse(resp);
                }
                else {
                    closeConnection();
                }

            },
                    &dartHiPRC,
                    &dartRead, // version(none) {
                    (string taskName, Buffer data) {
                log.trace("DSS: Received request from service: %s %d", taskName, data.length);
                Document loadAll(HiRPC hirpc) {
                    return Document(dart.loadAll().serialize);
                }

                void sendResult(Buffer result) {
                    auto tid = locate(taskName);
                    if (tid != Tid.init) {
                        log.trace("Sending response back to %s", taskName);
                        send(tid, result);
                    }
                    else {
                        log.warning("Couldn't locate task: %s", taskName);
                    }
                }

                const doc = Document(data);
                const receiver = empty_hirpc.receive(doc);
                if (receiver.supports!DART) {
                    const request = dart(receiver, false);
                    const tosend = request.toDoc.serialize;
                    sendResult(tosend);
                }
                else {
                    auto owners_doc = receiver.method.params["owners"].get!Document;
                    Buffer[] owners;
                    foreach (owner; owners_doc[]) {
                        owners ~= owner.get!Buffer;
                    }
                    auto result_doc = loadAll(hrpc);
                    StandardBill[] bills;
                    foreach (archive_doc; result_doc[]) {
                        auto archive = new Archive(net, archive_doc.get!Document);
                        if (!StandardBill.isRecord(archive.filed))
                            continue;
                        const bill = StandardBill(archive.filed);

                        import std.algorithm : canFind;

                        if (owners.canFind(bill.owner)) {
                            bills ~= bill;
                        }
                    }
                    HiBON params = new HiBON;
                    foreach (i, bill; bills) {
                        params[i] = bill.toHiBON;
                    }
                    auto response = empty_hirpc.result(receiver, params);
                    sendResult(response.toDoc.serialize);
                }
            },
                    (immutable(TaskFailure) t) { stop = true; ownerTid.send(t); },
            );
            // try {
            connectionPool.tick();
            if (opts.dart.synchronize) {
                syncPool.tick();
                if (addressbook.numOfNodes > 0 && syncPool.isReady) {
                    pragma(msg, "fixme(cbr): sync_factory.setNodeTable(addressbook._data) has been removed");
                    log.trace("syncPool.start active %d isReady %s", addressbook.numOfActiveNodes, addressbook
                            .isReady);

                    syncPool.start(sync_factory);
                    state.setState(DARTSynchronizeState.SYNCHRONIZING);
                }
                if (syncPool.isOver) {
                    log.trace("syncPool.stop active %d isReady %s", addressbook.numOfActiveNodes, addressbook
                            .isReady);
                    syncPool.stop;
                    state.setState(DARTSynchronizeState.REPLAYING_JOURNALS);
                }
                if (syncPool.isError) {
                    pragma(msg, "fixme(cbr): isError sync_factory.setNodeTable(addressbook._data) has been removed");
                    log("syncPool Error handling active %d isReady %s", addressbook.numOfActiveNodes, addressbook
                            .isReady);
                    syncPool.start(sync_factory);
                    state.setState(DARTSynchronizeState.SYNCHRONIZING); //TODO: remove if notification not needed
                }
            }
            if (state.checkState(DARTSynchronizeState.REPLAYING_JOURNALS)) {
                if (!journalReplayFiber.isOver) {
                    journalReplayFiber.execute;
                }
                else {
                    journalReplayFiber.clear();
                    connectionPool.closeAll();
                    state.setState(DARTSynchronizeState.REPLAYING_RECORDERS);
                }
            }
            if (state.checkState(DARTSynchronizeState.REPLAYING_RECORDERS)) {
                if (!recorderReplayFiber.isOver) {
                    recorderReplayFiber.execute;
                }
                else {
                    subscription.stop();
                    recorderReplayFiber.clear();
                    dart.dump(SectorRange.init, Yes.full);
                    log("DART generated: bullseye: %s", dart.fingerprint.toHexString);
                    state.setState(DARTSynchronizeState.READY);
                }
            }
            if (state.checkState(DARTSynchronizeState.READY) && !request_handling) {
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
    catch (Throwable t) {
        fatal(t);
    }
}

private struct ActiveNodeSubscribtion(Net : HashNet) {
    protected Tid handlerTid;
    protected shared(p2plib.RequestStreamI) stream;
    protected bool subscribed;
    @disable this();
    // protected Net net;
    @property bool isSubscribed() {
        return subscribed;
    }

    protected immutable(Options) opts;
    this(immutable(Options) opts) {
        this.opts = opts;
    }

    version (none) void tryToSubscribe(NodeAddress[Pubkey] node_addreses, shared(p2plib.NodeI) node) {
        bool subscribeTo(NodeAddress address) {
            try {
                stream = node.connect(address.address, address.is_marshal,
                        opts.dart.subs.protocol_id);
                auto taskName = opts.dart.subs.slave_task_name;
                handlerTid = spawn(&handleSubscription, taskName);
                receiveOnly!Control;
                stream.listen(&StdHandlerCallback, taskName,
                        opts.dart.subs.host.timeout.msecs, opts.dart.subs.host.max_size);
                return true;
            }
            catch (Exception e) {
                log.warning("Subscribe error: %s", e);
            }
            return false;
        }
        // writeln("looking for master node");

        foreach (node_id, node_address; node_addreses) { //TODO: should be random
            if (!opts.dart.master_from_port || node_address.port == opts.dart.subs.master_port) {
                log.trace("Master node found");
                if (subscribeTo(node_address)) {
                    subscribed = true;
                    return;
                }
            }
            log.trace("Master not found");
        }
    }

    void stop() {
        log.trace("Stop subscription");
        if (subscribed && handlerTid !is Tid.init) {
            send(handlerTid, Control.STOP);
            // receiveOnly!Control;
        }
    }

    protected static void handleSubscription(string taskName) { //TODO: moveout
        auto net = new Net;
        log.register(taskName);
        auto stop = false;
        ownerTid.send(Control.LIVE);

        auto manufactor = RecordFactory(net);
        while (!stop) {
            receive((Control cntrl) {
                if (cntrl == Control.STOP) {
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
tagion.services.DARTSynchronization.P2pSynchronizationFactory.this(
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
