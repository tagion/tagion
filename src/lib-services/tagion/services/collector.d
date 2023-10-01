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

    immutable(SignedContract)[uint] contracts;
    immutable(RecordFactory.Recorder)[uint] reads;
    uint[uint] readsmap;

    Topic reject;
    void task() {
        assert(net !is null, "No secure net");
        reject = submask.register(reject_collector);
        run(&signed_contract, &recorder, &rpc_contract);
    }

    // Input received directly from the HiRPC verifier
    void rpc_contract(inputHiRPC, immutable(HiRPC.Receiver) receiver) @trusted {
        immutable doc = Document(receiver.method.params);
        log("collector received receiver");
        if (!doc.isRecord!SignedContract) {
            log(reject, "hirpc_not_a_signed_contract", doc);
            return;
        }
        try {
            signed_contract(inputContract(), cast(immutable) SignedContract(doc));
        }
        catch (HiBONRecordException e) {
            log(reject, "hirpc_invalid_signed_contract", doc);
        }
    }

    void signed_contract(inputContract, immutable(SignedContract) s_contract) {
        auto inputs_req = dartReadRR();
        if (s_contract.signs.length != s_contract.contract.inputs.length) {
            log(reject, "contract_mismatch_signature_length", Document.init);
            return;
        }

        auto contract_ptr = inputs_req.id in contracts;
        contract_ptr = &s_contract;
        if (s_contract.contract.reads !is DARTIndex[].init) {
            auto reads_req = dartReadRR();
            readsmap[reads_req.id] = inputs_req.id;
            log("sending contract read request to dart");
            locate(task_names.dart).send(reads_req, s_contract.contract.reads);
        }

        log("sending contract input request to dart");
        locate(task_names.dart).send(inputs_req, s_contract.contract.inputs);
    }

    void recorder(dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) {
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
            auto reads_ptr = contract_id in reads;
            reads_ptr = &recorder;
            return;
        }
        else if ((res.id in contracts) !is null) {
            scope (exit) {
                contracts.remove(res.id);
                if ((res.id in reads) !is null) {
                    reads.remove(res.id);
                }
            }
            // if (recorder[].map(a => a.fingerprint).array != collection.inputs.length) {
            //     log(reject, "missing_archives", recorder);
            //     return;
            // }
            immutable s_contract = contracts[res.id];
            const contract_hash = net.calcHash(s_contract.contract);
            foreach (index, sign; zip(s_contract.contract.inputs, s_contract.signs)) {
                immutable archive = find(recorder, index);
                if (archive is null) {
                    log(reject, "archive_no_exist", recorder);
                    return;
                }
                if (!archive.filed.hasMember(StdNames.owner)) {
                    log(reject, "archive_no_pubkey", recorder);
                    return;
                }
                Pubkey pkey = archive.filed[StdNames.owner].get!Buffer;
                if (!net.verify(contract_hash, sign, pkey)) {
                    log(reject, "contract_no_verify", recorder);
                    return;
                }
            }

            if (recorder is RecordFactory.init) {
                log(reject, "contract_no_inputs", recorder);
                return;
            }

            immutable reads_recorder =
                ((res.id in reads) !is null) ?
                reads[res.id] : RecordFactory.Recorder.init;

            immutable collection = new immutable(CollectedSignedContract)(s_contract, recorder, reads_recorder);

            log("sending to tvm");
            locate(task_names.tvm).send(signedContract(), collection);
        }
    }
}

alias CollectorServiceHandle = ActorHandle!CollectorService;

// The find funtion in dart.recorder doest not work with an immutable recorder;
import tagion.dart.DARTBasic : DARTIndex;

private immutable(Archive) find(immutable(RecordFactory.Recorder) rec, const(DARTIndex) index) @safe nothrow pure {
    foreach (const _archive; rec[]) {
        if (_archive.fingerprint == index) {
            return _archive;
        }
    }
    return null;
}
