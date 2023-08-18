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
import tagion.basic.Types : Buffer;
import tagion.hashgraph.Refinement;
import tagion.gossip.InterfaceNet : GossipNet;
import tagion.gossip.EmulatorGossipNet;
import tagion.utils.Queue;
import tagion.utils.Random;

// core
import core.time;

// std
import std.algorithm : each;
import std.typecons : No;

// alias ContractSignedConsensus = Msg!"ContractSignedConsensus";
alias Payload = Msg!"Payload";
alias ReceivedWavefront = Msg!"ReceivedWavefront";

alias PayloadQueue = Queue!Document;

@safe:

enum NetworkMode {
    internal,
    local,
    pub
}

struct EpochCreatorOptions {

    uint timeout; // timeout between nodes in milliseconds;
    ushort nodes;
    uint scrap_depth;
    mixin JSONCommon;
}

struct EpochCreatorService {

    void task(immutable(EpochCreatorOptions) opts, immutable(SecureNet) net, immutable(Pubkey[]) pkeys) {
        const hirpc = HiRPC(net);

        GossipNet gossip_net;
        gossip_net = new EmulatorGossipNet(net.pubkey, opts.timeout.msecs);
        pkeys.each!(p => gossip_net.add_channel(p));

        auto refinement = new StdRefinement;

        HashGraph hashgraph = new HashGraph(opts.nodes, net, refinement, &gossip_net.isValidChannel, No.joining);
        hashgraph.scrap_depth = opts.scrap_depth;

        PayloadQueue payload_queue = new PayloadQueue();

        {
            immutable buf = cast(Buffer) hashgraph.channel;
            const nonce = cast(Buffer) net.calcHash(buf);
            auto eva_event = hashgraph.createEvaEvent(gossip_net.time, nonce);
        }

        gossip_net.start_listening();

        const(Document) payload() {
            if (!hashgraph.active || payload_queue.empty) {
                return Document();
            }
            return payload_queue.read;
        }

        void receivePayload(Payload, Document pload) {
            payload_queue.write(pload);
        }


        void receiveWavefront(ReceivedWavefront, Document wave_doc) {
            const receiver = HiRPC.Receiver(wave_doc);
            hashgraph.wavefront(
                    receiver,
                    gossip_net.time,
                    (const(HiRPC.Sender) return_wavefront) { gossip_net.send(receiver.pubkey, return_wavefront); },
                    &payload);
        }

        Random!size_t random;
        random.seed(123456789);
        void timeout() {
           const init_tide = random.value(0,2) is 1;
            if (!init_tide) { return; }
            hashgraph.init_tide(&gossip_net.gossip, &payload, gossip_net.time); 
        }

        runTimeout(opts.timeout.msecs, &timeout, &receivePayload, &receiveWavefront);

    }

}
