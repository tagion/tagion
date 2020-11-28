module tagion.services.DartSynchronizeService;

import core.thread;
import std.concurrency;

import tagion.Options;

import p2plib = p2p.node;
import p2p.connection;
import p2p.callback;
import p2p.cgo.helper;
import tagion.basic.Logger;
import tagion.basic.Basic : Buffer, Control;
import std.getopt;
import std.stdio;
import std.conv;
import tagion.utils.Miscellaneous : toHexString, cutHex;
import tagion.dart.DARTFile;
import tagion.dart.DART;
import tagion.dart.BlockFile : BlockFile;
import tagion.basic.Basic;
import tagion.Keywords;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.dart.DARTSynchronization;
version(unittest) import tagion.dart.BlockFile: fileId;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document;
import tagion.hibon.HiBON : HiBON;
import tagion.gossip.InterfaceNet: SecureNet, HashNet;
import tagion.communication.HiRPC;
import tagion.script.StandardRecords;
import tagion.communication.HandlerPool;
//import tagion.services.MdnsDiscoveryService;
import tagion.gossip.P2pGossipNet : AddressBook, NodeAddress;

import tagion.basic.TagionExceptions;

alias HiRPCSender = HiRPC.HiRPCSender;
alias HiRPCReceiver = HiRPC.HiRPCReceiver;

enum DartSynchronizeState{
    WAITING = 1,
    SYNCHRONIZING = 2,
    REPLAYING_JOURNALS = 3,
    REPLAYING_RECORDERS = 4,
    READY = 10,
}


struct ServiceState(T) {
    mixin StateT!T;
    this(T initial){
        _state = initial;
    }
    void setState(T state){
        if(state != _state){
            _state = state;
            notifyOwner(); //TODO: manualy notify?
        }
    }

    @property T state(){
        return _state;
    }

    void notifyOwner(){
        send(ownerTid, _state);
    }
}

