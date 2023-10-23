// Service for transcript  
/// [Documentation](https://docs.tagion.org/#/documents/architecture/transcript)
module tagion.services.transcript;

import std.stdio;
import std.exception;
import std.array;
import std.algorithm;

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
import tagion.crypto.SecureNet;
import tagion.services.messages;
import tagion.script.execute : ContractProduct;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.hashgraph.HashGraphBasic : EventPackage;
import tagion.logger.Logger;
import tagion.services.options;
import tagion.utils.StdTime;
import tagion.script.common;
import tagion.dart.Recorder;
import tagion.services.options : TaskNames;
import tagion.hibon.HiBONJSON;
import tagion.utils.Miscellaneous : toHexString;
import tagion.crypto.Types;

@safe:

enum BUFFER_TIME_SECONDS = 30;

struct TranscriptOptions {
    mixin JSONCommon;
}

/**
 * TranscriptService actor
 * Receives: (inputDoc, Document)
 * Sends: (inputHiRPC, HiRPC.Receiver) to receiver_task, where Document is a correctly formatted HiRPC
**/
struct TranscriptService {
    void task(immutable(TranscriptOptions) opts, immutable(size_t) number_of_nodes, shared(StdSecureNet) shared_net, immutable(TaskNames) task_names) {
        const net = new StdSecureNet(shared_net);

        immutable(ContractProduct)*[DARTIndex] products;
        auto rec_factory = RecordFactory(net);


        struct Votes {
            ConsensusVoting[] votes;
            long epoch;
            Fingerprint bullseye;
            this(Fingerprint bullseye, long epoch) {
                this.bullseye = bullseye;
                this.epoch = epoch;
            }

            bool addVote(ConsensusVoting vote) {
                // check the vote
                votes ~= vote;
                return votes.length == number_of_nodes;
            }
        }
        Votes[long] votes;

        struct EpochContracts {
            SignedContract[] signed_contracts;
            sdt_t epoch_time;
            Votes[] previous_votes;
        }

        immutable(EpochContracts)*[uint] epoch_contracts;

        void createRecorder(dartCheckReadRR.Response res, immutable(DARTIndex)[] not_in_dart) {
            log("received response from dart %s", not_in_dart);

            DARTIndex[] used;

            used ~= not_in_dart;

            const epoch_contract = epoch_contracts.get(res.id, null);
            if (epoch_contract is null) {
                log("unlinked data received from dart aborting epoch");
            }
            scope (exit) {
                epoch_contracts.remove(res.id);
                log("removed %s from epoch_contracts", res.id);
            }

            auto recorder = rec_factory.recorder;
            loop_signed_contracts: foreach (signed_contract; epoch_contract.signed_contracts) {
                foreach (input; signed_contract.contract.inputs) {
                    if (used.canFind(input)) {
                        log("input already in used list");
                        continue loop_signed_contracts;
                    }
                }

                const tvm_contract_outputs = products.get(net.dartIndex(signed_contract.contract), null);
                if (tvm_contract_outputs is null) {
                    log("contract not found asserting");
                }

                import tagion.utils.StdTime;
                import core.time;
                import std.datetime;

                const max_time = sdt_t((SysTime(cast(long) epoch_contract.epoch_time) + BUFFER_TIME_SECONDS.seconds)
                        .stdTime);

                foreach (doc; tvm_contract_outputs.outputs) {
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

            auto req = dartModifyRR();
            req.id = res.id;
            log("CREATING REQUEST");

            // if(recorder.empty) {
            //     return;
            // }
            locate(task_names.dart).send(req, RecordFactory.uniqueRecorder(recorder), cast(immutable(int)) res.id);

        }

        void epoch(consensusEpoch, immutable(EventPackage*)[] epacks, immutable(int) epoch_number, const(sdt_t) epoch_time) @safe {

            ConsensusVoting[] received_votes = epacks
                .filter!(epack => epack.event_body.payload.isRecord!ConsensusVoting)
                .map!(epack => ConsensusVoting(epack.event_body.payload))
                .array;

            Votes[] previous_votes;
            foreach (v; received_votes) {
                if (votes[v.epoch].addVote(v)) {
                    const same_bullseyes = votes[v.epoch].votes.all!(_v => _v.verifyBullseye(net, votes[v.epoch].bullseye));

                    if (!same_bullseyes) {
                        throw new Exception("Signed bullseyes not the same");
                    }
                    
                    previous_votes ~= votes[v.epoch];
                    votes.remove(v.epoch);
                    log("ALL VOTES RECEIVED [%s]", same_bullseyes);
                }
            }

            auto signed_contracts = epacks
                .filter!(epack => epack.event_body.payload.isRecord!SignedContract)
                .map!(epack => immutable(SignedContract)(epack.event_body.payload))
                .array;

            auto inputs = signed_contracts
                .map!(signed_contract => signed_contract.contract.inputs)
                .join
                .array;

            
            auto req = dartCheckReadRR();
            req.id = cast(uint) epoch_number;
            epoch_contracts[req.id] = (() @trusted => new immutable(EpochContracts)(signed_contracts, epoch_time, cast(immutable) previous_votes))();

            // pragma(msg, "Inputs ", typeof(inputs));
            if (inputs.length == 0) {
                createRecorder(req.Response(req.msg, req.id), inputs);
                return;
            }

            (() @trusted => locate(task_names.dart).send(req, inputs))();

        }

        void receiveBullseye(dartModifyRR.Response res, Fingerprint bullseye) {
            import tagion.utils.Miscellaneous : cutHex;

            log("transcript received bullseye %s", bullseye.cutHex);

            auto epoch_number = cast(long) res.id;
            ConsensusVoting own_vote = ConsensusVoting(
                    epoch_number,
                    net.pubkey,
                    net.sign(bullseye)
            );

            votes[epoch_number] = Votes(bullseye, epoch_number);

            locate(task_names.epoch_creator).send(Payload(), own_vote.toDoc);
        }

        void produceContract(producedContract, immutable(ContractProduct)* product) {
            log("received ContractProduct");
            auto product_index = net.dartIndex(product.contract.sign_contract.contract);
            products[product_index] = product;

        }

        //run(&epoch);
        run(&epoch, &produceContract, &createRecorder, &receiveBullseye);
        //run(&produceContract, &createRecorder, &receiveBullseye);
    }
}

alias TranscriptServiceHandle = ActorHandle!TranscriptService;
