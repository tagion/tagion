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
import tagion.crypto.random.random;
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
import tagion.utils.StdTime;

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

    void task(immutable(EpochCreatorOptions) opts, immutable(NetworkMode) network_mode, immutable(size_t) number_of_nodes, shared(StdSecureNet) shared_net, immutable(MonitorOptions) monitor_opts, immutable(TaskNames) task_names) {

        const net = new StdSecureNet(shared_net);

        
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
        Random!size_t random;
        const _seed = getRandom!size_t;
        random.seed(_seed);

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
            if (payload_queue.empty) {
                return Document();
            }
            return payload_queue.read;
        }

        void receivePayload(Payload, const(Document) pload) {
            log.trace("Received Payload %s", pload.toPretty);
            payload_queue.write(pload);
            // hashgraph.init_tide(&gossip_net.gossip, &payload, currentTime);
        }

        void receiveWavefront(ReceivedWavefront, const(Document) wave_doc) {
            import tagion.hashgraph.HashGraphBasic;
            import tagion.hibon.HiBONRecord : isRecord;
            import tagion.script.common : SignedContract;
            import std.array;

            version (EPOCH_LOG) {
                log.trace("Received wavefront %s");
            }

            const receiver = HiRPC.Receiver(wave_doc);

            const received_wave = receiver.params!(Wavefront)(net);

            immutable received_signed_contracts = received_wave.epacks
                .map!(e => e.event_body.payload)
                .filter!((p) => !p.empty)
                .filter!(p => p.isRecord!SignedContract)
                .map!(s => (() @trusted => cast(immutable) new SignedContract(s))())
                .array;

            if (received_signed_contracts.length != 0) {
                // log("would have send to collector %s", received_signed_contracts.map!(s => (*s).toPretty));
                locate(task_names.collector).send(consensusContract(), received_signed_contracts);
            }
            hashgraph.wavefront(
                    receiver,
                    currentTime,
                    (const(HiRPC.Sender) return_wavefront) { gossip_net.send(receiver.pubkey, return_wavefront); },
                    &payload);
        }

        void timeout() {
            const init_tide = random.value(0, 2) is 1;
            if (!init_tide) {
                return;
            }
            hashgraph.init_tide(&gossip_net.gossip, &payload, currentTime);
        }

        runTimeout(opts.timeout.msecs, &timeout, &receivePayload, &receiveWavefront);
    }

}
