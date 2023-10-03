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
import tagion.hibon.HiBONJSON;
import tagion.utils.Miscellaneous : toHexString;

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

        void epoch(consensusEpoch, immutable(EventPackage*)[] epacks, immutable(int) epoch_number) {
            if (epacks.length == 0) {
                return;
            }

            log("epoch type %s", epacks[0].event_body.payload.toPretty);
            
            SignedContract[] signed_contracts = epacks
                .map!(epack => SignedContract(epack.event_body.payload))
                .array;

            auto inputs = signed_contracts
                .map!(signed_contract => signed_contract.contract.inputs)
                .join
                .array;

            auto req = dartCheckReadRR();
            req.id = cast(uint) epoch_number;
            epoch_contracts[req.id] = EpochContracts(signed_contracts);

            (() @trusted => locate(task_names.dart).send(req, cast(immutable(DARTIndex)[]) inputs))();
        }

        void createRecorder(dartCheckReadRR.Response res, immutable(DARTIndex)[] not_in_dart) {
            log("received response from dart %s", not_in_dart);


            if (not_in_dart.length != 0) {
                pragma(msg, "fixme(pr): figure out what to do if some archives were not in the dart");
                log("Received not in dart response: %s. Must be implemented", not_in_dart.map!(f => f.toHexString));
                assert(0, "must be implemented");
            }

            const epoch_contract = epoch_contracts.get(res.id, EpochContracts.init);
            assert(epoch_contract !is EpochContracts.init, "unlinked data received from DART");
            scope (exit) {
                epoch_contracts.remove(res.id);
                log("removed %s from epoch_contracts", res.id);
            }

            DARTIndex[] used;
            auto recorder = rec_factory.recorder;

            foreach (signed_contract; epoch_contract.signed_contracts) {
                foreach (input; signed_contract.contract.inputs) {
                    if (used.canFind(input)) {
                        assert(0, "input already in used list");
                    }
                }

                const tvm_contract_outputs = products.get(net.dartIndex(signed_contract.contract), null);
                if (tvm_contract_outputs is null) {
                    log("contract not found asserting");
                    assert(0, "what should we do here");
                }

                scope(exit) { 
                    products.remove(net.dartIndex(signed_contract.contract));
                }

                recorder.insert(tvm_contract_outputs.outputs, Archive.Type.ADD);
                recorder.insert(tvm_contract_outputs.contract.inputs, Archive.Type.REMOVE);

                used ~= signed_contract.contract.inputs;
            }

            pragma(msg, "fixme(pr): add epoch_number");
            locate(task_names.dart).send(dartModify(), RecordFactory.uniqueRecorder(recorder), cast(immutable(int)) res.id);

        }

        void produceContract(producedContract, immutable(ContractProduct)* product) {
            log("received ContractProduct");
            auto product_index = net.dartIndex(product.contract.sign_contract.contract);
            products[product_index] = product;

        }

        run(&epoch, &produceContract, &createRecorder);
    }
}

alias TranscriptServiceHandle = ActorHandle!TranscriptService;
