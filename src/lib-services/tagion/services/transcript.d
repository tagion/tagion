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
pragma(msg, "fixme, transcript needs to be updated with the hashgraph to use long as id");
struct TranscriptService {
    void task(immutable(TranscriptOptions) opts, immutable(size_t) number_of_nodes, shared(StdSecureNet) shared_net, immutable(TaskNames) task_names) {
        const net = new StdSecureNet(shared_net);

        immutable(ContractProduct)*[DARTIndex] products;
        auto rec_factory = RecordFactory(net);


        struct Votes {
            ConsensusVoting[] votes;
            Fingerprint bullseye;
            long epoch;
            this(Fingerprint bullseye, long epoch) {
                this.bullseye = bullseye;
                this.epoch = epoch;
            }
        }
        Votes[long] votes;

        struct EpochContracts {
            SignedContract[] signed_contracts;
            sdt_t epoch_time;

            // Votes[] previous_votes;
        }

        immutable(EpochContracts)*[long] epoch_contracts;


        void createRecorder(dartCheckReadRR.Response res, immutable(DARTIndex)[] not_in_dart) {
            log("received response from dart %s", not_in_dart);

            DARTIndex[] used;

            used ~= not_in_dart;

            // check the votes here instead
            // get a list of all epochs where majority of votes with correct signature have been received

            import tagion.hashgraph.HashGraphBasic : isMajority;

            Votes[] finished;
            foreach(aggregated_vote; votes.byKeyValue) {
                // if the length is not majority there is no reason to check the signatures.
                if (!aggregated_vote.value.votes.length.isMajority(number_of_nodes)) {
                    continue;
                }

                // filter out all signatures that are not equal to the bullseye we have ourselves.
                auto valid_votes = aggregated_vote.value.votes
                    .filter!(consensus_vote => consensus_vote.verifyBullseye(net, aggregated_vote.value.bullseye))
                    .array;

                // if the length of the valid signatures for the epoch is not majority then continue
                if (!valid_votes.length.isMajority(number_of_nodes)) {
                    continue;
                }

                // now we know that we have majority votes and they are the same. 
                finished ~= aggregated_vote.value;
            }


            writefln("length of finished votes: %s", finished.length);


            
            
            // auto test = votes.byKeyValue.filter!(x => x.value.votes.length == number_of_nodes).array;
            // log("LENGTH OF SOME STUPID VOTES: %s", test.length);


            // foreach(t; test) {
            //     votes.remove(t.key);
            // }


            

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

            // log("CONSENSUSVOTES: %s",epoch_contract.previous_votes.length);

            // checkLeaks();
            auto req = dartModifyRR();
            req.id = res.id;

            // if(recorder.empty) {
            //     return;
            // }
            locate(task_names.dart).send(req, RecordFactory.uniqueRecorder(recorder), cast(immutable) res.id);

        }

        void epoch(consensusEpoch, immutable(EventPackage*)[] epacks, immutable(long) epoch_number, const(sdt_t) epoch_time) @safe {

            // filter out all the votes
            ConsensusVoting[] received_votes = epacks
                .filter!(epack => epack.event_body.payload.isRecord!ConsensusVoting)
                .map!(epack => ConsensusVoting(epack.event_body.payload))
                .array;

            // add them to the vote array
            foreach (v; received_votes) {
                votes[v.epoch].votes ~= v;
                //     // const same_bullseyes = votes[v.epoch].votes.all!(_v => _v.verifyBullseye(net, votes[v.epoch].bullseye));
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
            req.id = epoch_number;
            epoch_contracts[req.id] = (() @trusted => new immutable(EpochContracts)(signed_contracts, epoch_time))();

            if (inputs.length == 0) {
                createRecorder(req.Response(req.msg, req.id), inputs);
                return;
            }

            (() @trusted => locate(task_names.dart).send(req, inputs))();

        }

        void receiveBullseye(dartModifyRR.Response res, Fingerprint bullseye) {
            import tagion.utils.Miscellaneous : cutHex;

            if (bullseye is Fingerprint.init) {
                return;
            }
            log("transcript received bullseye %s", bullseye.cutHex);

            auto epoch_number = res.id;
            ConsensusVoting own_vote = ConsensusVoting(
                    epoch_number,
                    net.pubkey,
                    net.sign(bullseye)
            );

            votes[epoch_number] = Votes(bullseye, epoch_number);

            // checkLeaks();
            locate(task_names.epoch_creator).send(Payload(), own_vote.toDoc);
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
