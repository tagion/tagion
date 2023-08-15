/// module for the refinement interface for the hashgraph
module tagion.hashgraph.RefinementInterface;

import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.utils.BitMask;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Round;
import tagion.hashgraph.HashGraphBasic;
import tagion.utils.StdTime;
@safe
interface Refinement {

    void setOwner(HashGraph hashgraph);

    /// called when the epoch is final
    void finishedEpoch(const(Event[]) events, const sdt_t epoch_time, const Round decided_round);

    void excludedNodes(ref BitMask mask);

    void epack(immutable(EventPackage*) epack);

    void epoch(Event[] events, const(Round) decided_round);

}
