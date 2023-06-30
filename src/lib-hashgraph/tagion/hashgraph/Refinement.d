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

    struct Epoch {
        const(Event)[] events;
        sdt_t epoch_time;
    }

    static Epoch[][Pubkey] epoch_events;
    void epoch(const(Event[]) events, const sdt_t epoch_time) {
        auto epoch = Epoch(events, epoch_time);
        epoch_events[hashgraph.owner_node.channel] ~= epoch;
    }

    Pubkey[int] excluded_nodes_history;
    void excludedNodes(ref BitMask excluded_mask) {
        import tagion.basic.Debug;

        if (excluded_nodes_history is null) { return; }
                
        const last_decided_round = hashgraph.rounds.last_decided_round.number;
        const exclude_channel = excluded_nodes_history.get(last_decided_round, Pubkey.init);
        if (exclude_channel !is Pubkey.init) {
            const node = hashgraph.nodes.get(exclude_channel, HashGraph.Node.init);
            if (node !is HashGraph.Node.init) {
                excluded_mask[node.node_id] = !excluded_mask[node.node_id]; 
            }
        }
        
        // const mask = excluded_nodes_history.get(last_decided_round, );
        // if (mask !is BitMask.init) {
        //     excluded_mask = mask;
        // }

        __write("callback<%s>", excluded_mask);

    }


    void epack(immutable(EventPackage*) epack) @safe {
        // log.trace("epack.event_body.payload.empty %s", epack.event_body.payload.empty);
    }

}

