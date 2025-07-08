module tagion.dart.DARTFileSynchronizer;

import core.time : MonoTime;
import std.exception;
import std.format;
import std.stdio;
import std.range;
import tagion.dart.synchronizer;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.Recorder;
import tagion.dart.DARTSynchronizationFiber;
import tagion.hibon.Document;
import tagion.hibon.HiBONFile : fwrite;
import tagion.services.messages;
import tagion.services.options : TaskNames;
import tagion.actor.actor;
import tagion.utils.pretend_safe_concurrency : receiveOnly;
import tagion.crypto.Types;
import tagion.communication.HiRPC;

/**
 * DART file synchronizer.
 */
@safe
class DARTFileSynchronizer : StdSynchronizer {
    protected {
        DART owner;
        Pubkey addr_pub_key;
        File journalfile;
    }
    immutable(TaskNames) task_names;

    this(
        DART owner,
        Pubkey addr_pub_key,
        immutable(TaskNames) task_names) {
        this.owner = owner;
        this.addr_pub_key = addr_pub_key;
        this.task_names = task_names;
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
        ActorHandle node_interface_handle = ActorHandle(task_names.node_interface);
        node_interface_handle.send(NodeReq(), addr_pub_key, request.toDoc);
        const sender_response_doc = receiveOnly!(NodeReq.Response, Document)[1];
        const received = owner.hirpc.receive(sender_response_doc);
        return received;
    }

    /**
     * Update the journal file for this synchronizer.
     * Params:
     *   newJournalFile = The new journal file to use.
     */
    void updateJournalFile(File newJournalFile) {
        // check(!_finished, "Cannot update the journal file after the synchronizer has finished.");
        _finished = false;

        // Close the current journal file before switching
        if (journalfile !is File.init && journalfile.isOpen) {
            journalfile.close;
        }

        // Update to the new journal file
        journalfile = newJournalFile;
    }

    /** 
     * Update and adds the recorder to the journal and store it
     * Params:
     *   recorder = DART recorder
     */
    void record(const RecordFactory.Recorder recorder) @safe {
        if (!recorder.empty) {
            journalfile.fwrite(recorder);
        }
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

    override void set(
        DARTSynchronizationFiber fiber,
    ) nothrow @trusted {
        super.fiber = fiber;
        super.owner = owner;
    }

    override HiRPC hirpc() {
        return owner.hirpc;
    }

    /** 
     * Wrapper: Loads the branches from the DART at rim_path
     */
    override DARTFile.Branches branches(const(ubyte[]) rim_path, scope Index* branch_index = null) {
        return owner.branches(rim_path);
    }

    /**
     * Wrapper: Creates a recorder factor  
     */
    override RecordFactory.Recorder recorder() nothrow {
        return owner.recorder;
    }

    /**
     * Wrapper: Creates a recorder factor from a document  
     */
    override RecordFactory.Recorder recorder(const(Document) doc) {
        return owner.recorder(doc);
    }

    /** 
     * Wrapper: Reads the data at branch key  
     */
    override Document load(ref const(DARTFile.Branches) b, const uint key) {
        return owner.load(b, key);
    }
}
