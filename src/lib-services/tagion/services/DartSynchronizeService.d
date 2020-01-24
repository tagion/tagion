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

import tagion.communication.HiRPC;

alias HiRPCSender = HiRPC.HiRPCSender;
alias HiRPCReceiver = HiRPC.HiRPCReceiver;

static bool inRange(ref ushort sector, ushort from_sector, ushort to_sector) pure nothrow  {
    immutable ushort sector_origin=(sector-from_sector) & ushort.max;
    immutable ushort to_origin=(to_sector-from_sector) & ushort.max;
    return ( sector_origin < to_origin );    
}

enum DartSynchronizeControl{
    GetStatus = 1,
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

void dartSynchronizeServiceTask(immutable(Options) opts, shared(p2plib.Node) node) {
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
        writeln("CREATING DART1");
        immutable filename = fileId!(DART)(opts.dart.name).fullpath;
        writeln("DART FILENAME:", filename);
        if (opts.dart.initialize) {
            DARTFile.create_dart(filename);
        }

        auto crypt=new NativeSecp256k1;
        auto net = new MyFakeNet(crypt);

        net.generateKeyPair(node.Id[0..32]);
        
        auto node_number = opts.port - opts.portBase;
        ushort fromAng;
        ushort toAng;
        if(opts.dart.setAngleFromPort){
            pragma(msg, "Fixme(as): static table");
            import std.math: ceil, floor;
            double delta = (cast(double)(opts.dart.sync.netToAng - opts.dart.sync.netFromAng))/opts.dart.sync.maxSlaves;
            fromAng = to!ushort(opts.dart.fromAng + (node_number)*floor(delta)); 
            toAng = to!ushort(opts.dart.fromAng + (node_number+1)*ceil(delta));
        }else{
            fromAng = opts.dart.fromAng;
            toAng = opts.dart.toAng;
        }
        writefln("DART from: %d to: %d", fromAng, toAng);
        auto dart = new DART(net, filename, fromAng, toAng);

        if (opts.dart.generate) {
            writeln("GENERATING DART");
            auto fp = SetInitialDataSet(dart, opts.dart.ringWidth, opts.dart.rings, fromAng, toAng);
            writeln("DART Initialized: ", fp.cutHex);
            dart.dump;
        }

        node.listen(pid, &StdHandlerCallback, cast(string) task_name, opts.dart.sync.host.timeout.msecs, cast(uint) opts.dart.sync.host.max_size);

        bool stop;
        void handleControl (Control ts) {
            with(Control) switch(ts) {
                case STOP:
                    log("Kill dart service");
                    stop = true;
                    break;
                default:
                    log.error("Bad Control command %s", ts);
                }
        }

        void handleDartControl(DartSynchronizeControl dc){
            with(DartSynchronizeControl) switch(dc){
                case GetStatus: state.notifyOwner(); break;
                default: break;
            }
        }
        immutable(DARTFile.Recorder)[] recorders;
        ownerTid.send(Control.LIVE);
        
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))();

        DartSynchronizationPool syncPool = new DartSynchronizationPool(dart, node, connectionPool, opts);
        auto discoveryService = DiscoveryService(node, opts);

        scope(exit){
            writeln("connectionPool.len: ", connectionPool.size);
            discoveryService.stop;
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
        JournalReplay journalReplayFiber= new JournalReplay(dart, P2pSynchronizer.journals);
        RecorderReplay recorderReplayFiber = new RecorderReplay(dart, recorders);

        auto readPool = new HandlerPool!(ReadSynchronizer, uint)(opts.dart.commands.read_timeout.msecs);
        
        HiRPC hrpc;
        auto empty_hirpc = HiRPC(null);
        hrpc.net = net;
        while(!stop) {
            receiveTimeout(opts.dart.sync.tickTimeout.msecs,
                &handleControl,
                &handleDartControl,
                (immutable(DARTFile.Recorder) recorder){
                    writeln("setRecorder");
                    recorders ~= recorder;
                },
                (Response!(ControlCode.Control_Connected) resp) {
                    writeln("Client Connected key: ", resp.key);
                    connectionPool.add(resp.key, resp.stream);
                },
                (Response!(ControlCode.Control_Disconnected) resp) {
                    writeln("Client Disconnected key: ", resp.key);     
                    connectionPool.close(cast(void*)resp.key);
                },
                (Response!(ControlCode.Control_RequestHandled) resp) {  //TODO: moveout to factory
                    scope(exit){
                        if(resp.stream !is null){
                            destroy(resp.stream);
                        }
                    }
                    auto doc = Document(resp.data);
                    auto message_doc = doc[Keywords.message].get!Document;
                    void closeConnection(){
                        writeln("Close connection");
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
                    writeln("DSS: received request from: ", taskName);
                    const doc = Document(data);
                    auto receiver = empty_hirpc.receive(doc);
                    const message_doc = doc[Keywords.message].get!Document;
                    const hrpc_id = message_doc[Keywords.id].get!uint;
                    
                    const method = message_doc[Keywords.method].get!string;
                    if(method == DART.Quries.dartRead){
                        scope doc_fingerprints=receiver.params[DARTFile.Params.fingerprints].get!(Document);
                        scope fingerprints=doc_fingerprints.range!(Buffer[]);  
                        alias bufArr = Buffer[];
                        bufArr[DiscoveryService.NodeAddress] remote_fp_requests;
                        Buffer[] local_fp;

                        fpIterator: foreach(fp; fingerprints){
                            ushort sector = fp[0] | fp[1];
                            if(dart.inRange(sector)){
                                writeln("in range");
                                local_fp~=fp;
                                continue fpIterator;
                            }else{
                                foreach(address, fps; remote_fp_requests){
                                    writeln("check rfr addr from", address.fromAng, " to ", address.toAng, " with sector ", sector);
                                    if(sector.inRange(address.fromAng,address.toAng)){
                                        fps~=fp;
                                        remote_fp_requests[address] = fps;
                                        continue fpIterator;
                                    }
                                }
                                foreach(id, address; DiscoveryService.node_addrses){
                                    writeln("check address from", address.fromAng, " to ", address.toAng, " with sector ", sector);
                                    if(sector.inRange(address.fromAng, address.toAng)){
                                        remote_fp_requests[address] = [fp];
                                        continue fpIterator;
                                    }                                    
                                }
                            }                            
                        }
                        auto recorder=dart.loads(local_fp, DARTFile.Recorder.Archive.Type.ADD);

                        if(remote_fp_requests.length != 0){
                            import std.array;
                            auto rs = new ReadSynchronizer(array(fingerprints), hrpc, taskName, receiver);
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

            readPool.tick();
            discoveryService.tick();
            if(opts.dart.synchronize){
                syncPool.tick();
                if(discoveryService.isReady && syncPool.isReady){
                    syncPool.start(discoveryService.node_addrses);
                    state.setState(DartSynchronizeState.SYNCHRONIZING);
                }
                if(syncPool.isOver){
                    writefln("is over");
                    syncPool.stop;
                    state.setState(DartSynchronizeState.REPLAYING_JOURNALS);
                }
                if(syncPool.isError){
                    writeln("syncPool has an Error");
                    syncPool.start(discoveryService.node_addrses);
                    state.setState(DartSynchronizeState.SYNCHRONIZING);
                }
            }
            if(state.checkState(DartSynchronizeState.REPLAYING_JOURNALS)){
                if(!journalReplayFiber.empty){
                    journalReplayFiber.call;
                }else{
                    state.setState(DartSynchronizeState.REPLAYING_RECORDERS);
                }
            }
            if(state.checkState(DartSynchronizeState.REPLAYING_RECORDERS)){
                if(!recorderReplayFiber.empty){
                    recorderReplayFiber.call;
                }else{
                    recorderReplayFiber.reset();
                    state.setState(DartSynchronizeState.READY);
                }
            }
            stdout.flush();
        }
    }catch(Exception e){
        writefln("EXCEPTION: %s", e);
    }
} 