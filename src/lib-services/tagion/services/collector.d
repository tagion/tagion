/// [Documentation documents/architecture/InputValidator](https://docs.tagion.org/#/documents/architecture/Collector)
module tagion.services.collector;
@safe:

import std.exception;
import std.typecons;
import tagion.actor.actor;
import tagion.basic.Types;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.Recorder : Archive, RecordFactory;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.hibon.Document;
import tagion.hibon.HiBONException : HiBONRecordException;
import tagion.hibon.HiBONRecord;
import tagion.logger.Logger;
import tagion.script.common;
import tagion.script.execute;
import tagion.services.messages;
import tagion.services.options : TaskNames;
import tagion.utils.pretend_safe_concurrency;

struct CollectorOptions {
    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

/// Topic for rejected collector inputs;
enum reject_collector = "reject/collector";

/**
 * Collector Service actor
 * Sends:
 *  (dartReadRR, immutable(DARTIndex)[]) to TaskNames.dart
 *  (consensusContract(), immutable(CollectedSignedContract)*) to TaskNames.tvm 
 *  (signedContract(), immutable(CollectedSignedContract)*) to TaskNames.tvm 
**/
struct CollectorService {
    ActorHandle dart_handle;
    ActorHandle tvm_handle;

    this(immutable(TaskNames) tn) nothrow {
        dart_handle = ActorHandle(tn.dart);
        tvm_handle = ActorHandle(tn.tvm);
    }

    immutable(SignedContract)*[uint] contracts;
    bool[uint] is_consensus_contract;
    immutable(Document)[][uint] reads;

    Topic reject = Topic(reject_collector);
    SecureNet net;
    void task() {
        net = new StdSecureNet;
        assert(net !is null, "No secure net");
        run(&receive_recorder, &signed_contract, &consensus_signed_contract, &rpc_contract);
    }

    // Makes the read calls to the dart service;
    void read_indices(dartReadRR req, immutable(SignedContract)* s_contract) {
        if (s_contract.signs.length != s_contract.contract.inputs.length) {
            log(reject, "contract_mismatch_signature_length", Document.init);
            return;
        }

        contracts[req.id] = s_contract;
        scope (failure) {
            contracts.remove(req.id);
            reads.remove(req.id);
        }
        log("Set the signed_contract %s", (req.id in contracts) !is null);
        if (s_contract.contract.reads !is DARTIndex[].init) {
            log("sending contract read request to dart");
            dart_handle.send(req, (*s_contract).contract.reads);
        }

        log("sending contract input request to dart");
        dart_handle.send(req, (*s_contract).contract.inputs);
    }

    void consensus_signed_contract(consensusContract, immutable(SignedContract*)[] signed_contracts) {
        foreach (s_contract; signed_contracts) {
            auto req = dartReadRR();
            is_consensus_contract[req.id] = true;
            read_indices(req, s_contract);
        }
    }

    void signed_contract(inputContract, immutable(SignedContract)* s_contract) {
        auto req = dartReadRR();
        is_consensus_contract[req.id] = false;
        read_indices(req, s_contract);
    }

    // Input received directly from the HiRPC verifier
    void rpc_contract(inputHiRPC, immutable(HiRPC.Receiver) receiver) @safe {
        immutable doc = Document(receiver.method.params);
        log("collector received receiver");
        try {
            immutable s_contract = new immutable(SignedContract)(doc);
            signed_contract(inputContract(), s_contract);
        }
        catch (HiBONRecordException e) {
            log(reject, "hirpc_invalid_signed_contract", doc);
        }
    }

    private void clean(uint id) {
        is_consensus_contract.remove(id);
        contracts.remove(id);
        reads.remove(id);
    }

    // Receives the read Documents from the dart and constructs the CollectedSignedContract
    void receive_recorder(dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) {
        import std.algorithm.iteration : map;
        import std.range;

        scope (failure) {
            clean(res.id);
        }
        log("received dartresponse");

        if (!(res.id in contracts)) {
            return;
        }

        immutable s_contract = contracts[res.id];
        auto fingerprints = recorder[].map!(a => a.dart_index).array;
        if (s_contract.contract.reads !is null && fingerprints == contracts[res.id].contract.reads) {
            reads[res.id] = recorder[].map!(a => a.filed).array;
            return;
        }
        else if (fingerprints == contracts[res.id].contract.inputs) {
            log("Received and input response");
            scope (exit) {
                clean(res.id);
            }

            immutable inputs = recorder[].map!(a => a.filed).array;

            if (!verify(net, s_contract, inputs)) {
                log(reject, "contract_no_verify", recorder);
                return;
            }

            assert(inputs !is Document[].init, "Recorder should've contained inputs at this point");
            immutable collection =
                ((res.id in reads) !is null)
                ? new immutable(CollectedSignedContract)(s_contract, inputs, reads[res.id]) : new immutable(
                        CollectedSignedContract)(s_contract, inputs);

            log("sending to tvm");
            if (is_consensus_contract[res.id]) {
                tvm_handle.send(consensusContract(), collection);
            }
            else {
                tvm_handle.send(signedContract(), collection);
            }
            return;
        }
        else {
            clean(res.id);
            log(reject, "missing_archives", recorder);
            return;
        }
    }

}
