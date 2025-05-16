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
import tagion.crypto.SecureNet;
import tagion.communication.HiRPC;
import tagion.utils.pretend_safe_concurrency;

///
struct Mode0NodeInterfaceService {
    const(SecureNet) net;
    const(HiRPC) hirpc;
    ActorHandle epoch_creator_handle;
    ActorHandle dart_handle;
    shared(AddressBook) addressbook;

    ///
    this(shared(SecureNet) shared_net, shared(AddressBook) addressbook, TaskNames tn) {
        this.net = shared_net.clone;
        this.hirpc = HiRPC(this.net);
        this.epoch_creator_handle = ActorHandle(tn.epoch_creator);
        this.dart_handle = ActorHandle(tn.dart);
        this.addressbook = addressbook;
    }

    // Send a message to another node
    void wave_send(WavefrontReq req, Pubkey channel, Document doc) {
        const nnr = addressbook[channel].get;
        Tid node_tid = locate(nnr.address);
        if(node_tid is Tid.init) {
            log.error("Tid node address '%s' is not registered", nnr.address);
            return;
        }
        node_tid.send(req, doc);
    }

    // Receive a message from another node
    void wave_recv(WavefrontReq req, Document doc) {
        if (!doc.empty && !doc.isInorder(Document.Reserved.no)) {
            log.error("received document was invalid %s", doc);
            return;
        }
        const hirpcmsg = hirpc.receive(doc);
        if (hirpcmsg.pubkey == this.net.pubkey) {
            log.error("Received hirpc was from yourself replay?\n%J", doc);
            return;
        }
        if (!hirpcmsg.isSigned) {
            log.error("Received hirpc was not signed\n%J", doc);
            return;
        }
        epoch_creator_handle.send(req, doc);
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
        spawn((NodeReq req, ActorHandle dart_handle, Document doc) {
            // TODO check signatures and method name
            dart_handle.send(dartHiRPCRR(), doc);
            Document response_doc = receiveOnly!(dartHiRPCRR.Response, Document)[1];
            // Extern nodeinterface
            req.respond(response_doc);
        }, req, dart_handle, doc);
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
