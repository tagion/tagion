// Service for creating epochs
/// [Documentation](https://docs.tagion.org/#/documents/architecture/EpochCreator)
module tagion.services.epoch_creator;

// tagion
import tagion.actor;
import tagion.basic.Types;
import tagion.basic.basic : isinit;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.Types : Pubkey;
import tagion.crypto.random.random;
import tagion.gossip.AddressBook;
import tagion.gossip.EmulatorGossipNet;
import tagion.gossip.NNGGossipNet;
import tagion.gossip.GossipNet;
import tagion.gossip.InterfaceNet : GossipNet;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Refinement;
import tagion.hibon.Document;
import tagion.hibon.HiBONException;
import tagion.hibon.HiBONJSON;
import tagion.logger.Logger;
import tagion.services.messages;
import tagion.services.monitor;
import tagion.services.options : NetworkMode, TaskNames;
import tagion.utils.JSONCommon;
import tagion.utils.Queue;
import tagion.utils.Random;
import tagion.utils.StdTime;
import tagion.utils.pretend_safe_concurrency;

// core
import core.time;

// std
import std.algorithm;
import std.exception : RangePrimitive, handle;
import std.stdio;
import std.typecons : No;

alias PayloadQueue = Queue!Document;

@safe
struct EpochCreatorOptions {
    uint timeout = 250; // timeout in msecs 
    uint scrap_depth = 10;
    mixin JSONCommon;
}

@safe
struct EpochCreatorService {

    void task(immutable(EpochCreatorOptions) opts,
            immutable(NetworkMode) network_mode,
            immutable(size_t) number_of_nodes,
            shared(StdSecureNet) shared_net,
            immutable(MonitorOptions) monitor_opts,
            immutable(TaskNames) task_names) {

        const net = new StdSecureNet(shared_net);

        assert(network_mode < NetworkMode.PUB, "Unsupported network mode");

        import tagion.hashgraph.Event : Event;
        import tagion.monitor.Monitor;
        if (monitor_opts.enable) {
            version(none) {
                auto monitor_socket_tid = spawn(&monitorServiceTask, monitor_opts);
                Event.callbacks = new MonitorCallBacks(monitor_socket_tid, monitor_opts.dataformat);
                if (!waitforChildren(Ctrl.ALIVE)) {
                    log.warn("Monitor never started, continuing anyway");
                }
            }
            else {
            Event.callbacks = new LogMonitorCallBacks();
            }
        }


        GossipNet gossip_net;

        final switch (network_mode) {
        case NetworkMode.INTERNAL:
            gossip_net = new EmulatorGossipNet(net.pubkey, opts.timeout.msecs);
            break;
        case NetworkMode.LOCAL:
            gossip_net = new NNGGossipNet(net.pubkey, ActorHandle(task_names.node_interface), opts.timeout.msecs);
            break;
        case NetworkMode.PUB:
            assert(0);
        }

        Pubkey[] channels = addressbook.keys;
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
            hashgraph.createEvaEvent(gossip_net.time, nonce);
        }

        int counter = 0;
        const(Document) payload() {
            if (counter > 0) {
                log.trace("Payloads in queue=%d", counter);
            }
            if (payload_queue.empty) {
                return Document();
            }
            counter--;
            return payload_queue.read;
        }

        void receivePayload(Payload, const(Document) pload) {
            payload_queue.write(pload);
            counter++;
        }

        void receiveWavefront(ReceivedWavefront, const(Document) wave_doc) {
            import std.array;
            import tagion.hashgraph.HashGraphBasic;
            import tagion.hibon.HiBONRecord : isRecord;
            import tagion.script.common : SignedContract;

            version (EPOCH_LOG) {
                log.trace("Received wavefront");
            }

            const receiver = HiRPC.Receiver(wave_doc);

            const received_wave = receiver.params!(Wavefront)(net);

            immutable received_signed_contracts = received_wave.epacks
                .map!(e => e.event_body.payload)
                .filter!((p) => !p.empty)
                .filter!(p => p.isRecord!SignedContract) // Cannot explicitly return immutable container type (*) ?, need assign to immutable container
                .map!((doc) { immutable s = new immutable(SignedContract)(doc); return s; })
                .handle!(HiBONException, RangePrimitive.front,
                        (e, r) { log("invalid SignedContract from hashgraph"); return null; }
            )
                .filter!(s => !s.isinit)
                .array;

            if (received_signed_contracts.length != 0) {
                // log("would have send to collector %s", received_signed_contracts.map!(s => (*s).toPretty));
                locate(task_names.collector).send(consensusContract(), received_signed_contracts);
            }
            scope (failure) {
                log.fatal("WAVEFRONT\n%s\n", receiver.toPretty);
            }
            hashgraph.wavefront(
                    receiver,
                    currentTime,
                    (const(HiRPC.Sender) return_wavefront) { gossip_net.send(receiver.pubkey, return_wavefront); },
                    &payload);
        }

        /// Receive external payloads from the nodeinterface
        void node_receive(NodeRecv, Document doc) {
            // TODOr: Check that it's valid Receiver
            /* log("received payload %s bytes", doc.data.length); */
            receiveWavefront(ReceivedWavefront(), doc);
        }


        void timeout() {
            const init_tide = random.value(0, 2) is 1;
            if (!init_tide) {
                return;
            }
            hashgraph.init_tide(&gossip_net.gossip, &payload, currentTime);
        }

        while (!thisActor.stop && !hashgraph.areWeInGraph) {
            const received = receiveTimeout(
                    opts.timeout.msecs,
                    &signal,
                    &ownerTerminated,
                    &node_receive,
                    &receiveWavefront,
                    &unknown
            );
            if (received) {
                continue;
            }
            timeout();
        }

        if (thisActor.stop) {
            return;
        }
        Topic inGraph = Topic("in_graph");
        log.event(inGraph, __FUNCTION__, Document());
        runTimeout(opts.timeout.msecs, &timeout, &receivePayload, &node_receive, &receiveWavefront);
    }

}
