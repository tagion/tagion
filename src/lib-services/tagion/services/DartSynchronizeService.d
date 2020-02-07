module tagion.services.DartSynchronizeService;

import core.thread;
import std.concurrency;

import tagion.Options;

import p2plib = p2p.node;
import p2p.connection;
import p2p.callback;
import p2p.cgo.helper;
import tagion.services.LoggerService;
import tagion.Base : Buffer, Control;
import std.getopt;
import std.stdio;
import std.conv;
import tagion.utils.Miscellaneous : toHexString, cutHex;
import tagion.dart.DARTFile;
import tagion.dart.DART;
import tagion.dart.BlockFile : fileId;
import tagion.Base;
import tagion.Keywords;
import tagion.crypto.secp256k1.NativeSecp256k1;
import tagion.dart.DARTSynchronization;

import tagion.hibon.HiBONJSON;
import tagion.hibon.Document;
import tagion.hibon.HiBON : HiBON;
import tagion.gossip.InterfaceNet: SecureNet;
import tagion.communication.HiRPC;

alias HiRPCSender = HiRPC.HiRPCSender;
alias HiRPCReceiver = HiRPC.HiRPCReceiver;

static bool inRange(ref ushort sector, ushort from_sector, ushort to_sector) pure nothrow  {
    if(from_sector == to_sector) return true;
    immutable ushort sector_origin=(sector-from_sector) & ushort.max;
    immutable ushort to_origin=(to_sector-from_sector) & ushort.max;
    return ( sector_origin < to_origin );    
}

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
        _state = state;
        notifyOwner(); //TODO: manualy notify?
    }

    @property T state(){
        return _state;
    }

    void notifyOwner(){
        send(ownerTid, _state);
    }
}

