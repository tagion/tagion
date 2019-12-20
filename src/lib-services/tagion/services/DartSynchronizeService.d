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

enum DartControl{
    WAITING = 4,
    READY = 5,
    SYNCHRONIZING = 6
}

void dartSynchronizeServiceTask(immutable(Options) opts, shared(p2plib.Node) node) {
    writeln("SERVICE CREATED"); 
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
        auto dart = new DART(net, filename, opts.dart.fromAng, opts.dart.toAng);

        if (opts.dart.generate) {
            writeln("GENERATING DART");
            auto fp = GetInitialDataSet(dart, opts.dart.ringWidth, opts.dart.rings, opts.dart.fromAng, opts.dart.toAng);
            // log("DART initialized");
            // log("EYE: %x", fp.cutHex);
            writeln("DART Initialized: ", fp.cutHex);
        }
        
        writeln(opts.dart.host.timeout.msecs);
        node.listen("dartsyncsync", &StdHandlerCallback, cast(string) task_name, opts.dart.host.timeout.msecs, cast(uint) opts.dart.host.max_size);

        bool stop;
        void handleState (Control ts) {
            with(Control) switch(ts) {
                case STOP:
                    // log("Kill dart service");
                    stop = true;
                    break;
                default:
                    // log.error("Bad Control command %s", ts);
                }
        }

        ownerTid.send(Control.LIVE);
        auto handlerPool = new HandlerPool!(P2pSynchronizer, Pubkey)(opts.dart.host.timeout.msecs);
        enum tickTimeout = 1.seconds;
        
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))();
        DartSynchronizationPool syncPool = new DartSynchronizationPool(dart, node, connectionPool, opts);
        bool isUpdated = false;
        if(opts.dart.synchronize) {
            send(ownerTid, DartControl.WAITING);
            writefln("Run mdns");
            syncPool.runMdns();
            writefln("after Run mdns");
        }else{
            isUpdated = true;
            send(ownerTid, DartControl.READY);
        }

        while(!stop) {
            receiveTimeout(tickTimeout,
                &handleState,
                (Response!(ControlCode.Control_Connected) resp) {    
                    writeln("Client Connected key: ", resp.key);
                    connectionPool.add(resp.key, resp.stream);
                },
                (Response!(ControlCode.Control_Disconnected) resp) { 
                    writeln("Client Disconnected key: ", resp.key);     
                    connectionPool.close(cast(void*)resp.key);
                },
                (Response!(ControlCode.Control_RequestHandled) resp) {  
                    writeln("i get a response");
                    auto doc = Document(resp.data);
                    auto message_doc = doc[Keywords.message].get!Document;
                    writeln("after convert");
                    void serverHandler(){
                        writeln("as a server");
                        HiRPC hrpc;
                        hrpc.net = net;
                        auto received = hrpc.receive(doc);
                        auto request = dart(received);
                        auto tosend = hrpc.toHiBON(request).serialize;
                        connectionPool.send(resp.key, tosend);
                        destroy(resp.stream);
                    }
                    void clientHandler(){
                        writeln("set sync pool resposne");
                        syncPool.setResponse(resp);
                    }
                    if(message_doc.hasElement(Keywords.method) && isUpdated){
                        serverHandler();
                    }else if(!message_doc.hasElement(Keywords.method) && !isUpdated){
                        clientHandler();
                    }else{
                        writeln("Close connection");
                        connectionPool.close(resp.key);
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
            handlerPool.tick();
            if(opts.dart.synchronize){
                syncPool.tick();
                if(syncPool.isReady){
                    syncPool.start();
                    send(ownerTid, DartControl.SYNCHRONIZING);
                }
                if(syncPool.isOver){
                    writefln("is over");
                    P2pSynchronizer.replay(dart); //block until update db
                    isUpdated = true;
                    syncPool.stop;
                    send(ownerTid, DartControl.READY);
                }
            }
        }
    }catch(Exception e){
        writefln("EXCEPTION: %s", e);
    }
}