// Service for transcript  
/// [Documentation](https://docs.tagion.org/#/documents/architecture/transcript)
module tagion.services.transcript;

@safe:

import core.time;
import std.algorithm;
import std.array;
import std.exception;
import std.format;
import std.range;
import std.stdio;
import tagion.actor.actor;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet;
import tagion.crypto.Types;
import tagion.dart.DARTBasic : DARTIndex, dartIndex;
import tagion.dart.DARTBasic;
import tagion.dart.Recorder;
import tagion.hashgraph.HashGraphBasic : EventPackage, isMajority;
import tagion.hibon.BigNumber;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : HiBONRecord, isRecord;
import tagion.logger.Logger;
import tagion.logger.Logger;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.execute : ContractProduct;
import tagion.script.standardnames;
import tagion.services.locator;
import tagion.services.messages;
import tagion.services.options;
import tagion.services.options : TaskNames;
import tagion.utils.JSONCommon;
import tagion.utils.StdTime;
import tagion.utils.pretend_safe_concurrency;

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
    void task(immutable(TranscriptOptions) opts, immutable(size_t) number_of_nodes, shared(StdSecureNet) shared_net, immutable(
            TaskNames) task_names) {
        const(SecureNet) net = new StdSecureNet(shared_net);

        immutable(ContractProduct)*[DARTIndex] products;
        auto rec_factory = RecordFactory(net);

        struct Votes {
            const(ConsensusVoting)[] votes;
            bool init_bullseye;
            Epoch epoch;
        }

        Votes[long] votes;

        struct EpochContracts {
            const(SignedContract)[] signed_contracts;
            sdt_t epoch_time;

            // Votes[] previous_votes;
        }

        const(EpochContracts)*[long] epoch_contracts;

        HiRPC hirpc = HiRPC(net);




        /** 
         * Get the current head and epoch
         */
        TagionGlobals last_globals = TagionGlobals(BigNumber(1000_000_000), BigNumber(0), long(10_0000), long(0));
        TagionHead last_head = TagionHead(TagionDomain, 0);
        
        Fingerprint previous_epoch = Fingerprint.init;
        long last_epoch_number = 0;

        {
            bool head_found;
            // start by reading the head
            immutable tagion_index = net.dartKey(StdNames.name, TagionDomain);
            auto dart_tid = tryLocate(task_names.dart);
            dart_tid.send(dartReadRR(), [tagion_index]);
            log("SENDING HEAD REQUEST TO DART");

            auto received = receiveTimeout(1.seconds, (dartReadRR.Response _, immutable(RecordFactory.Recorder) head_recorder) {
                if (!head_recorder.empty) {
                    log("FOUND A TAGIONHEAD");
                    // yay we found a head!
                    last_head = TagionHead(head_recorder[].front.filed);
                    head_found = true;
                }
                else {
                    log("NO HEAD FOUND");

                }

            });
            if (!received) {
                throw new Exception("Never received a tagionhead");

            }

            if (head_found) {
                // now we locate the epoch
                immutable epoch_index = net.dartKey(StdNames.epoch, last_head.current_epoch);
                dart_tid.send(dartReadRR(), [epoch_index]);
                receiveTimeout(1.seconds, (dartReadRR.Response _, immutable(RecordFactory.Recorder) epoch_recorder) {
                    if (!epoch_recorder.empty) {
                        auto doc = epoch_recorder[].front.filed;
                        if (doc.isRecord!Epoch) {
                            auto epoch = Epoch(doc);
                            last_epoch_number = epoch.epoch_number;
                            last_globals = epoch.globals;
                        }
                        else if (doc.isRecord!GenesisEpoch) {
                            auto genesis_epoch = GenesisEpoch(doc);
                            last_epoch_number = genesis_epoch.epoch_number;
                            last_globals = genesis_epoch.globals;
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

            DARTIndex[] used;

            auto recorder = rec_factory.recorder;
            used ~= not_in_dart;



            /*
                The vote array is already updated. We must go through all the different vote indices and update the epoch that was stored in the dart if any new votes are found.
            */
            log("VOTES LENGTH BEFORE=%s", votes.byKey.array);
            foreach(v; votes.byKeyValue) {
                // add the new signatures to the epoch. We only want to do it if there are new signatures
                if (v.value.init_bullseye || v.value.epoch.signs.length != v.value.votes.length) {
                    v.value.init_bullseye = false;
                    // add the signatures to the epoch. Only add them if the signature match ours
                    foreach(single_vote; v.value.votes) {
                        // check that we have not already added the signature
                        if (v.value.epoch.signs.canFind(single_vote.signed_bullseye)) {
                            continue;
                        }
                        if (single_vote.verifyBullseye(net, v.value.epoch.bullseye)) {
                            v.value.epoch.signs ~= single_vote.signed_bullseye;
                        }
                        else {
                            pragma(msg, "throw error or what should we do?");
                            // throw error or what to do
                        }
                    }

                    // if the new length of the epoch is majority then we finish the epoch
                    if (v.value.epoch.signs.length.isMajority(number_of_nodes)) {
                        v.value.epoch.previous = previous_epoch;
                        previous_epoch = net.calcHash(v.value.epoch);
                        votes.remove(v.value.epoch.epoch_number);
                    }

                    // add the modified epochs to the recorder.
                    recorder.insert(v.value.epoch, Archive.Type.ADD);
                }

            }
            log("VOTES LENGTH AFTER=%s", votes.length);



            

            
            const epoch_contract = epoch_contracts.get(res.id, null);
            if (epoch_contract is null) {
                throw new Exception(format("unlinked epoch contract %s", res.id));
            }
            scope(exit) {
                epoch_contracts.remove(res.id);
            }

            loop_signed_contracts: foreach (signed_contract; epoch_contract.signed_contracts) {
                try {
                    foreach (input; signed_contract.contract.inputs) {
                        if (used.canFind(input)) {
                            log("input already in used list");
                            continue loop_signed_contracts;
                        }
                    }

                    const tvm_contract_outputs = products.get(net.dartIndex(signed_contract.contract), null);
                    if (tvm_contract_outputs is null) {
                        continue loop_signed_contracts;
                        log("contract not found asserting");
                    }

                    import core.time;
                    import std.datetime;
                    import tagion.utils.StdTime;

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
                catch (Exception e) {
                    log("Contract Exception %s", e);
                    continue loop_signed_contracts;
                }
            }

            /*
            Since we write all inromation that is known immediatly we create the epoch chain block here and make it empty.
            The following information can be added:
                epoch_number
                time
                active
                deactive
                globals
            This will be added to thed DART. We also keep this in our cache in order to make the reads as few as possible.
            */
            Epoch non_voted_epoch;
            non_voted_epoch.epoch_number = res.id;
            non_voted_epoch.time = sdt_t(epoch_contract.epoch_time);
            non_voted_epoch.bullseye = Fingerprint.init;
            non_voted_epoch.previous = Fingerprint.init;
            non_voted_epoch.signs = Signature[].init;

            // create the globals

            BigNumber total = last_globals.total;
            BigNumber total_burned = last_globals.total_burned;
            long number_of_bills = last_globals.number_of_bills;
            long burnt_bills = last_globals.burnt_bills;

            void billStatistic(const(Archive) archive) {
                if (!archive.filed.isRecord!TagionBill) {
                    return;
                }
                auto bill = TagionBill(archive.filed);

                if (archive.Type.REMOVE) {
                    total -= bill.value.axios;
                    total_burned += bill.value.axios;
                    burnt_bills++;
                    number_of_bills--;
                }
                if (archive.Type.ADD) {
                    total += bill.value.axios;
                    number_of_bills++;
                    number_of_bills++;
                }
            }

            recorder[].each!(a => billStatistic(a));

            TagionGlobals new_globals = TagionGlobals(
                    total,
                    total_burned,
                    number_of_bills,
                    burnt_bills,
            );
            non_voted_epoch.globals = new_globals;

            TagionHead new_head = TagionHead(
                TagionDomain,
                res.id,
            );
            last_head = new_head;
            last_globals = new_globals;
            recorder.insert(new_head, Archive.Type.ADD);
            recorder.insert(non_voted_epoch, Archive.Type.ADD);

            Votes new_vote;
            new_vote.epoch = non_voted_epoch;

            votes[non_voted_epoch.epoch_number] = new_vote;

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
                }
                else {
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

            log("transcript received bullseye %s", bullseye.cutHex);
            const epoch_number = res.id;

            votes[epoch_number].epoch.bullseye = bullseye;
            votes[epoch_number].init_bullseye = true;

            ConsensusVoting own_vote = ConsensusVoting(
                epoch_number,
                net.pubkey,
                net.sign(bullseye)
            );

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