void dartSynchronizeServiceTask(Net)(immutable(Options) opts, shared(p2plib.Node) node,  shared(SecureNet) master_net) {
    try{
        auto state = ServiceState!DartSynchronizeState(DartSynchronizeState.WAITING);
        setOptions(opts);
        immutable task_name=opts.dart.sync.task_name;
        auto pid = opts.dart.sync.protocol_id;
        log.register(task_name);

        log("-----Start Dart Sync service-----");
        scope(success){
            log("------Stop Dart Sync service-----");
            ownerTid.prioritySend(Control.END);
        }
        scope(failure){
            log("------Error Stop Dart Sync service-----");
            ownerTid.prioritySend(Control.END);
        }
        immutable filename = fileId!(DART)(opts.dart.name).fullpath;
        if (opts.dart.initialize) {
            DARTFile.create_dart(filename);
        }
        log("Dart file created with filename: %s", filename);

        auto net = new Net();
        net.drive(opts.dart.sync.task_name, master_net);

        auto node_number = opts.port - opts.port_base;
        ushort from_ang;
        ushort to_ang;
        if(opts.dart.angle_from_port){
            pragma(msg, "Fixme(as): static table");
            import std.math: ceil, floor;

            auto angRange = DiscoveryService.NodeAddress.calcAngleRange(opts, node_number, opts.dart.sync.maxSlaves);
            from_ang = angRange[0];
            to_ang = angRange[1];
        }else{
            from_ang = opts.dart.from_ang;
            to_ang = opts.dart.to_ang;
        }
        auto dart = new DART(net, filename, from_ang, to_ang);
        log("DART initialized with angle from: %d to: %d", from_ang, to_ang);

        if (opts.dart.generate) {
            auto fp = SetInitialDataSet(dart, opts.dart.ringWidth, opts.dart.rings);
            log("DART generated: bullseye: %s", fp.cutHex);
            dart.dump;
        }

        node.listen(pid, &StdHandlerCallback, cast(string) task_name, opts.dart.sync.host.timeout.msecs, cast(uint) opts.dart.sync.host.max_size);

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
        immutable(DARTFile.Recorder)[] recorders;
        ownerTid.send(Control.LIVE);
 
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))(opts.dart.sync.host.timeout.msecs);
        auto sync_factory = new P2pSynchronizationFactory(dart, node, connectionPool, opts);
        auto syncPool = new DartSynchronizationPool!(StdHandlerPool!(ResponseHandler, uint))(dart.sectors, opts);
        auto discoveryService = DiscoveryService(node, opts);

        scope(exit){
            discoveryService.stop;
            writeln("exit scope: call stop");
            syncPool.stop;
        }

        discoveryService.start();
        if(opts.dart.synchronize) {
            state.setState(DartSynchronizeState.WAITING);
        }else{
            state.setState(DartSynchronizeState.READY);
        }
        alias JournalReplay =  ReplayFiber!(string, (DART dart, string journal)=> dart.replay(journal));
        alias RecorderReplay = ReplayFiber!(immutable(DARTFile.Recorder), (DART dart, immutable(DARTFile.Recorder) recorder)=> dart.modify(cast(DARTFile.Recorder) recorder));
        JournalReplay journalReplayFiber= new JournalReplay(dart, P2pSynchronizationFactory.P2pSynchronizer.journals);
        RecorderReplay recorderReplayFiber = new RecorderReplay(dart, recorders);

        auto readPool = new StdHandlerPool!(ReadRequestHandler, uint)(opts.dart.commands.read_timeout.msecs);
        
        HiRPC hrpc;
        auto empty_hirpc = HiRPC(null);
        hrpc.net = net;
        while(!stop) {
            try{
                const tick_timeout = state.checkState(
                    DartSynchronizeState.REPLAYING_JOURNALS, 
                    DartSynchronizeState.REPLAYING_RECORDERS)
                    ? opts.dart.sync.replay_tick_timeout.msecs 
                    : opts.dart.sync.tick_timeout.msecs;
                receiveTimeout(tick_timeout,
                    &handleControl,
                    (immutable(DARTFile.Recorder) recorder){
                        log("DSS: recorder received");
                        recorders ~= recorder;
                    },
                    (Response!(ControlCode.Control_Connected) resp) {
                        log("DSS: Client Connected key: %d", resp.key);
                        connectionPool.add(resp.key, resp.stream, true);
                    },
                    (Response!(ControlCode.Control_Disconnected) resp) {
                        log("DSS: Client Disconnected key: %d", resp.key);  
                        connectionPool.close(cast(void*)resp.key);
                    },
                    (Response!(ControlCode.Control_RequestHandled) resp) {  //TODO: moveout to factory
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
                            auto received = hrpc.receive(doc);
                            auto request = dart(received);
                            auto tosend = hrpc.toHiBON(request).serialize;
                            connectionPool.send(resp.key, tosend);
                            // log("DSS: Sended response to connection: %s", resp.key);
                        }
                        if(message_doc.hasElement(Keywords.method) && state.checkState(DartSynchronizeState.READY)){ //TODO: to switch
                            serverHandler();
                        }else if(!message_doc.hasElement(Keywords.method)){
                            if(state.checkState(DartSynchronizeState.SYNCHRONIZING)){
                                syncPool.setResponse(resp);
                            }else{
                                auto response = ResponseHandler.Response!uint(message_doc[Keywords.id].get!uint, resp.data);
                                readPool.setResponse(response);
                            }
                        }else{
                            closeConnection();
                        }
                    },
                    (string taskName, Buffer data){
                        log("DSS: Received request from service: %s", task_name);
                        const doc = Document(data);
                        auto receiver = empty_hirpc.receive(doc);
                        const message_doc = doc[Keywords.message].get!Document;
                        const hrpc_id = message_doc[Keywords.id].get!uint;

                        const method = message_doc[Keywords.method].get!string;
                        
                        void readDart(){
                            scope doc_fingerprints=receiver.params[DARTFile.Params.fingerprints].get!(Document);
                            scope fingerprints=doc_fingerprints.range!(Buffer[]);  
                            alias bufArr = Buffer[];
                            bufArr[DiscoveryService.NodeAddress] remote_fp_requests;
                            Buffer[] local_fp;

                            fpIterator: foreach(fp; fingerprints){
                                ushort sector = fp[0] | fp[1];
                                if(dart.inRange(sector)){
                                    local_fp~=fp;
                                    continue fpIterator;
                                }else{
                                    foreach(address, fps; remote_fp_requests){
                                        if(sector.inRange(address.sector.from_sector,address.sector.to_sector)){
                                            fps~=fp;
                                            remote_fp_requests[address] = fps;
                                            continue fpIterator;
                                        }
                                    }
                                    foreach(id, address; DiscoveryService.node_addrses){
                                        if(sector.inRange(address.sector.from_sector, address.sector.to_sector)){
                                            remote_fp_requests[address] = [fp];
                                            continue fpIterator;
                                        }
                                    }
                                }
                            }
                            auto recorder=dart.loads(local_fp, DARTFile.Recorder.Archive.Type.ADD);

                            if(remote_fp_requests.length != 0){
                                import std.array;
                                auto rs = new ReadRequestHandler(array(fingerprints), hrpc, taskName, receiver);
                                readPool.add(hrpc_id, rs);
                                if(local_fp.length>0){
                                    readPool.setResponse(ResponseHandler.Response!uint(hrpc_id, empty_hirpc.result(receiver, recorder.toHiBON).toHiBON(net).serialize));
                                }
                                foreach(addr, fps; remote_fp_requests){
                                    auto stream = node.connect(addr.address, [pid]);
                                    // connectionPool.add(stream.Identifier, stream);
                                    stream.listen(&StdHandlerCallback, opts.dart.task_name, opts.dart.sync.host.timeout.msecs, opts.dart.sync.host.max_size);
                                    auto params=new HiBON;
                                    auto params_fingerprints=new HiBON;
                                    foreach(i, b; fps) {
                                        if ( b.length !is 0 ) {
                                            params_fingerprints[i]=b;
                                        }
                                    }
                                    params[DARTFile.Params.fingerprints]=params_fingerprints;
                                    const request = empty_hirpc.dartRead(params, hrpc_id);
                                    immutable foreign_data = empty_hirpc.toHiBON(request).serialize;
                                    stream.writeBytes(foreign_data);
                                }
                            }else{
                                if(local_fp.length != 0){
                                    auto tid = locate(task_name);
                                    if(tid != Tid.init){
                                        send(tid, empty_hirpc.result(receiver, recorder.toHiBON).toHiBON(net).serialize);
                                    }
                                }
                            }
                        }

                        void modifyDart(){
                            HiRPC.check_element!Document(receiver.params, DARTFile.Params.recorder);
                            scope recorder_doc=receiver.params[DARTFile.Params.recorder].get!Document;
                            scope recorder=DARTFile.Recorder(net, recorder_doc);
                            immutable bullseye=dart.modify(recorder);
                            auto hibon_params=new HiBON;
                            hibon_params[DARTFile.Params.bullseye]=bullseye;
                            auto tid = locate(task_name);
                            if(tid != Tid.init){
                                send(tid, empty_hirpc.result(receiver, recorder.toHiBON).toHiBON(net).serialize);
                            }
                        }

                        if(method == DART.Quries.dartRead){
                            readDart();
                        }
                        else if(method == DART.Quries.dartModify){
                            modifyDart();
                        }
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

                connectionPool.tick();
                readPool.tick();
                discoveryService.tick();
                if(opts.dart.synchronize){
                    syncPool.tick();
                    if(discoveryService.isReady && syncPool.isReady){
                        sync_factory.setNodeTable(discoveryService.node_addrses);
                        syncPool.start(sync_factory);
                        state.setState(DartSynchronizeState.SYNCHRONIZING);
                    }
                    if(syncPool.isOver){
                        syncPool.stop;
                        log("Start replay journals with: %d journals", P2pSynchronizationFactory.P2pSynchronizer.journals.length);
                        state.setState(DartSynchronizeState.REPLAYING_JOURNALS);
                    }
                    if(syncPool.isError){
                        sync_factory.setNodeTable(discoveryService.node_addrses);
                        syncPool.start(sync_factory);
                        state.setState(DartSynchronizeState.SYNCHRONIZING); //TODO: remove if notification not needed
                    }
                }
                if(state.checkState(DartSynchronizeState.REPLAYING_JOURNALS)){
                    if(!journalReplayFiber.empty){
                        journalReplayFiber.call;
                    }else{
                        log("Start replay recorders with: %d recorders", recorders.length);
                        connectionPool.closeAll();
                        state.setState(DartSynchronizeState.REPLAYING_RECORDERS);
                    }
                }
                if(state.checkState(DartSynchronizeState.REPLAYING_RECORDERS)){
                    if(!recorderReplayFiber.empty){
                        recorderReplayFiber.call;
                    }else{
                        recorderReplayFiber.reset();
                        dart.dump(true);
                        log("DART generated: bullseye: %s", dart.fingerprint.toHexString);
                        state.setState(DartSynchronizeState.READY);
                    }
                }
            }catch(Exception e){
                log("Iteration exception: %s", e);
            }
            catch(Throwable t) {
                log("Iteration throwable: %s", t);
            }
        }
    }catch(Exception e){
        log("EXCEPTION: %s", e);
    }
    catch(Throwable t) {
        log("THROWABLE: %s", t);
    }
}
