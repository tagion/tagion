/// module for the refinement interface for the hashgraph
module tagion.hashgraph.RefinementInterface;

import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.utils.BitMask;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.utils.StdTime;

@safe
interface Refinement {

    void setOwner(HashGraph hashgraph);

    void epoch(const(Event[]) events, const sdt_t epoch_time);

    void excludedNodes(ref BitMask mask);

    void epack(immutable(EventPackage*) epack);



}