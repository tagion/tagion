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

@safe
class StdRefinement : Refinement {
    protected {
        HashGraph hashgraph;
    }


    void setOwner(HashGraph hashgraph) 
    in (this.hashgraph is null) 
    do
    {
        this.hashgraph = hashgraph;
    }

    void epoch(const(Event[]) events, const sdt_t epoch_time) {
        assert(0, "not implemented");
    }

    void excludedNodes(ref BitMask excluded_mask) {
        // should be implemented
    }


    void epack(immutable(EventPackage*) epack) @safe {
        // log.trace("epack.event_body.payload.empty %s", epack.event_body.payload.empty);
    }

}

