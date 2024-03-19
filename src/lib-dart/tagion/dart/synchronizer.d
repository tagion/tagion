module tagion.dart.synchronizer;

import tagion.communication.HiRPC;

alias HiRPCSender = HiRPC.Sender;
alias HiRPCReceiver = HiRPC.Receiver;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.DARTRim;
import tagion.dart.Recorder;
import tagion.hibon.Document;

/**
* Interface to the DART synchronizer
*/
@safe
interface Synchronizer {
    /**
        * Recommend to put a yield the SynchronizationFiber between send and receive between the DART's
        */
    const(HiRPC.Receiver) query(ref const(HiRPC.Sender) request);
    /**
        * Stores the add and remove actions in the journal replay log file
        * 
        * Params:
        *   recorder = DART recorder
        */
    void record(RecordFactory.Recorder recorder);
    /**
        * This function is called when whole branches doesn't exist in the foreign DART
        * and need to be removed in the local DART
        * Params:
        *   rims = path to the selected rim
        */
    void removeRecursive(const Rims rims);
    /**
        * This function is called when the SynchronizationFiber run-function finishes
        */
    void finish();
    /**
        * Called in by the SynchronizationFiber constructor
        * which enable the query function to yield the run function in SynchronizationFiber
        *
        * Params:
        *     owner = is the dart to be modified
        *     fiber = is the synchronizer fiber object
        */
    void set(DART owner, DART.SynchronizationFiber fiber, HiRPC hirpc);
    /**
        * Checks if the syncronizer is empty
        * Returns:
        *     If the SynchronizationFiber has finished then this function returns `true`
        */
    bool empty() const pure nothrow;
}

/**
    *  Standards DART Synchronization object
    */
@safe
abstract class StdSynchronizer : Synchronizer {

    protected DART.SynchronizationFiber fiber; /// Contains the reference to SynchronizationFiber
    immutable uint chunk_size; /// Max number of archives operates in one recorder action
    protected {
        //        BlockFile journalfile; /// The actives is stored in this journal file. Which late can be run via the replay function
        bool _finished; /// Finish flag set when the Fiber function returns
        bool _timeout; /// Set via the timeout method to indicate and network timeout
        DART owner;
        //        Index index; /// Current block index
        HiRPC hirpc;
    }
    this(const uint chunk_size = 0x400) {
        this.chunk_size = chunk_size;
    }

    /** 
        * Remove all archive at selected rim path
        * Params:
        *   selected_rims = selected rims to be removed
        */
    void removeRecursive(const Rims selected_rims) {

        auto rim_walker = owner.rimWalkerRange(selected_rims.path);
        uint count = 0;
        auto recorder_worker = owner.recorder;
        foreach (archive_data; rim_walker) {
            const archive_doc = Document(archive_data);
            assert(!archive_doc.empty, "archive should not be empty");
            recorder_worker.remove(archive_doc);
            count++;
            if (count > chunk_size) {
                record(recorder_worker);
                count = 0;
                recorder_worker.clear;
            }
        }
        record(recorder_worker);
    }

    /** 
        * Should be called when the synchronization has finished
        */
    void finish() {
        _finished = true;
    }

    /**
        * 
        * Params:
        *   owner = DART to be synchronized
        *   fiber = syncronizer fiber
        *   hirpc = remote credential used 
        */
    void set(
            DART owner,
            DART.SynchronizationFiber fiber,
            HiRPC hirpc) nothrow @trusted {
        import std.conv : emplace;

        this.fiber = fiber;
        this.owner = owner;
        emplace(&this.hirpc, hirpc);
    }

    /**
        * Should be call on timeout timeout
        */
    void timeout() {
        //  journalfile.close;
        _timeout = true;
    }

    /**
        * Checks if synchronization has ended
        * Returns: true on empty
        */
    bool empty() const pure nothrow {
        return (_finished || _timeout);
    }
    /* 
        * Check the synchronization timeout
        * Returns: true on timeout
        */
    bool timeout() const pure nothrow {
        return _timeout;
    }
}

@safe
class JournalSynchronizer : StdSynchronizer {
    protected {
        BlockFile journalfile; /// The actives is stored in this journal file. Which later can be run via the replay function
        Index index; /// Current block index
    }
    this(BlockFile journalfile, const uint chunk_size = 0x400) {
        this.journalfile = journalfile;
        super(chunk_size);
    }

    /** 
        * Update and adds the recorder to the journal and store it
        * Params:
        *   recorder = DART recorder
        */
    void record(const RecordFactory.Recorder recorder) @safe {
        if (!recorder.empty) {
            const journal = const(DART.Journal)(recorder, index);
            const allocated = journalfile.save(journal.toDoc);
            index = Index(allocated.index);
            journalfile.root_index = index;
            scope (exit) {
                journalfile.store;
            }
        }
    }
    /** 
        * Should be called when the synchronization has finished
        */
    override void finish() {
        journalfile.close;
        super.finish;
        _finished = true;
    }

}
