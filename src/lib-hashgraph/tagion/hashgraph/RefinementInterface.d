/// module for the refinement interface for the hashgraph
module tagion.hashgraph.RefinementInterface;

import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Round;
import tagion.services.options : TaskNames;
import tagion.utils.BitMask;
import tagion.utils.StdTime;

@safe
interface Refinement {

    void setOwner(HashGraph hashgraph);

    void setTasknames(TaskNames task_names);

    /// called when the epoch is final
    void finishedEpoch(const(Event[]) events, const sdt_t epoch_time, const Round decided_round);

    void excludedNodes(ref BitMask mask);

    void epack(immutable(EventPackage*) epack);

    void epoch(Event[] events, const(Round) decided_round);

    void payload(immutable(EventPackage*) epack);

    version(NEW_ORDERING)
    bool order_less(Event a, Event b, Event[] famous_witnesses);

    version(OLD_ORDERING)
    bool order_less(const Event a, const Event b, const(int) order_count) pure;
    
}
