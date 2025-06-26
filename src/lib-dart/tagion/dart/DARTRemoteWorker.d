module tagion.dart.DARTRemoteWorker;

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
import tagion.services.DARTSynchronization : DARTSyncOptions, RemoteRequestSender, SockAddresses;
import tagion.actor.actor;
import tagion.services.messages;
import tagion.utils.pretend_safe_concurrency : receiveOnly;
import tagion.crypto.Types;

/**
 * Remote synchronizer for DARTs.
 */
@safe
class DARTRemoteWorker : JournalSynchronizer {
    protected DART destination;
    string sock_addr;
    immutable(DARTSyncOptions) opts;

    this(immutable(DARTSyncOptions) opts, string sock_addr, DART destination) {
        this.opts = opts;
        this.sock_addr = sock_addr;
        this.destination = destination;
        File dummy;
        super(dummy);
    }

    /**
     * Query the remote DART for a response to a request.
     * Params:
     *   request = The request to send.
     * Returns: The response from the remote DART.
     */
    const(HiRPC.Receiver) query(ref const(HiRPC.Sender) request)
    in (journalfile !is File.init)
    do {
        RemoteRequestSender sender = new RemoteRequestSender(opts.socket_attempts_mil,
            opts.socket_timeout_mil, sock_addr, fiber); 
        const response_doc = sender.send(request.toDoc);
        const received = destination.hirpc.receive(response_doc);
        return received;
    }

    /**
     * Update the journal file for this synchronizer.
     * Params:
     *   newJournalFile = The new journal file to use.
     */
    void updateJournalFile(File newJournalFile) {
        check(!_finished, "Cannot update the journal file after the synchronizer has finished.");
        _finished = false;

        // Close the current journal file before switching
        if (journalfile !is File.init && journalfile.isOpen) {
            journalfile.close;
        }

        // Update to the new journal file
        journalfile = newJournalFile;
    }

    bool fiber_empty() {
        return fiber.empty;
    }

    override void finish() {
        journalfile.close;
        super.finish;
        _finished = true;
        journalfile = File.init;
    }

}

/**
 * Remote synchronizer for DARTs.
 */
@safe
class DARTSynchronizer : JournalSynchronizer { // Fiber
    protected DART destination;
    Pubkey addr_pub_key;
    ActorHandle node_interface_handle;

    this(Pubkey addr_pub_key, ActorHandle node_interface_handle, DART destination) {
        this.addr_pub_key = addr_pub_key;
        this.destination = destination;
        this.node_interface_handle = node_interface_handle;
        File dummy;
        super(dummy);
    }

    /**
     * Query the remote DART for a response to a request.
     * Params:
     *   request = The request to send.
     * Returns: The response from the remote DART.
     */
    const(HiRPC.Receiver) query(ref const(HiRPC.Sender) request)
    in (journalfile !is File.init)
    do {
        node_interface_handle.send(NodeReq(), addr_pub_key, request.toDoc);
        const sender_response_doc = receiveOnly!(NodeReq.Response, Document)[1];
        const received = destination.hirpc.receive(sender_response_doc);
        return received;
    }

    /**
     * Update the journal file for this synchronizer.
     * Params:
     *   newJournalFile = The new journal file to use.
     */
    void updateJournalFile(File newJournalFile) {
        check(!_finished, "Cannot update the journal file after the synchronizer has finished.");
        _finished = false;

        // Close the current journal file before switching
        if (journalfile !is File.init && journalfile.isOpen) {
            journalfile.close;
        }

        // Update to the new journal file
        journalfile = newJournalFile;
    }

    bool fiber_empty() {
        return fiber.empty;
    }

    override void finish() {
        journalfile.close;
        super.finish;
        _finished = true;
        journalfile = File.init;
    }

}


