module tagion.dart.synchronizer;


import tagion.communication.HiRPC;

alias HiRPCSender = HiRPC.Sender;
alias HiRPCReceiver = HiRPC.Receiver;
import tagion.dart.DARTFile;
import tagion.dart.Recorder;
import tagion.dart.DART;

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
        * This function is call when hole branches doesn't exist in the foreign DART
        * and need to be removed in the local DART
        * Params:
        *   rims = path to the selected rim
        */
    void remove_recursive(const DART.Rims rims);
    /**
        * This function is called when the SynchronizationFiber run function finishes
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
