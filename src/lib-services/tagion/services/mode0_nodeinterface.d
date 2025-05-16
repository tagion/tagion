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
import tagion.crypto.SecureNet;
import tagion.communication.HiRPC;
import tagion.utils.pretend_safe_concurrency;

///
struct Mode0NodeInterfaceService {
    const(SecureNet) net;
    const(HiRPC) hirpc;
    ActorHandle receive_handle;
    shared(AddressBook) addressbook;

    ///
    this(shared(SecureNet) shared_net, shared(AddressBook) addressbook, string message_handler_task) {
        this.net = shared_net.clone;
        this.hirpc = HiRPC(this.net);
        this.receive_handle = ActorHandle(message_handler_task);
        this.addressbook = addressbook;
    }

    void node_send(WavefrontReq req, Pubkey channel, Document doc) {
        const nnr = addressbook[channel].get;
        Tid node_tid = locate(nnr.address);
        if(node_tid is Tid.init) {
            log.error("Tid node address '%s' is not registered", nnr.address);
            return;
        }
        node_tid.send(req, doc);
    }

    void node_recv(WavefrontReq req, Document doc) {
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
        receive_handle.send(req, doc);
    }

    void task() {
        log("listening on %s", thisActor.task_name);

        run(
                &node_send,
                &node_recv,
        );
    }
}
