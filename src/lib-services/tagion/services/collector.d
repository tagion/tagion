/// [Documentation documents/architecture/InputValidator](https://docs.tagion.org/#/documents/architecture/Collector)
module tagion.services.collector;

import tagion.actor.actor;
import tagion.hibon.HiBONRecord;
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

import std.typecons;

@safe
struct CollectorOptions {
    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

import std.stdio;

@safe
struct CollectorService {
    immutable SecureNet net;
    const string dart_task_name;
    const string tvm_task_name;

    CollectedSignedContract[uint] collections;
    CollectedSignedContract*[uint] reads;

    void task() {
        assert(net !is null, "No secure net");
        assert(dart_task_name !is string.init && tvm_task_name !is string.init, "no task names");
        run(&signed_contract, &recorder, &rpc_contract);
    }

    // Input received directly from the HiRPC verifier
    void rpc_contract(inputHiRPC, immutable(HiRPC.Receiver) receiver) @trusted {
        immutable doc = Document(receiver.method.params);
        if (!doc.isRecord!SignedContract) {
            return;
        }
        signed_contract(inputContract(), cast(immutable) SignedContract(doc));
    }

    void signed_contract(inputContract, immutable(SignedContract) s_contract) @trusted {
        auto inputs_req = dartReadRR();

        CollectedSignedContract collected;
        collected.sign_contract = s_contract;
        collections[inputs_req.id] = collected;
        if (s_contract.contract.reads !is DARTIndex[].init) {
            auto reads_req = dartReadRR();
            reads[reads_req.id] = inputs_req.id in collections;
            locate(dart_task_name).send(reads_req, s_contract.contract.reads);
        }

        locate(dart_task_name).send(inputs_req, s_contract.contract.inputs);
    }

    void recorder(dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) @trusted {
        import std.range;
        import std.algorithm.iteration : map;

        if ((res.id in reads) !is null) {
            scope (exit) {
                // TODO: dereference;
            }
            auto collection = *(res.id in reads);
            collection.reads = recorder[].map!(a => a.toDoc).array.dup;
            return;
        }
        else if ((res.id in collections) !is null) {
            scope (exit) {
                //dereference
            }
            auto collection = res.id in collections;
            const s_contract = collection.sign_contract;
            immutable contract_hash = net.calcHash(s_contract.contract);
            foreach (index, sign; zip(s_contract.contract.inputs, s_contract.signs)) {
                const archive = find(recorder, index);
                if (archive is null) {
                    return;
                }

                Pubkey pkey = archive.filed[StdNames.owner].get!Buffer;
                if (!net.verify(contract_hash, sign, pkey)) {
                    return;
                }
            }
            collection.inputs = recorder[].map!(a => a.toDoc).array.dup;
            if (collection.inputs.length == 0) {
                return;
            }

            (() @trusted => locate(tvm_task_name).send(signedContract(), cast(immutable) collection))();
        }
    }
}

alias CollectorServiceHandle = ActorHandle!CollectorService;

// The find funtion in dart.recorder doest not work with an immutable recorder;
import tagion.dart.DARTBasic : DARTIndex;

const(Archive) find(const(RecordFactory.Recorder) rec, const(DARTIndex) index) {
    foreach (_archive; rec[]) {
        if (_archive.fingerprint == index) {
            return _archive;
        }
    }
    return null;
}
