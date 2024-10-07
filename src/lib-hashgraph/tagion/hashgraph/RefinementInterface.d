/// module for the refinement interface for the hashgraph
module tagion.hashgraph.RefinementInterface;

import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Round;
import tagion.hibon.Document;
import tagion.services.options : TaskNames;
import tagion.utils.BitMask;
import tagion.utils.StdTime;

import tagion.utils.Queue;

@safe:
alias PayloadQueue = Queue!Document;

interface Refinement {

    void setOwner(HashGraph hashgraph);

    void setTasknames(TaskNames task_names);

    /// called when the epoch is final
    void finishedEpoch(const(Event[]) events, const sdt_t epoch_time, const Round decided_round);

    void excludedNodes(ref BitMask mask);

    void epack(immutable(EventPackage*) epack);

    void epoch(Event[] events, const(Round) decided_round);

    void payload(immutable(EventPackage*) epack);
    /**
     *  
     * Returns: the transmission queue 
     */
    PayloadQueue queue() nothrow;

    /** 
     * 
     * Params:
     *   _queue = the transmission queue used
     */
    void queue(PayloadQueue _queue);

    /**
     * Check if the evenpackage contains a epoch-vote 
     * Params: 
     *   epack = event package to be checked 
     * Returns: true if the epoch was decided
     */

    bool checkEpochVoting(immutable(EventPackage*) epack);

    version (NEW_ORDERING) static bool order_less(Event a, Event b,
            const(Event[]) famous_witnesses,
    const(Round) decided_round) pure;

    version (OLD_ORDERING) static bool order_less(const Event a, const Event b,
            const(int) order_count) pure;

}
