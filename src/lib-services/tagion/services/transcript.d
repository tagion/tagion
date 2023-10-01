// Service for transcript  
/// [Documentation](https://docs.tagion.org/#/documents/architecture/transcript)
module tagion.services.transcript;

import std.stdio;

import tagion.logger.Logger;
import tagion.basic.Debug : __write;
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency;
import tagion.actor.actor;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.services.messages;
import tagion.script.execute : ContractProduct;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.hashgraph.HashGraphBasic : EventPackage;
import tagion.logger.Logger;
import tagion.services.options;
import std.array;
import tagion.utils.StdTime;
import tagion.script.common;
import std.algorithm;
import tagion.dart.Recorder;
import tagion.services.options : TaskNames;

@safe
struct TranscriptOptions {
    mixin JSONCommon;
}

/**
 * TranscriptService actor
 * Receives: (inputDoc, Document)
 * Sends: (inputHiRPC, HiRPC.Receiver) to receiver_task, where Document is a correctly formatted HiRPC
**/
@safe
struct TranscriptService {
    void task(immutable(TranscriptOptions) opts, immutable(SecureNet) net, immutable(TaskNames) task_names) {

        immutable(ContractProduct)*[DARTIndex] products;
        auto rec_factory = RecordFactory(net);

        struct EpochContracts {
            SignedContract[] signed_contracts;
        }

        EpochContracts[uint] epoch_contracts;

        void epoch(consensusEpoch, immutable(EventPackage*)[] epacks) {
            SignedContract[] s_contracts = epacks
                .map!(epack => SignedContract(epack.event_body.payload))
                .array;

            auto inputs = s_contracts
                .map!(s_contract => s_contract.contract.inputs)
                .array;

            const req = dartCheckReadRR();
            epoch_contracts[req.id] = EpochContracts(s_contracts);

            (() @trusted => locate(task_names.dart).send(req, cast(immutable(DARTIndex[])) inputs))();
        }

        void create_recorder(dartCheckReadRR.Response res, immutable(DARTIndex)[] not_in_dart) {

            if (not_in_dart.length == 0) {
                assert(0, "must be implemented");
            }

            const epoch_contract = epoch_contracts.get(res.id, EpochContracts.init);
            assert(epoch_contract !is EpochContracts.init, "unlinked data received from DART");
            scope (exit) {
                epoch_contracts.remove(res.id);
            }

            DARTIndex[] used;
            auto recorder = rec_factory.recorder;

            foreach (s_contract; epoch_contract.signed_contracts) {
                foreach (input; s_contract.contract.inputs) {
                    if (used.canFind(input)) {
                        assert(0, "input already in used list");
                    }
                }

                const tvm_contract_outputs = products.get(net.dartIndex(s_contract.contract), null);

                if (tvm_contract_outputs is null) {
                    assert(0, "what should we do here");
                }

                recorder.insert(tvm_contract_outputs.outputs, Archive.Type.ADD);
                recorder.insert(tvm_contract_outputs.contract.inputs, Archive.Type.REMOVE);

                used ~= s_contract.contract.inputs;
            }

            pragma(msg, "fixme(pr): add epoch_number");
            locate(task_names.dart).send(dartModify(), RecordFactory.uniqueRecorder(recorder), immutable int(0));

        }

        void produceContract(producedContract, immutable(ContractProduct)* product) {
            log("received ContractProduct");
            auto product_index = net.dartIndex(product.contract.sign_contract.contract);
            products[product_index] = product;

        }

        run(&epoch, &produceContract);
    }
}

alias TranscriptServiceHandle = ActorHandle!TranscriptService;
