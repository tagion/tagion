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

    CollectedSignedContract[uint] collections;
    CollectedSignedContract*[uint] reads;

    Topic reject;
    void task() {
        assert(net !is null, "No secure net");
        reject = submask.register(reject_collector);
        run(&signed_contract, &recorder, &rpc_contract);
    }

    // Input received directly from the HiRPC verifier
    void rpc_contract(inputHiRPC, immutable(HiRPC.Receiver) receiver) @trusted {
        immutable doc = Document(receiver.method.params);
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
            immutable ulong[2] r = [s_contract.signs.length, s_contract.contract.inputs.length];
            log(reject, "contract_mismatch_signature_length", r);
            return;
        }

        CollectedSignedContract collected;
        collected.sign_contract = s_contract;
        collections[inputs_req.id] = collected;

        if (s_contract.contract.reads !is DARTIndex[].init) {
            auto reads_req = dartReadRR();
            reads[reads_req.id] = inputs_req.id in collections;
            locate(task_names.dart).send(reads_req, s_contract.contract.reads);
        }

        locate(task_names.dart).send(inputs_req, s_contract.contract.inputs);
    }

    void recorder(dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) {
        import std.range;
        import std.algorithm.iteration : map;

        if ((res.id in reads) !is null) {
            auto collection = *(res.id in reads);
            scope (exit) {
                collection = null;
                reads.remove(res.id);
            }
            // if (recorder[].map(a => a.fingerprint).array != collection.reads.length) {
            //     log(reject, "missing_archives", recorder);
            //      // Remove inputs aswell
            //     return;
            // }
            collection.reads ~= recorder[].map!(a => a.toDoc).array;
            return;
        }
        else if ((res.id in collections) !is null) {
            auto collection = res.id in collections;
            scope (exit) {
                collection = null;
                collections.remove(res.id);
            }
            // if (recorder[].map(a => a.fingerprint).array != collection.inputs.length) {
            //     log(reject, "missing_archives", recorder);
            //     return;
            // }
            const s_contract = collection.sign_contract;
            const contract_hash = net.calcHash(s_contract.contract);
            foreach (index, sign; zip(s_contract.contract.inputs, s_contract.signs)) {
                immutable archive = find(recorder, index);
                if (archive is null) {
                    log(reject, "archive_no_exist", recorder);
                    return;
                }
                if (!archive.filed.hasMember(StdNames.owner)) {
                    log(reject, "archive_no_pubkey", archive);
                    return;
                }
                Pubkey pkey = archive.filed[StdNames.owner].get!Buffer;
                if (!net.verify(contract_hash, sign, pkey)) {
                    log(reject, "contract_no_verify", tuple(contract_hash, sign, pkey));
                    return;
                }
            }
            collection.inputs ~= recorder[].map!(a => a.toDoc).array;
            if (collection.inputs.length == 0) {
                log(reject, "contract_no_inputs", immutable(tuple)(collections.giveme(res.id), recorder));
                return;
            }

            locate(task_names.tvm).send(signedContract(), collections.giveme(res.id));
        }
    }
}

alias CollectorServiceHandle = ActorHandle!CollectorService;

private immutable(CollectedSignedContract*) giveme(ref CollectedSignedContract[uint] aa, uint key) @trusted nothrow pure {
    scope (exit) {
        aa.remove(key);
    }
    CollectedSignedContract* val = key in aa;
    return cast(immutable) val;
}

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
