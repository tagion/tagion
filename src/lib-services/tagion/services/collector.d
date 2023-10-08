/// [Documentation documents/architecture/InputValidator](https://docs.tagion.org/#/documents/architecture/Collector)
module tagion.services.collector;

import tagion.actor.actor;
import tagion.hibon.HiBONRecord;
import tagion.hibon.HiBONException : HiBONRecordException;
import tagion.hibon.Document;
import tagion.dart.Recorder : RecordFactory, Archive;
import tagion.services.messages;
import tagion.script.execute;
import tagion.script.common;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types;
import tagion.basic.Types;
import tagion.utils.pretend_safe_concurrency;
import tagion.services.options : TaskNames;
import tagion.logger.Logger;

import std.typecons;
import std.exception;

@safe
struct CollectorOptions {
    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

/// Topic for rejected collector inputs;
enum reject_collector = "reject/collector";

@safe
struct CollectorService {
    immutable SecureNet net;
    immutable TaskNames task_names;

    immutable(SignedContract)*[uint] contracts;
    bool[uint] is_consensus_contract;
    immutable(Document)[][uint] reads;
    uint[uint] readsmap;

    Topic reject;
    void task() {
        assert(net !is null, "No secure net");
        reject = submask.register(reject_collector);
        run(&receive_recorder, &signed_contract, &consensus_signed_contract, &rpc_contract);
    }

    // Makes the read calls to the dart service;
    void read_indices(dartReadRR inputs_req, immutable(SignedContract)* s_contract) {
        auto reads_req = dartReadRR();
        if (s_contract.signs.length != s_contract.contract.inputs.length) {
            log(reject, "contract_mismatch_signature_length", Document.init);
            return;
        }

        contracts[inputs_req.id] = s_contract;
        scope (failure) {
            contracts.remove(inputs_req.id);
            readsmap.remove(reads_req.id);
        }
        log("Set the signed_contract %s", (inputs_req.id in contracts) !is null);
        if (s_contract.contract.reads !is DARTIndex[].init) {
            readsmap[reads_req.id] = inputs_req.id;
            log("sending contract read request to dart");
            locate(task_names.dart).send(reads_req, (*s_contract).contract.reads);
        }

        log("sending contract input request to dart");
        locate(task_names.dart).send(inputs_req, (*s_contract).contract.inputs);
    }

    void consensus_signed_contract(consensusContract, immutable(SignedContract*)[] signed_contracts) {
        foreach (s_contract; signed_contracts) {
            auto inputs_req = dartReadRR();
            is_consensus_contract[inputs_req.id] = true;
            read_indices(inputs_req, s_contract);
        }
    }

    void signed_contract(inputContract, immutable(SignedContract)* s_contract) {
        auto inputs_req = dartReadRR();
        is_consensus_contract[inputs_req.id] = false;
        read_indices(inputs_req, s_contract);
    }

    // Input received directly from the HiRPC verifier
    void rpc_contract(inputHiRPC, immutable(HiRPC.Receiver) receiver) @safe {
        immutable doc = Document(receiver.method.params);
        log("collector received receiver");
        if (!doc.isRecord!SignedContract) {
            log(reject, "hirpc_not_a_signed_contract", doc);
            return;
        }
        try {
            // No immutable construct on this HiBONRecord
            immutable s_contract = (() @trusted => (cast(immutable) new SignedContract(doc)))();
            signed_contract(inputContract(), s_contract);
        }
        catch (HiBONRecordException e) {
            log(reject, "hirpc_invalid_signed_contract", doc);
        }
    }

    // Receives the read Documents from the dart and constructs the CollectedSignedContract
    void receive_recorder(dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) {
        import std.range;
        import std.algorithm.iteration : map;

        log("received dartRead response");
        if ((res.id in readsmap) !is null) {
            scope (exit) {
                readsmap.remove(res.id);
            }
            // if (recorder[].map(a => a.fingerprint).array != collection.reads.length) {
            //     log(reject, "missing_archives", recorder);
            //      // Remove inputs aswell
            //     return;
            // }
            const contract_id = readsmap[res.id];
            reads[contract_id] = recorder[].map!(a => a.filed).array;
            return;
        }
        else if ((res.id in contracts) !is null) {
            log("Received and input response");
            scope (exit) {
                is_consensus_contract.remove(res.id);
                contracts.remove(res.id);
                reads.remove(res.id);
            }
            // if (recorder[].map(a => a.fingerprint).array != collection.inputs.length) {
            //     log(reject, "missing_archives", recorder);
            //     return;
            // }
            immutable s_contract = contracts[res.id];
            immutable inputs = recorder[].map!(a => a.filed).array;

            if (!verify(net, s_contract, inputs)) {
                log(reject, "contract_no_verify", recorder);
                return;
            }
            // const contract_hash = net.calcHash(s_contract.contract);

            // foreach (index, sign; zip(s_contract.contract.inputs, s_contract.signs)) {
            //     immutable archive = find(recorder, index);
            //     if (archive is null) {
            //         log(reject, "archive_no_exist", recorder);
            //         return;
            //     }
            //     if (!archive.filed.hasMember(StdNames.owner)) {
            //         log(reject, "archive_no_pubkey", recorder);
            //         return;
            //     }
            //     Pubkey pkey = archive.filed[StdNames.owner].get!Buffer;
            //     if (!net.verify(contract_hash, sign, pkey)) {
            //         log(reject, "contract_no_verify", recorder);
            //         return;
            //     }
            // }

            if (recorder is RecordFactory.init) {
                log(reject, "contract_no_inputs", recorder);
                return;
            }

            assert(inputs !is Document[].init, "Recorder should've contained inputs at this point");
            immutable collection =
                ((res.id in reads) !is null)
                ? new immutable(CollectedSignedContract)(s_contract, inputs, reads[res.id]) : new immutable(
                    CollectedSignedContract)(s_contract, inputs);

            log("sending to tvm");
            if (is_consensus_contract[res.id]) {
                locate(task_names.tvm).send(consensusContract(), collection);
            }
            else {
                locate(task_names.tvm).send(signedContract(), collection);
            }
            return;
        }
        else {
            log("Response did not match any of the requests");
        }
    }

}

alias CollectorServiceHandle = ActorHandle!CollectorService;

// The find funtion in dart.recorder doest not work with an immutable recorder;
import tagion.dart.DARTBasic : DARTIndex;

private immutable(Archive) find(immutable(RecordFactory.Recorder) rec, const(DARTIndex) index) @safe nothrow pure {
    foreach (const _archive; rec[]) {
        if (_archive.dart_index == index) {
            return _archive;
        }
    }
    return null;
}