void dartSynchronizeServiceTask(Net : SecureNet)(immutable(Options) opts, shared(p2plib.Node) node, shared(Net) master_net, immutable(DART.SectorRange) sector_range) {
    try{
        const task_name = opts.dart.sync.task_name;
        log.register(task_name);

        auto state = ServiceState!DartSynchronizeState(DartSynchronizeState.WAITING);
        auto pid = opts.dart.sync.protocol_id;
        log("-----Start Dart Sync service-----");
        scope(success){
            log("------Stop Dart Sync service-----");
            ownerTid.prioritySend(Control.END);
        }
        scope(failure){
            log("------Error Stop Dart Sync service-----");
            ownerTid.prioritySend(Control.END);
        }
        version(unittest) {
            immutable filename = opts.dart.path.length==0 ? fileId!(DART)(opts.dart.name).fullpath: opts.dart.path;
        }
        else {
            immutable filename = opts.dart.path;
        }
        if (opts.dart.initialize) {
            enum BLOCK_SIZE=0x80;
            BlockFile.create(filename, DARTFile.stringof, BLOCK_SIZE);
        }
        log("Dart file created with filename: %s", filename);

        auto net = new Net();
        net.drive(task_name, master_net);
        DART dart = new DART(net, filename, sector_range.from_sector, sector_range.to_sector);
        log("DART initialized with angle: %s", sector_range);

        if (opts.dart.generate) {
            import tagion.dart.DARTFakeNet;
            auto fp = SetInitialDataSet(dart, opts.dart.ringWidth, opts.dart.rings);
            log("DART generated: bullseye: %s", fp.cutHex);
            dart.dump;
        }
        else{
            if(!opts.dart.initialize){
                dart.calculateFingerprint();
            }
            dart.dump;
            log("DART bullseye: %s", dart.fingerprint.cutHex);
        }

        scope(exit){
            node.closeListener(pid);
        }
        bool stop;
        void handleControl (Control ts) {
            with(Control) switch(ts) {
                case STOP:
                    log("Kill dart synchronize service");
                    stop = true;
                    break;
                default:
                    log.error("Bad Control command %s", ts);
                }
        }
        void recorderReplayFunc(immutable(DARTFile.Recorder) recorder){
            dart.modify(cast(DARTFile.Recorder) recorder);
        }
        auto journalReplayFiber= new ReplayPool!string((string journal) => dart.replay(journal));
        auto recorderReplayFiber= new ReplayPool!(immutable(DARTFile.Recorder))(&recorderReplayFunc);

        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))(opts.dart.sync.host.timeout.msecs);
        auto sync_factory = new P2pSynchronizationFactory(dart, node, connectionPool, opts, net.pubkey);
        auto syncPool = new DartSynchronizationPool!(StdHandlerPool!(ResponseHandler, uint))(dart.sectors, journalReplayFiber, opts);
        bool request_handling = false;
        // auto discoveryTid = spawn(&mdnsDiscoveryService, node, opts);
        // receiveOnly!Control;
        scope(exit){
            log("exit scope: call stop");
            // discoveryTid.prioritySend(Control.STOP);
            // receiveOnly!Control;
            syncPool.stop;
        }
        log("SYNC: %s", opts.dart.synchronize);
        if(opts.dart.synchronize) {
            state.setState(DartSynchronizeState.WAITING);
        }else{
            state.setState(DartSynchronizeState.READY);
        }

        HiRPC hrpc;
        auto empty_hirpc = HiRPC(null);
        hrpc.net = net;

        auto subscription = ActiveNodeSubscribtion!Net(opts);
        NodeAddress[Pubkey] node_addrses;
        log("send live");
        ownerTid.send(Control.LIVE);
        while(!stop) {
            const tick_timeout = state.checkState(
                DartSynchronizeState.REPLAYING_JOURNALS,
                DartSynchronizeState.REPLAYING_RECORDERS)
                ? opts.dart.sync.replay_tick_timeout.msecs
                : opts.dart.sync.tick_timeout.msecs;
            receiveTimeout(tick_timeout,
                &handleControl,
                (immutable(DARTFile.Recorder) recorder){
                    log("DSS: recorder received");
                    recorderReplayFiber.insert(recorder);
                },
                (Response!(ControlCode.Control_Connected) resp) {
                    log("DSS: Client Connected key: %d", resp.key);
                    connectionPool.add(resp.key, resp.stream, true);
                },
                (Response!(ControlCode.Control_Disconnected) resp) {
                    log("DSS: Client Disconnected key: %d", resp.key);
                    connectionPool.close(cast(void*)resp.key);
                },
                (Response!(ControlCode.Control_RequestHandled) resp) {
                    // log("DSS: Received request from p2p: %s", resp.key);
                    scope(exit){
                        if(resp.stream !is null){
                            destroy(resp.stream);
                        }
                    }
                    auto doc = Document(resp.data);
                    auto message_doc = doc[Keywords.message].get!Document;
                    void closeConnection(){
                        log("DSS: Forced close connection");
                        connectionPool.close(resp.key);
                    }
                    void serverHandler(){
                        if(message_doc[Keywords.method].get!string == DART.Quries.dartModify){  //Not allowed
                            closeConnection();
                        }
                        // log("Req:%s", doc.toJSON);
                        auto received = hrpc.receive(doc);
                        auto request = dart(received);
                        auto tosend = hrpc.toHiBON(request).serialize;
                        import tagion.hibon.HiBONJSON;
                        // log("Res:%s", Document(tosend).toJSON);
                        connectionPool.send(resp.key, tosend);
                        // log("DSS: Sended response to connection: %s", resp.key);
                    }
                    if(message_doc.hasElement(Keywords.method) && state.checkState(DartSynchronizeState.READY)){ //TODO: to switch
                        serverHandler();
                    }else if(!message_doc.hasElement(Keywords.method)&& state.checkState(DartSynchronizeState.SYNCHRONIZING)){
                        syncPool.setResponse(resp);
                    }else{
                        closeConnection();
                    }
                },
                (string taskName, Buffer data){
                    log("DSS: Received request from service: %s %d", taskName, data.length);
                    Document loadAll(HiRPC hirpc){
                        return Document(dart.loadAll().serialize);
                    }
                    void sendResult(Buffer result){
                        auto tid = locate(taskName);
                        if(tid != Tid.init){
                            log("sending response back, %s", taskName);
                            send(tid, result);
                        }else{
                            log("couldn't locate task: %s", taskName);
                        }
                    }
                    const doc = Document(data);
                    auto receiver = empty_hirpc.receive(doc);
                    // auto message_doc = doc[Keywords.message].get!Document;
                    if(DART.supports(receiver)){
                        auto request = dart(receiver, false);
                        auto tosend = empty_hirpc.toHiBON(request).serialize;
                        sendResult(tosend);
                    }else{
                        // auto epoch = receiver.params["epoch"].get!int;
                        auto owners_doc = receiver.params["owners"].get!Document;
                        Buffer[] owners;
                        foreach(owner; owners_doc[]){
                            owners ~= owner.get!Buffer;
                        }
                        // log("epoch: %d, owner: %s", epoch, owner);
                        auto result_doc = loadAll(hrpc);
                        StandardBill[] bills;
                        foreach(archive_doc;result_doc[]){
                            auto archive = new DARTFile.Recorder.Archive(net, archive_doc.get!Document);
                            //auto data_doc = Document(archive.data);
                            log("%s", archive.doc.toJSON);
                            if(archive.doc.hasElement("$type")){
                                if(archive.doc["$type"].get!string == "BIL"){
                                    auto bill = StandardBill(archive.doc);
                                    import std.algorithm: canFind;
                                    // log("bill.owner: %s, owner: %s", bill.owner, owner);
                                    if( owners.canFind(bill.owner)){
                                        bills~=bill;
                                    }
                                }
                            }
                        }
                        HiBON params = new HiBON;
                        foreach(i, bill; bills){
                            params[i] = bill.toHiBON;
                        }
                        auto response = empty_hirpc.result(receiver, params);
                        sendResult(empty_hirpc.toHiBON(response).serialize);
                    }
                },
                (immutable(AddressBook!Pubkey) update){
                    node_addrses = cast(NodeAddress[Pubkey]) update.data;
                    // log("node addresses %s", node_addrses);
                },
                (immutable(Exception) e) {
                    log.fatal(e.msg);
                    stop=true;
                    ownerTid.send(e);
                },
                (immutable(Throwable) t) {
                    log.fatal(t.msg);
                    stop=true;
                    ownerTid.send(t);
                }
            );
            try{
                connectionPool.tick();
                if(opts.dart.synchronize){
                    syncPool.tick();
                    if(node_addrses.length > 0 && syncPool.isReady){
                        sync_factory.setNodeTable(node_addrses);
                        syncPool.start(sync_factory);
                        state.setState(DartSynchronizeState.SYNCHRONIZING);
                    }
                    if(syncPool.isOver){
                        syncPool.stop;
                        // log("Start replay journals with: %d journals", journalReplayFiber.count);
                        state.setState(DartSynchronizeState.REPLAYING_JOURNALS);
                    }
                    if(syncPool.isError){
                        log("Error handling");
                        sync_factory.setNodeTable(node_addrses);
                        syncPool.start(sync_factory);
                        state.setState(DartSynchronizeState.SYNCHRONIZING); //TODO: remove if notification not needed
                    }
                }
                if(state.checkState(DartSynchronizeState.REPLAYING_JOURNALS)){
                    if(!journalReplayFiber.isOver){
                        journalReplayFiber.execute;
                    }else{
                        journalReplayFiber.clear();
                        // log("Start replay recorders with: %d recorders", recorders.length);
                        connectionPool.closeAll();
                        state.setState(DartSynchronizeState.REPLAYING_RECORDERS);
                    }
                }
                if(state.checkState(DartSynchronizeState.REPLAYING_RECORDERS)){
                    if(!recorderReplayFiber.isOver){
                        recorderReplayFiber.execute;
                    }else{
                        subscription.stop();
                        recorderReplayFiber.clear();
                        dart.dump(true);
                        log("DART generated: bullseye: %s", dart.fingerprint.toHexString);
                        state.setState(DartSynchronizeState.READY);
                    }
                }
                if(state.checkState(DartSynchronizeState.READY) && !request_handling){
                    node.listen(pid, &StdHandlerCallback, cast(string) task_name, opts.dart.sync.host.timeout.msecs, cast(uint) opts.dart.sync.host.max_size);
                    request_handling = true;
                }
            }
            catch(TagionException e){
                log.fatal(e.msg);
                stop=true;
                ownerTid.send(e.taskException);
            }
            // catch(Exception e){
            //     log.fatal(e.msg);
            //     stop=true;
            //     ownerTid.send(cast(immutable)e);
            // }
            catch(Throwable t) {
                log.fatal(t.msg);
                stop=true;
                ownerTid.send(t.taskException);
            }
        }
    }
    catch(TagionException e){
        log.fatal(e.msg);
        ownerTid.send(e.taskException);
    }
    // catch(Exception e){
    //     log.fatal(e.msg);
    //     ownerTid.send(cast(immutable)e.taskException);
    // }
    catch(Throwable e){
        log.fatal(e.msg);
        ownerTid.send(cast(immutable)e);
    }
}

