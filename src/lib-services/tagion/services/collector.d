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

@safe
struct CollectorOptions {
    import tagion.utils.JSONCommon;

    string task_name = "collector_task";
    mixin JSONCommon;
}

@safe
struct CollectorService {
    void task(immutable(CollectorOptions) opts, string dart_task_name, immutable SecureNet net) {
        //            [req id]
        SignedContract[uint] contracts;

        void signed_contract(inputContract, immutable(SignedContract) s_contract) {
            const req = dartReadRR();
            contracts[req.id] = cast(SignedContract) s_contract;
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

        void recorder(dartReadRR.Response res, immutable(RecordFactory.Recorder) recorder) {
            import std.range;
            import tagion.dart.DARTBasic : dartFingerprint;

            auto contract = contracts[res.id];
            foreach (dartindex, sign, archive; zip(contract.contract.inputs, contract.signs, recorder[])) {
                Pubkey pkey = archive.filed[OwnerKey].get!Buffer;
                if (!net.verify(dartFingerprint(dartindex), sign, pkey)) {
                    return;
                }
            }
        }

        run(&signed_contract, &recorder, &rpc_contract);
    }
}
