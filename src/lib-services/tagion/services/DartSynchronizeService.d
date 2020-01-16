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
            auto delta = (opts.dart.toAng - opts.dart.fromAng)/opts.dart.sync.maxSlaves;
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
        auto handlerPool = new HandlerPool!(P2pSynchronizer, Pubkey)(opts.dart.host.timeout.msecs);
        enum tickTimeout = 50.msecs;
        
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))();
        DartSynchronizationPool syncPool = new DartSynchronizationPool(dart, node, connectionPool, opts);
        auto discoveryService = DiscoveryService(node);
        if(opts.dart.synchronize) {
            state.setState(DartSynchronizeState.WAITING);
            discoveryService.start();
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
                    void clientHandler(){
                        writeln("set sync pool resposne");
                        syncPool.setResponse(resp);
                    }
                    if(message_doc.hasElement(Keywords.method) && state.state == DartSynchronizeState.READY){ //TODO: to switch
                        serverHandler();
                    }else if(!message_doc.hasElement(Keywords.method) && state.state == DartSynchronizeState.SYNCHRONIZING){
                        clientHandler();
                    }else{
                        closeConnection();
                    }
                },
                (string taskName, Buffer data){
                    writeln("DSS: received request from: ", taskName);
                    scope hrpc = HiRPC(null);
                    const doc = Document(data);
                    const message_doc = doc[Keywords.message].get!Document;
                    
                    const method = message_doc[Keywords.method].get!string;
                    if(method == DART.Quries.dartRead){
                        // auto port = addrPort(node_addrses[selectedNode]);
                        // DartSynchronizationPool.node_addrses
                    }

                    const received = hrpc.receive(doc);

                    auto response = dart(received);
                    auto tid = locate(taskName);
                    if(tid != Tid.init){
                        auto tosend = hrpc.toHiBON(response).serialize;
                        send(tid, tosend);
                    }else{
                        // log.fatal ..  
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
            // readPool.tick();
            if(opts.dart.synchronize){
                syncPool.tick();
                discoveryService.tick();
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