private struct ActiveNodeSubscribtion(Net : HashNet) {
    protected Tid handlerTid;
    protected shared(p2plib.RequestStream) stream;
    protected bool subscribed;
    @disable this();
   // protected Net net;
    @property bool isSubscribed(){
        return subscribed;
    }
    protected immutable(Options) opts;
    this(immutable(Options) opts){
        this.opts = opts;
    }
    void tryToSubscribe(NodeAddress[Pubkey] node_addreses, shared(p2plib.Node) node){
        bool subscribeTo(NodeAddress address){
            try{
                stream = node.connect(address.address, address.is_marshal, opts.dart.subs.protocol_id);
                auto taskName = opts.dart.subs.slave_task_name;
                handlerTid = spawn(&handleSubscription, taskName);
                receiveOnly!Control;
                stream.listen(&StdHandlerCallback, taskName, opts.dart.subs.host.timeout.msecs, opts.dart.subs.host.max_size);
                return true;
            }
            catch(Exception e){
                log("subscribe error: %s", e);
            }
            return false;
        }
        // writeln("looking for master node");

        foreach(node_id, node_address; node_addreses){ //TODO: should be random
        // writefln("master port: %d \tport: %d", opts.dart.subs.master_port, node_address.port);
            if(!opts.dart.master_from_port || node_address.port == opts.dart.subs.master_port){
                log("master node found");
                if(subscribeTo(node_address)){
                    subscribed = true;
                    return;
                }
            }
            log("Master not found");
        }
    }

    void stop(){
        log("Stop subscription");
        if(subscribed && handlerTid != Tid.init){
            send(handlerTid, Control.STOP);
            // receiveOnly!Control;
        }
    }

    protected static void handleSubscription(string taskName){   //TODO: moveout
        scope(exit){
            log("exit handleSubscription");
            // ownerTid.prioritySend(Control.END);
        }
        pragma(msg, "Why is fake net used here?");
//        auto net = new MyFakeNet();
        auto net = new Net;
        log.register(taskName);
        auto stop = false;
        ownerTid.send(Control.LIVE);

        while(!stop){
            receive(
                (Control cntrl){
                    if(cntrl == Control.STOP){
                        stop = true;
                    }
                },
                (Response!(ControlCode.Control_Disconnected) resp) {
                    writeln("Subscribe Disconnected key: ", resp.key);
                },
                (Response!(ControlCode.Control_RequestHandled) response){
                    writeln("Subscribe recorder received");
                    auto doc = Document(response.data);
                    immutable recorder = cast(immutable)DARTFile.Recorder(net, doc);
                    send(ownerTid, recorder);
                }
            );
        }
    }
}
