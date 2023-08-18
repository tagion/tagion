/// Service for creating epochs
/// [Documentation](https://docs.tagion.org/#/documents/architecture/EpochCreator)
module tagion.services.epoch_creator;

// tagion
import tagion.logger.Logger;
import tagion.actor;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.utils.JSONCommon;
import tagion.hashgraph.HashGraph;
import tagion.gossip.GossipNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Refinement;
import tagion.gossip.InterfaceNet : GossipNet;
import tagion.gossip.EmulatorGossipNet;

// core
import core.time;

// std
import std.algorithm : each;
import std.typecons : No;

alias ContractSignedConsensus = Msg!"ContractSignedConsensus";
alias WavefrontGossip = Msg!"WavefrontGossip";

enum NetworkMode {
    internal,
    local,
    pub
}

struct EpochCreatorOptions {

    uint timeout; // timeout between nodes;
    ushort nodes;
    uint scrap_depth;
}

struct EpochCreatorSercive {

    void task(immutable(EpochCreatorOptions) opts, immutable(SecureNet) net, immutable(Pubkey[]) pkeys) {
        const hirpc = HiRPC(net);
        GossipNet gossip_net;
        auto refinement = new StdRefinement;

        gossip_net = new EmulatorGossipNet(net.pubkey, opts.timeout.msecs);
        pkeys.each!(p => gossip_net.add_channel(p));

        HashGraph hashgraph = new HashGraph(opts.nodes, net, refinement, &gossip_net.isValidChannel, No.joining);
        hashgraph.scrap_depth = opts.scrap_depth;

    }

}
