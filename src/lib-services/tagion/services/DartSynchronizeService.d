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

enum DartSynchronizeControl{
    GetStatus = 1,
}

enum DartSynchronizeState{
    WAITING = 4,
    READY = 5,
    SYNCHRONIZING = 6,
    REPLAYING_JOURNALS = 7,
    REPLAYING_RECORDERS = 8,
}


struct ServiceState(T) {
    protected T _state;
    this(T initial){
        _state = initial;
    }
    void setState(T state){
        _state = state;
        notifyOwner();
    }

    @property T state(){
        return _state;
    }

    void notifyOwner(){
        send(ownerTid, _state);
    }
}

void dartSynchronizeServiceTask(immutable(Options) opts, shared(p2plib.Node) node) {
    writeln("SERVICE CREATED"); 
    auto state = ServiceState!DartSynchronizeState(DartSynchronizeState.WAITING);
    try{
        setOptions(opts);
        immutable task_name=opts.dart.task_name;
        auto pid = task_name~"sync";
        log.register(task_name);

        // log("-----Start Dart service-----");
        scope(success){
            // log("------Stop Dart service-----");
            ownerTid.prioritySend(Control.END);
        }

        // log("-----Creating dart-----");
        writeln("CREATING DART1");
        immutable filename = fileId!(DART)(opts.dart.name).fullpath;
        writeln("DART FILENAME:", filename);
        if (opts.dart.initialize) {
            DARTFile.create_dart(filename);
        }

        auto crypt=new NativeSecp256k1;
        auto net = new MyFakeNet(crypt);

        net.generateKeyPair(node.Id[0..32]);
        
        auto port = opts.port - opts.portBase;
        ushort fromAng;
        ushort toAng;
        if(opts.dart.setAngleFromPort){
            pragma(msg, "Fixme(as): static table");
            auto delta = (opts.dart.sync.netToAng - opts.dart.sync.netFromAng)/opts.dart.sync.maxSlaves;
            fromAng = to!ushort(opts.dart.fromAng + (port)*delta ); 
            toAng = to!ushort(opts.dart.fromAng + (port+1)*(delta+1));
        }else{
            fromAng = opts.dart.fromAng;
            toAng = opts.dart.toAng;
        }
        writefln("from: %d to: %d", fromAng, toAng);
        auto dart = new DART(net, filename, fromAng, toAng);

        if (opts.dart.generate) {
            writeln("GENERATING DART");
            auto fp = GetInitialDataSet(dart, opts.dart.ringWidth, opts.dart.rings, fromAng, toAng);
            writeln("DART Initialized: ", fp.cutHex);
            dart.dump;
        }
        
        writeln(opts.dart.host.timeout.msecs);
        node.listen("dartsyncsync", &StdHandlerCallback, cast(string) task_name, opts.dart.host.timeout.msecs, cast(uint) opts.dart.host.max_size);

        bool stop;
        void handleControl (Control ts) {
            with(Control) switch(ts) {
                case STOP:
                    // log("Kill dart service");
                    stop = true;
                    break;
                default:
                    // log.error("Bad Control command %s", ts);
                }
        }

        void handleDartControl(DartSynchronizeControl dc){
            with(DartSynchronizeControl) switch(dc){
                case GetStatus: state.notifyOwner(); break;
                default: break;
            }
        }

        immutable(DARTFile.Recorder)[] recorders;
        void setRecorder(immutable(DARTFile.Recorder) recorder){
            recorders~=recorder;
        }
        ownerTid.send(Control.LIVE);
        enum tickTimeout = 50.msecs;
        
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))();
        DartSynchronizationPool syncPool = new DartSynchronizationPool(dart, node, connectionPool, opts);
        auto discoveryService = DiscoveryService(node, opts);
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

        auto readPool = new HandlerPool!(ReadSynchronizer, uint)(1.minutes);
        
        HiRPC hrpc;
        hrpc.net = net;
        while(!stop) {
            receiveTimeout(tickTimeout,
                &handleControl,
                &handleDartControl,
                (immutable(DARTFile.Recorder) recorder){
                    writeln("setRecorder");
                    setRecorder(recorder);
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
                    auto doc = Document(resp.data);
                    auto message_doc = doc[Keywords.message].get!Document;
                    void closeConnection(){
                        writeln("Close connection");
                        connectionPool.close(resp.key);
                    }
                    void serverHandler(){
                        writeln("as a server");
                        if(message_doc[Keywords.method].get!string == DART.Quries.dartModify){  //Not allowed
                            closeConnection();
                        }
                        auto received = hrpc.receive(doc);
                        auto request = dart(received);
                        auto tosend = hrpc.toHiBON(request).serialize;
                        // writeln("RESPONSE:");
                        // writeln(Document(tosend).toJSON(true));
                        writeln("RESPONSE KEY: ", resp.key);
                        connectionPool.send(resp.key, tosend);
                        destroy(resp.stream);
                    }
                    if(message_doc.hasElement(Keywords.method) && state.state == DartSynchronizeState.READY){ //TODO: to switch
                        serverHandler();
                    }else if(!message_doc.hasElement(Keywords.method)){
                        if(state.state == DartSynchronizeState.SYNCHRONIZING){
                            syncPool.setResponse(resp);
                        }else{
                            writeln("set read pool response ", message_doc[Keywords.id].get!uint);
                            auto response = ResponseHandler.Response!uint(message_doc[Keywords.id].get!uint, resp.data);
                            readPool.setResponse(response);
                        }
                    }else{
                        closeConnection();
                    }
                },
                (string taskName, Buffer data){
                    writeln("DSS: received request from: ", taskName);
                    auto empty_hirpc = HiRPC(null);
                    const doc = Document(data);
                    writeln(doc.toJSON);
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
                            writeln("sector:", sector);
                            if(dart.inRange(sector)){
                                writeln("in range");
                                local_fp~=fp;
                                continue fpIterator;
                            }else{
                                foreach(address, fps; remote_fp_requests){
                                    writeln("check rfr addr from", address.fromAng, " to ", address.toAng, " with sector ", sector);
                                    if(sector >= address.fromAng && sector<= address.toAng){
                                        fps~=fp;
                                        remote_fp_requests[address] = fps;
                                        continue fpIterator;
                                    }
                                }
                                foreach(id, address; DiscoveryService.node_addrses){
                                    writeln("check address from", address.fromAng, " to ", address.toAng, " with sector ", sector);
                                    if(sector>= address.fromAng && sector<= address.toAng){
                                        remote_fp_requests[address] = [fp];
                                        continue fpIterator;
                                    }                                    
                                }
                            }                            
                        }
                        writeln("remote_fp_requests:", remote_fp_requests);
                        writeln("local_fp:", local_fp);
                        auto recorder=dart.loads(local_fp, DARTFile.Recorder.Archive.Type.ADD);

                        if(remote_fp_requests.length != 0){
                            import std.array;
                            auto rs = new ReadSynchronizer(array(fingerprints), hrpc, taskName, receiver);
                            writeln("add : ", hrpc_id);
                            readPool.add(hrpc_id, rs);
                            if(local_fp.length>0){
                                writeln("set local fp response");
                                readPool.setResponse(ResponseHandler.Response!uint(hrpc_id, empty_hirpc.result(receiver, recorder.toHiBON).toHiBON(net).serialize));
                            }
                            foreach(addr, fps; remote_fp_requests){
                                auto stream = node.connect(addr.address, [task_name~"sync"]);
                                // connectionPool.add(stream.Identifier, stream);
                                stream.listen(&StdHandlerCallback, opts.dart.task_name, opts.dart.host.timeout.msecs, opts.dart.host.max_size);
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
                                writeln("requested");
                                stream.writeBytes(foreign_data);
                            }
                        }else{
                            if(local_fp.length != 0){
                                auto tid = locate(task_name);
                                if(tid != Tid.init){
                                    writeln("sending local fp!!");
                                    send(tid, empty_hirpc.result(receiver, recorder.toHiBON).toHiBON(net).serialize);
                                }
                            }
                        }
                        
                    }
                },
                (immutable(Exception) e) {
                    // log.fatal(e.msg);
                    stop=true;
                    ownerTid.send(e);
                },
                (immutable(Throwable) t) {
                    // log.fatal(t.msg);
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
                    // P2pSynchronizer.replay(dart); //block until update db
                    syncPool.stop;
                    state.setState(DartSynchronizeState.REPLAYING_JOURNALS);
                }
            }
            if(state.state == DartSynchronizeState.REPLAYING_JOURNALS){
                if(!journalReplayFiber.empty){
                    writeln("journals count", P2pSynchronizer.journals.length);
                    journalReplayFiber.call;
                }else{
                    state.setState(DartSynchronizeState.REPLAYING_RECORDERS);
                }
            }
            if(state.state == DartSynchronizeState.REPLAYING_RECORDERS){
                if(!recorderReplayFiber.empty){
                    writeln("recorders count", recorders.length);
                    recorderReplayFiber.call;
                }else{
                    recorderReplayFiber.reset();
                    state.setState(DartSynchronizeState.READY);
                }
            }

            if(state.state == DartSynchronizeState.READY){
                
            }
        }
    }catch(Exception e){
        writefln("EXCEPTION: %s", e);
    }
} 