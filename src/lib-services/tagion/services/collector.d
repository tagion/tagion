/// [Documentation documents/architecture/InputValidator](https://docs.tagion.org/#/documents/architecture/Collector)
module tagion.services.collector;

import tagion.actor.actor;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document;
import tagion.dart.Recorder : RecordFactory;
import tagion.services.messages;
import tagion.script.prior.StandardRecords;
import tagion.communication.HiRPC;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.Types;
import tagion.basic.Types;
import tagion.utils.pretend_safe_concurrency;

import std.typecons;

version (none) struct Stack(T) {
    import std.container.slist;

    immutable(T) pop(uint id) {
        return cast(immutable) t;
    }

    void push(uint id, immutable T item) {
        stack[id] = cast(T) item;
    }
}

@safe
struct CollectorOptions {
    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

@safe
struct CollectorService {
    void task(immutable(CollectorOptions) opts, immutable SecureNet net, const string dart_task_name, const string tvm_task_name) {
        //            [req id]
        // Slist!(immutable(SignedContract)) contracts;
        import std.typecons : Unique;

        CollectedSignedContract[uint] collections;
        // Unique!CollectedSignedContract[uint] collections;

        void signed_contract(inputContract, immutable(SignedContract) s_contract) {
            const req = dartReadRR();

            // collections[req.id] = new Unique!CollectorService;
            // collections[req.id].contract = s_contract;
            collections[req.id].contract = cast(SignedContract) s_contract;
            locate(dart_task_name).send(req, s_contract.contract.reads);
            locate(dart_task_name).send(req, s_contract.contract.inputs);
        }

        // Input received directly from the HiRPC verifier
        void rpc_contract(inputHiRPC, immutable(HiRPC.Receiver) receiver) {
            auto doc = Document(receiver.method.params);
            if (!doc.isRecord!SignedContract) {
                return;
            }

            signed_contract(inputContract(), cast(immutable) SignedContract(doc));
        }

        // bool verify(const Fingerprint message, const Signature signature, const Pubkey pubkey)

        void recorder(dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) @safe {
            import std.range;
            import tagion.dart.DARTBasic : dartFingerprint;
            import std.algorithm.iteration : map;

            auto collection = collections[res.id];

            const archives = recorder[];
            const s_contract = collection.contract;
            if (s_contract.contract.reads == archives.map!(a => a.fingerprint).array) {
                collection.reads = archives.map!(a => a.toDoc).array.dup;
            }
            if (s_contract.contract.inputs == archives.map!(a => a.fingerprint).array) {
                foreach (dartindex, sign, archive; zip(s_contract.contract.inputs, s_contract.signs, recorder[])) {
                    Pubkey pkey = archive.filed[OwnerKey].get!Buffer;
                    if (!net.verify(dartFingerprint(dartindex), sign, pkey)) {
                        return;
                    }
                }
                collection.inputs = archives.map!(a => a.toDoc).array.dup;
            }
            if (collection.reads !is Document[].init && collection.inputs !is Document[].init) {
                return;
            }

            import std.exception;

            const(Document[]) inputs = recorder[].map!(a => a.toDoc).array;
            // immutable collected = 
            //     CollectedSignedContract(
            //             assumeUnique(inputs),
            //             assumeUnique(inputs), // reads
            //             s_contract,
            //     );

            // locate(tvm_task_name).send(signedContract(), collected);
        }

        run(&signed_contract, &recorder, &rpc_contract);
    }
}
