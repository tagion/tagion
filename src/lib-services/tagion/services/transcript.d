// Service for transcript  
/// [Documentation](https://docs.tagion.org/#/documents/architecture/transcript)
module tagion.services.transcript;

@safe:

import std.stdio;
import std.exception;
import std.array;
import std.algorithm;
import std.range;
import std.format;
import core.time;

import tagion.logger.Logger;
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
import tagion.crypto.Types;
import tagion.script.standardnames;
import tagion.hibon.BigNumber;

import tagion.script.TagionCurrency;
import tagion.dart.DARTBasic;

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
        const(SecureNet) net = new StdSecureNet(shared_net);

        immutable(ContractProduct)*[DARTIndex] products;
        auto rec_factory = RecordFactory(net);

        struct Votes {
            const(ConsensusVoting)[] votes;
            long epoch;
            Fingerprint bullseye;
            this(Fingerprint bullseye, long epoch) pure {
                this.bullseye = bullseye;
                this.epoch = epoch;
            }
        }
        Votes[long] votes;

        struct EpochContracts {
            const(SignedContract)[] signed_contracts;
            sdt_t epoch_time;

            // Votes[] previous_votes;
        }

        const(EpochContracts)*[long] epoch_contracts;

        HiRPC hirpc = HiRPC(net);



        
        TagionHead last_head = TagionHead(TagionDomain, 0, TagionGlobals(null, BigNumber(1000_000_000), BigNumber(0), long(10_000), long(0)));
        Fingerprint previous_epoch = Fingerprint.init;
        long last_epoch_number = 0;


        
        {
            bool head_found;
            // start by reading the head
            immutable tagion_index = net.dartKey(StdNames.name, TagionDomain);
            locate(task_names.dart).send(dartReadRR(),[tagion_index]); 
            log("SENDING HEAD REQUEST TO DART");
             
            receiveTimeout(1.seconds, (dartReadRR.Response _, immutable(RecordFactory.Recorder) head_recorder) {
                if (!head_recorder.empty) {
                    log("FOUND A TAGIONHEAD");
                    // yay we found a head!
                    last_head = TagionHead(head_recorder[].front.filed);
                    head_found = true;
                }else {
                    log("NO HEAD FOUND");

                }

            }); 

            if (head_found) {
            // now we locate the epoch
                immutable epoch_index = net.dartKey(StdNames.epoch, last_head.current_epoch);
                locate(task_names.dart).send(dartReadRR(),[epoch_index]); 
                receiveTimeout(1.seconds, (dartReadRR.Response _, immutable(RecordFactory.Recorder) epoch_recorder) {
                    if (!epoch_recorder.empty) {
                        auto doc = epoch_recorder[].front.filed;
                        if (doc.isRecord!Epoch) {
                            last_epoch_number = Epoch(doc).epoch_number;
                        } 
                        else if(doc.isRecord!GenesisEpoch) {
                            last_epoch_number = GenesisEpoch(doc).epoch_number;
                        } 
                        else {
                            log("THROWING EXCEPTION");
                            throw new Exception("The read epoch was not of type Epoch or GenesisEpoch");
                        }
                        previous_epoch = Fingerprint(net.calcHash(doc));
                    }
                }); 
            }
        }
        



        


        void createRecorder(dartCheckReadRR.Response res, immutable(DARTIndex)[] not_in_dart) {
            log("received response from dart %s", not_in_dart);

            DARTIndex[] used;

            auto recorder = rec_factory.recorder;
            used ~= not_in_dart;

            // check the votes here instead
            // get a list of all epochs where majority of votes with correct signature have been received

            import tagion.hashgraph.HashGraphBasic : isMajority;


            // find the consensus epochs
            auto aggregated_votes = votes
                .byKeyValue
                .filter!(v => v.value.votes.length.isMajority(number_of_nodes))
                .filter!(v => v.value.votes
                            .filter!(consensus_vote => consensus_vote.verifyBullseye(net, v.value.bullseye))
                            .walkLength
                            .isMajority(number_of_nodes)
                        ).array
                .sort!((a,b) => a.value.epoch < b.value.epoch);
            // clean up the arrays on exit
            scope(exit) {
                foreach(a_vote; aggregated_votes) {
                    votes.remove(a_vote.value.epoch);
                    epoch_contracts.remove(a_vote.value.epoch);
                }
            }

            // create the epochs. Sort them by epoch number so that we can create the previous link
            Epoch[] consensus_epochs;
            loop_epochs: foreach(a_vote; aggregated_votes) {
                auto previous_epoch_contract = epoch_contracts.get(a_vote.value.epoch, null);

                if (previous_epoch_contract is null) {
                    log("UNLINKED EPOCH_CONTRACT %s", a_vote.value.epoch);
                    continue loop_epochs;
                }

                // update the last epoch number
                Pubkey[] keys = [Pubkey([1,2,3,4])];
                // create the epoch;
                auto new_epoch = Epoch(a_vote.value.epoch, 
                                    sdt_t(previous_epoch_contract.epoch_time), 
                                    a_vote.value.bullseye, 
                                    previous_epoch, 
                                    a_vote.value.votes.map!(v => v.signed_bullseye).array,
                                    keys, 
                                    keys);
                consensus_epochs ~= new_epoch, 
                last_epoch_number = a_vote.value.epoch;
                previous_epoch = net.calcHash(new_epoch);
            }
            log("EPOCH_CONTRACTS: %s, consensus_epochs %s agg_votes: %s votes: %s", epoch_contracts.length, consensus_epochs.length, aggregated_votes.length, votes.length);

            /*
                Add the epochs to the recorder. We can assume that there will be multiple epochs due
                to the hashgraph being asynchronous.
            */
            // recorder.insert(consensus_epochs, Archive.Type.ADD);



            const epoch_contract = epoch_contracts.get(res.id, null);
            if (epoch_contract is null) {
                throw new Exception(format("unlinked epoch contract %s", res.id));
            }

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

            // BigNumber total = last_head.globals.total;
            // long number_of_bills = last_head.global.number_of_bills;

            // void billStatistic(const(Archive) archive) {
            //     if (!archive.filed.isRecord!TagionBill) {
            //         return;
            //     }
            //     auto bill = TagionBill(archive.filed);

            //     if (archive.Type.REMOVE) {
            //         total -= bill.value;
            //         number_of_bills--;
            //     }
            //     if (archive.Type.ADD) {
            //         total += bill.value;
            //         number_of_bills++;
            //     }
            // }
            // recorder[].each!(a => billStatistic(a));

            // TagionGlobals new_globals = TagionGlobals(
            //     Fingerprint[].init,
            //     total,
            //     number_of_bills,
                
            // )


        

            
            // // create the tagionhead and globals.
            // long number_of_new_bills = recorder[]
            //     .filter!(d => d.filed.isRecord!(TagionBill))
            //     .


            auto req = dartModifyRR();
            req.id = res.id;

            locate(task_names.dart).send(req, RecordFactory.uniqueRecorder(recorder), cast(immutable) res.id);

        }

        void epoch(consensusEpoch, immutable(EventPackage*)[] epacks, immutable(long) epoch_number, const(sdt_t) epoch_time) @safe {

            immutable(ConsensusVoting)[] received_votes = epacks
                .filter!(epack => epack.event_body.payload.isRecord!ConsensusVoting)
                .map!(epack => immutable(ConsensusVoting)(epack.event_body.payload))
                .array;

            // add them to the vote array
            foreach (v; received_votes) {
                if (votes.get(v.epoch, Votes.init) !is Votes.init) {
                    votes[v.epoch].votes ~= v;
                } else {
                    log("VOTE IS INIT %s", v.epoch);
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
            req.id = epoch_number;
            epoch_contracts[req.id] = new const EpochContracts(signed_contracts, epoch_time);

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
