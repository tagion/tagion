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

    bool valid_channel(const Pubkey channel);

    void epochCallback(const(Event[]) events, const sdt_t epoch_time);

    void excludedNodesCallback(ref BitMask mask);

    void epackCallback(immutable(EventPackage*) epack);



}