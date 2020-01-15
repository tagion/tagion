module tagion.services.DartService;

import core.thread;
import std.concurrency;

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
import tagion.Options;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document;
import tagion.hibon.HiBON : HiBON;

import tagion.communication.HiRPC;
import tagion.services.DartSynchronizeService;

alias HiRPCSender = HiRPC.HiRPCSender;
alias HiRPCReceiver = HiRPC.HiRPCReceiver;

enum DartControl{
    GetStatus = 1,
    Start = 2
}

enum DartState{
    WAITING = 4,
    READY = 5,
    SYNCHRONIZING = 6
}


void dartServiceTask(immutable(Options) opts, shared(p2plib.Node) node) {
    writeln("DS: SERVICE CREATED");
    auto state = ServiceState!DartState(DartState.WAITING); 
    try{
        setOptions(opts);
        immutable task_name=opts.dart.task_name~"dd";
        auto pid = task_name~"ddd";
        log.register(task_name);

        // log("-----Start Dart service-----");
        scope(success){
            // log("------Stop Dart service-----");
            ownerTid.prioritySend(Control.END);
        }

        bool stop = false;
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

        void handleDartControl(DartControl dc){
            with(DartControl) switch(dc){
                case GetStatus: state.notifyOwner(); break;
                case Start: writeln("DS: START"); break;
                default: break;
            }
        }
        node.listen("dartsubs", &StdHandlerCallback, cast(string) task_name, 1.minutes, cast(uint) opts.dart.host.max_size);
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))();
        while(!stop) {
            receive(
                    &handleControl,
                    &handleDartControl,
                    (Response!(ControlCode.Control_Connected) resp) {    
                        writeln("DS: Client Connected key: ", resp.key);
                        connectionPool.add(resp.key, resp.stream);
                    },
                    (Response!(ControlCode.Control_Disconnected) resp) { 
                        writeln("DS: Client Disconnected key: ", resp.key);     
                        connectionPool.close(cast(void*)resp.key);
                    },
                    (immutable(DARTFile.Recorder) recorder){ //TODO: change to HiRPC
                        writeln("DS: received recorder");
                        connectionPool.broadcast(recorder.toHiBON.serialize); //+save to journal etc..
                        // if not ready/started => send error
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
        }
        writeln("DS: handling over");
    }catch(Exception e){
        writefln("EXCEPTION: %s", e);
    }
}