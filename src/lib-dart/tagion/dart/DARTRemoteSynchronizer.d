module tagion.dart.DARTRemoteSynchronizer;

import tagion.dart.synchronizer;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.communication.HiRPC;
import nngd;
import std.exception;
import core.time;
import tagion.hibon.Document;
import std.format;
import std.stdio;
import std.range;
import core.time : MonoTime;
import tagion.services.DARTSynchronization : DARTSyncOptions, RemoteRequestSender;

@safe
class DARTRemoteSynchronizer : JournalSynchronizer {
    protected DART destination;
    protected DARTSyncOptions opts;
    
    this(immutable(DARTSyncOptions) opts, DART destination, File journalFile){
        this.opts = opts;
        this.destination = destination;
        super(journalFile);
    }

    const(HiRPC.Receiver) query(ref const(HiRPC.Sender) request) {
        RemoteRequestSender sender = new RemoteRequestSender(opts, fiber);
        const response_doc = sender.send(request.toDoc);
        const received = destination.hirpc.receive(response_doc);
        return received;
    }

    override void finish() {
        _finished = true;
    }
}
