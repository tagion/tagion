/// The collector collects & verifies the inputs in a contract
/// https://docs.tagion.org/tech/architecture/Collector
module tagion.services.collector;
@safe:

import std.exception;
import std.typecons;
import std.algorithm;
import std.range;
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
import tagion.services.exception;
import tagion.utils.pretend_safe_concurrency;
import conc = tagion.utils.pretend_safe_concurrency;
import tagion.hibon.HiBONJSON;
import tagion.logger.ContractTracker;

struct CollectorOptions {
    import tagion.json.JSONRecord;

    mixin JSONRecord;
}

/// Topic for rejected collector inputs;
Topic reject_collector = "reject/collector";

immutable(CollectedSignedContract)* collect_contract(ActorHandle dart_handle, immutable SecureNet net, immutable(SignedContract)* s_contract) {
    immutable(Document)[] contract_reads;
    /* Read indices */ 
    if (s_contract.signs.length != s_contract.contract.inputs.length) {
        throw new ServiceException("contract_mismatch_signature_length");
    }

    if (!s_contract.contract.reads.empty) {
        auto reads_req = dartReadRR();
        dart_handle.send(reads_req, (*s_contract).contract.reads);
        receive((dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) {
                assert(res.id == reads_req.id);
                check(recorder[].map!(a => a.dart_index).array == (*s_contract).contract.reads, "missing_archives");
                contract_reads = recorder[].map!(a => a.filed).array;
            }
        );
    }

    auto inputs_req = dartReadRR();
    dart_handle.send(inputs_req, (*s_contract).contract.inputs);

    // receive inputs recorder response
    immutable(Document)[] contract_inputs;
    receive((dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) {
        assert(res.id == inputs_req.id);
        check(recorder[].map!(a => a.dart_index).array == (*s_contract).contract.inputs, "missing_archives");
        contract_inputs = recorder[].map!(a => a.filed).array;
    });

    if (!verify(net, s_contract, contract_inputs)) {
        throw new ServiceException("contract_no_verify");
    }

    assert(contract_inputs !is Document[].init, "Recorder should've contained inputs at this point");

    return new immutable(CollectedSignedContract)(s_contract, contract_inputs, contract_reads);
}

void collect_contract_hirpc(ActorHandle tvm_handle, ActorHandle dart_handle, immutable(SecureNet) net, immutable(SignedContract)* s_contract) {
    try {
        auto collected = collect_contract(dart_handle, net, s_contract);
        if(collected) {
            tvm_handle.send(signedContract(), collected);
        }
    }
    catch(Exception e) {
        log.event(reject_collector, e.msg, Document.init);
        logContractStatus(s_contract.contract, ContractStatusCode.rejected, e.msg);
    }
}

void collect_contract_consensus(ActorHandle tvm_handle, ActorHandle dart_handle, immutable(SecureNet) net, immutable(SignedContract)* s_contract) {
    try {
        auto collected = collect_contract(dart_handle, net, s_contract);
        if(collected) {
            tvm_handle.send(consensusContract(), collected);
        }
    }
    catch(Exception e) {
        log.event(reject_collector, e.msg, Document.init);
        logContractStatus(s_contract.contract, ContractStatusCode.rejected, e.msg);
    }
}

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
    immutable(SecureNet) net;

    @trusted
    this(immutable(TaskNames) tn) nothrow {
        dart_handle = ActorHandle(tn.dart);
        tvm_handle = ActorHandle(tn.tvm);
        // Only used for verify function
        net = cast(immutable)createSecureNet;
        assert(net !is null, "No secure net");
    }

    @trusted
    void task() {
        auto scheduler = new FiberScheduler;
        scheduler.start({
            run(&signed_contract, &rpc_contract);
        });
    }

    void signed_contract(consensusContract, immutable(SignedContract*)[] signed_contracts) {
        foreach(s_contract; signed_contracts) {
            conc.spawn(&collect_contract_consensus, tvm_handle, dart_handle, net, s_contract);
        }
    }

    // Input received directly from the HiRPC verifier
    void rpc_contract(inputHiRPC, immutable(HiRPC.Receiver) receiver) @safe {
        immutable doc = Document(receiver.method.params);
        log("collector received receiver");
        try {
            immutable s_contract = new immutable(SignedContract)(doc);
            conc.spawn(&collect_contract_hirpc, tvm_handle, dart_handle, net, s_contract);
        }
        catch (HiBONRecordException e) {
            log.event(reject_collector, "hirpc_invalid_signed_contract", doc);
        }
    }
}
