/// Interface for the Peer to Peer communication in mode0
/// https://docs.tagion.org/tech/architecture/NodeInterface
module tagion.services.mode0_nodeinterface;

@safe:

import std.algorithm;

import tagion.actor;
import tagion.basic.Types;
import tagion.crypto.Types;
import tagion.gossip.AddressBook;
import tagion.hibon.Document;
import tagion.logger;
import tagion.services.messages;
import tagion.services.tasknames;
import tagion.services.exception;
import tagion.crypto.SecureNet;
import tagion.communication.HiRPC;
import tagion.utils.pretend_safe_concurrency;
import tagion.script.methods;

alias Mode0Send = Msg!"mode0send";

///
struct Mode0NodeInterfaceService {
    const(SecureNet) net;
    const(HiRPC) hirpc;
    ActorHandle epoch_creator_handle;
    TaskNames tn;
    shared(AddressBook) addressbook;

    ///
    this(shared(SecureNet) shared_net, shared(AddressBook) addressbook, TaskNames tn) {
        this.net = shared_net.clone;
        this.hirpc = HiRPC(this.net);
        this.epoch_creator_handle = ActorHandle(tn.epoch_creator);
        this.tn = tn;
        this.addressbook = addressbook;
    }

    // Send a message to another node
    void wave_send(WavefrontReq req, Pubkey channel, Document doc) {
        const nnr = addressbook[channel].get;
        Tid remote_tid = locate(nnr.address);
        if(remote_tid is Tid.init) {
            log.error("Tid node address '%s' is not registered", nnr.address);
            return;
        }
        remote_tid.send(Mode0Send(), doc);
    }

    // Receive a message from another node
    void wave_recv(Mode0Send, Document doc) {
        if (!doc.empty && !doc.isInorder(Document.Reserved.no)) {
            log.error("received document was invalid %s", doc);
            return;
        }
        const hirpcmsg = hirpc.receive(doc);
        if (hirpcmsg.pubkey == this.net.pubkey) {
            log.error("Received hirpc was from yourself replay?\n%s", doc.toPretty);
            return;
        }
        if (!hirpcmsg.isSigned) {
            log.error("Received hirpc was not signed\n%s", doc.toPretty);
            return;
        }
        epoch_creator_handle.send(WavefrontReq(), doc);
    }

    // Send a message to another node and get the dart response back
    void node_send(NodeReq req, Pubkey channel, Document doc) {
        const nnr = addressbook[channel].get;
        Tid node_tid = locate(nnr.address);
        if(node_tid is Tid.init) {
            log.error("Tid node address '%s' is not registered", nnr.address);
            return;
        }
        spawn((NodeReq req, Tid node_tid, Document doc) {
                // Extern nodeinterface
                node_tid.send(req, doc);
                Document response_doc = receiveOnly!(NodeReq.Response, Document)[1];
                req.respond(response_doc);
        }, req, node_tid, doc);
    }

    // Receive a message from another node and forward the request to dart service
    void node_recv(NodeReq req, Document doc) {
        spawn((NodeReq req, TaskNames tn, Document doc) {
            try {
                const receiver = HiRPC(null).receive(doc);
                switch(receiver.method.name) {
                    case RPCMethods.dartRead:
                    case RPCMethods.dartCheckRead:
                    case RPCMethods.dartBullseye:
                    case RPCMethods.dartRim:
                        ActorHandle(tn.dart).send(dartHiRPCRR(), doc);
                        break;
                    case RPCMethods.readRecorder:
                        ActorHandle(tn.replicator).send(readRecorderRR(), doc);
                        break;
                    default:
                        throw new ServiceException("Unknown method");
                }

                receive(
                        (dartHiRPCRR.Response _, Document response_doc) {
                            req.respond(response_doc);
                        },
                        (dartHiRPCRR.Error _, string msg) {
                            req.error(msg);
                        },
                        (readRecorderRR.Response _, Document response_doc) {
                            req.respond(response_doc);
                        },
                        (readRecorderRR.Error _, string msg) {
                            req.error(msg);
                        },
                );
            }
            catch (Exception e) {
                req.error(e.msg);
            }
        }, req, tn, doc);
    }

    void task() @trusted {
        log("listening on %s", thisActor.task_name);
        import std.concurrency;

        auto scheduler = new FiberScheduler;
        scheduler.start({
            run(
                    &node_send,
                    &node_recv,
                    &wave_send,
                    &wave_recv,
            );
        });
    }
}
