module tagion.dart.DARTRemoteSynchronizer;

import core.time : MonoTime;
import core.thread.fiber;
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
import tagion.dart.DARTRim;
import tagion.dart.DARTBasic : dartIndex;
import tagion.hibon.Document;
import tagion.hibon.HiBONFile : fwrite;
import tagion.services.messages;
import tagion.services.options : TaskNames;
import tagion.actor.actor;
import tagion.utils.pretend_safe_concurrency : receiveOnly;
import tagion.crypto.Types;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.communication.HiRPC;

/**
 * Remote DART synchronizer.
 */
@safe
class DARTRemoteSynchronizer : Synchronizer {
    version (DEDICATED_DART_SYNC_FIBER) {
        protected DARTSynchronizationFiber fiber; /// Contains the reference to a dedicated DARTSynchronizationFiber
    }
    else {
        protected DART.SynchronizationFiber fiber; /// Contains the reference to SynchronizationFiber
    }
    protected {
        bool _finished; /// Finish flag set when the Fiber function returns
        bool _timeout; /// Set via the timeout method to indicate and network timeout
        Pubkey addr_pub_key;
        File journalfile;
    }
    immutable uint chunk_size; /// Max number of archives operates in one recorder action
    immutable(TaskNames) task_names;
    ActorHandle dart_handle;
    const HiRPC _hirpc;
    const SecureNet net;

    this(
        Pubkey addr_pub_key,
        immutable(TaskNames) task_names,
        const SecureNet net,
        const uint chunk_size = 0x400) {
        this.addr_pub_key = addr_pub_key;
        this.task_names = task_names;
        this.net = net;
        this.chunk_size = chunk_size;
        dart_handle = ActorHandle(task_names.dart);
        _hirpc = HiRPC(net);
    }

    Fiber.State state() const pure nothrow {
        return fiber.state;
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
        const received = _hirpc.receive(sender_response_doc);
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

    /**
        * Checks if synchronization has ended
        * Returns: true on empty
        */
    bool finished() const pure nothrow {
        return (_finished || _timeout);
    }

    /** 
     * Remove all archive at selected rim path
     * Params:
     *   selected_rims = selected rims to be removed
     */
    override void removeRecursive(const Rims selected_rims) {
        // auto rim_walker = rimWalkerRange(selected_rims.path);
        // uint count = 0;
        // auto recorder_worker = recorder;
        // foreach (archive_data; rim_walker) {
        //     const archive_doc = Document(archive_data);
        //     assert(!archive_doc.empty, "archive should not be empty");
        //     recorder_worker.remove(archive_doc);
        //     count++;
        //     if (count > chunk_size) {
        //         record(recorder_worker);
        //         count = 0;
        //         recorder_worker.clear;
        //     }
        // }
        // record(recorder_worker);
    }

    override void finish() {
        journalfile.close;
        _finished = true;
        journalfile = File.init;
    }

    override void set(
        DARTSynchronizationFiber fiber,
    ) nothrow @trusted {
        this.fiber = fiber;
    }

    void set(
        DART owner,
        DARTSynchronizationFiber fiber,
        HiRPC hirpc) nothrow @trusted {
        // Do nothing
    }

    void set(
        DART owner,
        DART.SynchronizationFiber fiber,
        HiRPC hirpc) nothrow @trusted {
        // Do nothing
    }

    override HiRPC hirpc() {
        return _hirpc;
    }

    /** 
     * Wrapper: Loads the branches from the DART at rim_path
     */
    override DARTFile.Branches branches(immutable(ubyte[]) rim_path, scope Index* branch_index = null) {
        dart_handle.send(dartRimRR(), rim_path);
        immutable rim_doc = receiveOnly!(dartRimRR.Response, Document)[1];
        if (DARTFile.Branches.isRecord(rim_doc)) {
            return DARTFile.Branches(rim_doc);
        }
        return DARTFile.Branches.init;
    }

    /**
     * Wrapper: Creates a recorder factor  
     */
    override RecordFactory.Recorder recorder() {
        dart_handle.send(dartReadRR());
        auto recorder = receiveOnly!(dartReadRR.Response, RecordFactory.Recorder)[1];
        return recorder;
    }

    /**
     * Wrapper: Creates a recorder factor from a document  
     */
    override RecordFactory.Recorder recorder(const(Document) doc) {
        auto dart_index = net.hash.dartIndex(doc);
        dart_handle.send(dartReadRR(), [dart_index]);
        auto recorder = receiveOnly!(dartReadRR.Response, RecordFactory.Recorder)[1];
        return recorder;
    }

    /** 
     * Wrapper: Reads the data at branch key  
     */
    override Document load(ref const(DARTFile.Branches) b, const uint key) {
        // auto dart_index = b.get_dart_index(key);
        immutable dart_index = b.indices[key];

        dart_handle.send(dartReadRR(), [dart_index]);
        auto recorder = receiveOnly!(dartReadRR.Response, immutable(RecordFactory.Recorder))[1];
        if (recorder.empty()) {
            return Document.init;
        }
        return recorder[].front.filed;
    }
}
