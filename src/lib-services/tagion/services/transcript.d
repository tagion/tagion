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
import tagion.hibon.HiBONRecord : isRecord, HiBONRecord;
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
import tagion.crypto.Types;


enum BUFFER_TIME_SECONDS = 30;


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
    void task(immutable(TranscriptOptions) opts, immutable(size_t) number_of_nodes, immutable(SecureNet) net, immutable(TaskNames) task_names) {

        immutable(ContractProduct)*[DARTIndex] products;
        auto rec_factory = RecordFactory(net);

        struct EpochContracts {
            SignedContract[] signed_contracts;
            sdt_t epoch_time;
        }

        EpochContracts[uint] epoch_contracts;

        ConsensusVoting[][long] votes;
        

        void epoch(consensusEpoch, immutable(EventPackage*)[] epacks, immutable(int) epoch_number, const(sdt_t) epoch_time) {
            if (epacks.length == 0) {
                return;
            }

            ConsensusVoting[] received_votes = epacks
                .filter!(epack => epack.event_body.payload.isRecord!ConsensusVoting)
                .map!(epack => ConsensusVoting(epack.event_body.payload))
                .array;

            foreach(v; received_votes) {
                votes[v.epoch] ~= v;
            }

            log("epoch type %s", epacks[0].event_body.payload.toPretty);
            
            SignedContract[] signed_contracts = epacks
                .filter!(epack => epack.event_body.payload.isRecord!SignedContract)
                .map!(epack => SignedContract(epack.event_body.payload))
                .array;

            auto inputs = signed_contracts
                .map!(signed_contract => signed_contract.contract.inputs)
                .join
                .array;

            auto req = dartCheckReadRR();
            req.id = cast(uint) epoch_number;
            epoch_contracts[req.id] = EpochContracts(signed_contracts, epoch_time);

            (() @trusted => locate(task_names.dart).send(req, cast(immutable(DARTIndex)[]) inputs))();
        }

        void createRecorder(dartCheckReadRR.Response res, immutable(DARTIndex)[] not_in_dart) {
            log("received response from dart %s", not_in_dart);

            DARTIndex[] used;

            if (not_in_dart.length != 0) {
                used ~= not_in_dart;
            }

            const epoch_contract = epoch_contracts.get(res.id, EpochContracts.init);
            if (epoch_contract is EpochContracts.init) {
                log("unlinked data received from dart aborting epoch");
            }
            scope (exit) {
                epoch_contracts.remove(res.id);
                log("removed %s from epoch_contracts", res.id);
            }

            auto recorder = rec_factory.recorder;
            loop_signed_contracts:
            foreach (signed_contract; epoch_contract.signed_contracts) {
                foreach (input; signed_contract.contract.inputs) {
                    if (used.canFind(input)) {
                        log("input already in used list");
                        continue loop_signed_contracts;
                    }
                }

                const tvm_contract_outputs = products.get(net.dartIndex(signed_contract.contract), null);
                if (tvm_contract_outputs is null) {
                    log("contract not found asserting");
                    assert(0, "what should we do here");
                }

                import tagion.utils.StdTime;
                import core.time;
                import std.datetime;

                const max_time = sdt_t((SysTime(cast(long) epoch_contract.epoch_time) + BUFFER_TIME_SECONDS.seconds).stdTime);
                
                foreach(doc; tvm_contract_outputs.outputs) {
                    if (!doc.isRecord!TagionBill) {
                        continue;
                    }
                    const bill_time = TagionBill(doc).time;
                    if (bill_time > max_time) {
                        log("tagion bill timestamp too new bill_time: %s, epoch_time %s", bill_time.toText, max_time);
                        continue loop_signed_contracts;
                    }
                }


                recorder.insert(tvm_contract_outputs.outputs, Archive.Type.ADD);
                recorder.insert(tvm_contract_outputs.contract.inputs, Archive.Type.REMOVE);

                used ~= signed_contract.contract.inputs;
                products.remove(net.dartIndex(signed_contract.contract));
            }

            

            locate(task_names.dart).send(dartModifyRR(), RecordFactory.uniqueRecorder(recorder), cast(immutable(int)) res.id);

        }

        void receiveBullseye(dartModifyRR.Response, Fingerprint) {
            return;
        }

        void produceContract(producedContract, immutable(ContractProduct)* product) {
            log("received ContractProduct");
            auto product_index = net.dartIndex(product.contract.sign_contract.contract);
            products[product_index] = product;

        }

        run(&epoch, &produceContract, &createRecorder, &receiveBullseye);
    }
}

alias TranscriptServiceHandle = ActorHandle!TranscriptService;
