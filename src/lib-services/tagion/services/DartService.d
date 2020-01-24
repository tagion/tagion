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

enum DartState{
    WAITING = 4,
    READY = 5,
    SYNCHRONIZING = 6
}


void dartServiceTask(immutable(Options) opts, shared(p2plib.Node) node) {
    auto state = ServiceState!DartState(DartState.WAITING); 
    try{
        setOptions(opts);
        immutable task_name=opts.dart.task_name;
        auto pid = opts.dart.protocol_id;
        log.register(task_name);

        log("-----Start Dart service-----");
        scope(success){
            log("------Stop Dart service-----");
            ownerTid.prioritySend(Control.END);
        }

        bool stop = false;
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
        node.listen(pid, &StdHandlerCallback, cast(string) task_name, opts.dart.subs.host.timeout.msecs, cast(uint) opts.dart.subs.host.max_size);
        auto connectionPool = new shared(ConnectionPool!(shared p2plib.Stream, ulong))();
        while(!stop) {
            receive(
                    &handleControl,
                    (Response!(ControlCode.Control_Connected) resp) {    
                        log("DS: Client Connected key: %d", resp.key);
                        connectionPool.add(resp.key, resp.stream);
                    },
                    (Response!(ControlCode.Control_Disconnected) resp) { 
                        log("DS: Client Disconnected key: %d", resp.key);     
                        connectionPool.close(cast(void*)resp.key);
                    },
                    (immutable(DARTFile.Recorder) recorder){ //TODO: change to HiRPC
                        log("DS: received recorder");
                        connectionPool.broadcast(recorder.toHiBON.serialize); //+save to journal etc..
                        // if not ready/started => send error
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
        }
    }catch(Exception e){
        writefln("EXCEPTION: %s", e);
    }
}