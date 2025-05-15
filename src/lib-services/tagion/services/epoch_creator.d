/// Service for creating epochs
/// https://docs.tagion.org/tech/architecture/EpochCreator
module tagion.services.epoch_creator;

import core.time;

import std.array;
import std.algorithm;
import std.exception : RangePrimitive, handle;
import std.stdio;
import std.typecons : No;
import std.path : setExtension;

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
import tagion.hashgraph.RefinementInterface : PayloadQueue;
import tagion.hibon.Document;
import tagion.hibon.HiBONException;
import tagion.hibon.HiBONJSON;
import tagion.hashgraph.HashGraphBasic;
import tagion.hashgraph.Event;
import tagion.logger.Logger;
import tagion.services.messages;
import tagion.services.options : NetworkMode, TaskNames;
import tagion.json.JSONRecord;
import tagion.utils.Queue;
import tagion.utils.Random;
import tagion.utils.StdTime;
import tagion.utils.pretend_safe_concurrency;
import tagion.monitor.Monitor;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.script.common : SignedContract;

@safe
struct EpochCreatorOptions {
    uint timeout = 250; // timeout in msecs 
    uint scrap_depth = 10;
    mixin JSONRecord;
}

@safe
struct EpochCreatorService {

    void task(immutable(EpochCreatorOptions) opts,
            immutable(NetworkMode) network_mode,
            uint number_of_nodes,
            shared(SecureNet) shared_net,
            shared(AddressBook) addressbook,
            immutable(TaskNames) task_names) {

        const net = shared_net.clone;
        ActorHandle collector_handle = ActorHandle(task_names.collector);

        /// Setup EventView callbacks for visualizing the graph
        Event.callbacks = new LogMonitorCallbacks(number_of_nodes, addressbook.keys);
        version (BDD) {
            Event.callbacks = new FileMonitorCallbacks(
                    thisActor.task_name ~ "_graph".setExtension(FileExtension.hibon), number_of_nodes, addressbook.keys
            );
        }

        StdGossipNet gossip_net = new NodeGossipNet(opts.timeout, ActorHandle(task_names.node_interface), addressbook);

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

        refinement.queue = new PayloadQueue();

        int counter = 0;
        Document payload() {
            if (counter > 0) {
                log.trace("Payloads in queue=%d", counter);
            }
            if (refinement.queue.empty) {
                return Document();
            }
            counter--;
            return refinement.queue.read;
        }

        // Receive contracts from the TVM
        void receivePayload(Payload, Document pload) {
            pragma(msg, "fixme(cbr): Should we not just send the payload directly to the hashgraph");
            refinement.queue.write(pload);
            counter++;
        }

        HiRPC hirpc = HiRPC(net);

        void receiveWavefront_req(WavefrontReq req, Document wave_doc) {
            const receiver = hirpc.receive(wave_doc);
            try {
                if (receiver.isError) {
                    return;
                }

                const received_wave = (receiver.isMethod)
                    ? receiver.params!Wavefront(net) : receiver.result!Wavefront(net);

                debug (epoch_creator)
                    log("<- %s", received_wave.state);

                // Filter out all signed contracts from the wavefront
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
                    collector_handle.send(consensusContract(), received_signed_contracts);
                }

                const return_wavefront = hashgraph.wavefront_response(receiver, currentTime, payload);

                if (receiver.isMethod) {
                    gossip_net.send(req, cast(Pubkey) receiver.pubkey, return_wavefront);
                }
            }
            catch (Exception e) {
                log.fatal(e);
                if (!receiver.isinit && receiver.isMethod) {
                    const err_rpc = hirpc.error(receiver, "internal");
                    gossip_net.send(req, cast(Pubkey) receiver.pubkey, err_rpc);
                }
            }
        }

        void receiveWavefront_req_mirror(WavefrontReq req, Document wave_doc) {
            const receiver = HiRPC.Receiver(wave_doc);
            if (receiver.isError) {
                return;
            }

            debug (epoch_creator) {
                const received_wave = (receiver.isMethod)
                    ? receiver.params!Wavefront(net) : receiver.result!Wavefront(net);
                log("<- %s", received_wave.state);
            }

            const return_wavefront = hashgraph.mirror_wavefront_response(receiver, currentTime);

            if (receiver.isMethod) {
                gossip_net.send(req, cast(Pubkey) receiver.pubkey, return_wavefront);
            }
        }

        void timeout() {
            const init_tide = random.value(0, 2) is 1;
            if (init_tide) {
                const sender = hashgraph.create_init_tide(payload, gossip_net.time);
                gossip_net.send(hashgraph.select_channel, sender);
            }
        }

        final switch (network_mode) {
        case NetworkMode.INTERNAL,
            NetworkMode.LOCAL:

            immutable buf = cast(Buffer) hashgraph.channel;
            const nonce = cast(Buffer) net.hash.calc(buf);
            hashgraph.createEvaEvent(gossip_net.time, nonce);

            while (!thisActor.stop && !hashgraph.areWeInGraph) {
                const received = receiveTimeout(
                        opts.timeout.msecs,
                        &signal,
                        &ownerTerminated,
                        &receiveWavefront_req,
                        &unknown
                );
                if (!received) {
                    timeout();
                }
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
            break;

        case NetworkMode.MIRROR:

            hashgraph.mirror_mode = true;
            runTimeout(opts.timeout.msecs, &timeout, &receiveWavefront_req_mirror);
            break;
        }
    }

}
