// Service for creating epochs
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
import tagion.utils.pretend_safe_concurrency;
import tagion.utils.Miscellaneous : cutHex;
import tagion.gossip.AddressBook;
import tagion.hibon.HiBONJSON;
import tagion.utils.Miscellaneous : cutHex;
import tagion.services.messages;
import tagion.services.monitor;
import tagion.services.options : TaskNames, NetworkMode;

// core
import core.time;

// std
import std.algorithm;
import std.typecons : No;
import std.stdio;

alias PayloadQueue = Queue!Document;

@safe
struct EpochCreatorOptions {
    uint timeout = 15; // timeout in msecs 
    uint scrap_depth = 5;
    mixin JSONCommon;
}

@safe
struct EpochCreatorService {

    void task(immutable(EpochCreatorOptions) opts, immutable(NetworkMode) network_mode, immutable(size_t) number_of_nodes, immutable(
            SecureNet) net, immutable(MonitorOptions) monitor_opts, immutable(TaskNames) task_names) {

        assert(network_mode == NetworkMode.INTERNAL, "Unsupported network mode");

        if (monitor_opts.enable) {
            import tagion.monitor.Monitor : MonitorCallBacks;
            import tagion.hashgraph.Event : Event;

            auto monitor_socket_tid = spawn(&monitorServiceTask, monitor_opts);
            Event.callbacks = new MonitorCallBacks(
                    monitor_socket_tid, monitor_opts.dataformat);

            assert(receiveOnly!Ctrl is Ctrl.ALIVE);
        }

        const hirpc = HiRPC(net);

        GossipNet gossip_net;
        gossip_net = new NewEmulatorGossipNet(net.pubkey, opts.timeout.msecs);
        Pubkey[] channels = addressbook.activeNodeChannels;

        foreach (channel; channels) {
            gossip_net.add_channel(channel);
        }
        log.trace("Beginning gossip");

        auto refinement = new StdRefinement;
        refinement.setTasknames(task_names);

        HashGraph hashgraph = new HashGraph(number_of_nodes, net, refinement, &gossip_net.isValidChannel, No.joining);
        hashgraph.scrap_depth = opts.scrap_depth;

        PayloadQueue payload_queue = new PayloadQueue();
        {
            immutable buf = cast(Buffer) hashgraph.channel;
            const nonce = cast(Buffer) net.calcHash(buf);
            auto eva_event = hashgraph.createEvaEvent(gossip_net.time, nonce);
        }

        const(Document) payload() {
            if (!hashgraph.active || payload_queue.empty) {
                return Document();
            }
            return payload_queue.read;
        }

        void receivePayload(Payload, const(Document) pload) {
            log.trace("Received Payload %s", pload.toPretty);
            payload_queue.write(pload);
        }

        void receiveWavefront(ReceivedWavefront, const(Document) wave_doc) {
            version (EPOCH_LOG) {
                log.trace("Received wavefront");
            }
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
            const init_tide = random.value(0, 2) is 1;
            if (!init_tide) {
                return;
            }
            hashgraph.init_tide(&gossip_net.gossip, &payload, gossip_net.time);
        }

        runTimeout(opts.timeout.msecs, &timeout, &receivePayload, &receiveWavefront);
    }

}
