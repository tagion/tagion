/// Module for handling callbacks from the hashgraph
module tagion.hashgraph.Refinement;

import tagion.hashgraph.RefinementInterface;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.utils.BitMask;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.HashGraphBasic;
import tagion.utils.StdTime;

// std
import std.stdio;

class StdRefinement : Refinement {

    bool valid_channel(const Pubkey channel) {
        writefln("%s", __FUNCTION__);
        return true;
    }

    void epoch_callback(const(Event[]) events, const sdt_t epoch_time) {
        writefln("%s", __FUNCTION__);
    }

    void excluded_nodes_callback(ref BitMask mask, const(HashGraph) hashgraph) {
        writefln("%s", __FUNCTION__);
    }

    void epack_callback(immutable(EventPackage*) epack) {
        writefln("%s", __FUNCTION__);
    }


}

