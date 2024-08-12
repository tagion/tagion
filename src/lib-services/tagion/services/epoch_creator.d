/// Service for creating epochs
/// https://docs.tagion.org/docs/architecture/EpochCreator
module tagion.services.epoch_creator;

import core.time;

import std.array;
import std.algorithm;
import std.exception : RangePrimitive, handle;
import std.stdio;
import std.typecons : No;

import tagion.actor;
import tagion.basic.Types;
import tagion.basic.basic : isinit;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.Types : Pubkey;
import tagion.crypto.random.random;
import tagion.gossip.AddressBook;
import tagion.gossip.GossipNet;
import tagion.hashgraph.HashGraph;
import tagion.hashgraph.Refinement;
import tagion.hibon.Document;
import tagion.hibon.HiBONException;
import tagion.hibon.HiBONJSON;
import tagion.hashgraph.HashGraphBasic;
import tagion.logger.Logger;
import tagion.services.messages;
import tagion.services.options : NetworkMode, TaskNames;
import tagion.utils.JSONCommon;
import tagion.utils.Queue;
import tagion.utils.Random;
import tagion.utils.StdTime;
import tagion.utils.pretend_safe_concurrency;
import tagion.monitor.Monitor;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.script.common : SignedContract;

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
            uint number_of_nodes,
            shared(StdSecureNet) shared_net,
            immutable(TaskNames) task_names) {

        const net = new StdSecureNet(shared_net);
        ActorHandle collector_handle = ActorHandle(task_names.collector);

        assert(network_mode < NetworkMode.PUB, "Unsupported network mode");

        import tagion.hashgraph.Event : Event;
        Event.callbacks = new LogMonitorCallbacks();
        version(BDD) {
            Event.callbacks = new FileMonitorCallbacks(thisActor.task_name ~ "_graph.hibon", number_of_nodes, addressbook.keys);
        }

        StdGossipNet gossip_net;

        final switch (network_mode) {
        case NetworkMode.INTERNAL:
            gossip_net = new EmulatorGossipNet(net.pubkey, opts.timeout);
            break;
        case NetworkMode.LOCAL:
            gossip_net = new NNGGossipNet(net.pubkey, opts.timeout, ActorHandle(task_names.node_interface));
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

        HashGraph hashgraph = new HashGraph(number_of_nodes, net, refinement, gossip_net);
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
            pragma(msg, "fixme(cbr): Should we not just send the payload directly to the hashgraph");
            payload_queue.write(pload);
            counter++;
        }

        void receiveWavefront_req(WavefrontReq req, const(Document) wave_doc) {
            const receiver = HiRPC.Receiver(wave_doc);
            if (receiver.isError) {
                return;
            }

            const received_wave = (receiver.isMethod)
                ? receiver.params!Wavefront(net)
                : receiver.result!Wavefront(net);

            debug(epoch_creator) log("<- %s", received_wave.state);

            // Filter out all signed contracts from the payload
            immutable received_signed_contracts = received_wave.epacks
                .map!(e => e.event_body.payload)
                .filter!((p) => !p.empty)
                .filter!(p => p.isRecord!SignedContract)
                // Cannot explicitly return immutable container type (*) ?, need assign to immutable container
                .map!((doc) { immutable s = new immutable(SignedContract)(doc); return s; })
                .handle!(HiBONException, RangePrimitive.front,
                        (e, r) { log("invalid SignedContract from hashgraph"); return null; }
                )
                .filter!(s => !s.isinit)
                .array;

            if (received_signed_contracts.length != 0) {
                collector_handle.send(consensusContract(), received_signed_contracts);
            }

            const return_wavefront = hashgraph.wavefront_response(receiver, currentTime, payload);

            if(receiver.isMethod) {
                gossip_net.send(req, cast(Pubkey)receiver.pubkey, return_wavefront);
                /* locate(req.task_name).send(WavefrontReq(req.id), cast(Pubkey)receiver.pubkey, return_wavefront.toDoc); */
            }
        }

        void timeout() {
            const init_tide = random.value(0, 2) is 1;
            if (init_tide) {
                auto sender = () => hashgraph.create_init_tide(payload, currentTime);
                const _ = gossip_net.gossip(&hashgraph.not_used_channels, sender);
            }
        }

        while (!thisActor.stop && !hashgraph.areWeInGraph) {
            const received = receiveTimeout(
                    opts.timeout.msecs,
                    &signal,
                    &ownerTerminated,
                    &receiveWavefront_req,
                    &unknown
            );
            if (received) {
                continue;
            }
            timeout();
        }

        if (hashgraph.areWeInGraph) {
            log("NODE CAME INTO GRAPH");
        }

        if (thisActor.stop) {
            return;
        }
        Topic inGraph = Topic("in_graph");
        log.event(inGraph, __FUNCTION__, Document());
        runTimeout(opts.timeout.msecs, &timeout, &receivePayload, &receiveWavefront_req);
    }

}
