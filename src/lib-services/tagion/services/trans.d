module tagion.services.trans;

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
import tagion.services.messages;
import tagion.services.options : TaskNames;
import tagion.services.exception;
import tagion.json.JSONRecord;
import tagion.utils.StdTime;
import tagion.utils.pretend_safe_concurrency;
import std.path : buildPath;
import std.file : exists;
import std.conv : to;
import tagion.logger.ContractTracker;

enum BUFFER_TIME_SECONDS = 30;

struct TranscriptService {

    const(SecureNet) net;
    immutable(size_t) number_of_nodes;

    ActorHandle dart_handle;
    ActorHandle epoch_creator_handle;
    ActorHandle trt_handle;

    bool trt_enable;

    RecordFactory rec_factory;

    this(const size_t number_of_nodes, shared(StdSecureNet) shared_net, immutable(TaskNames) task_names, bool trt_enable) {
        this.number_of_nodes = number_of_nodes;

        this.dart_handle = ActorHandle(task_names.dart);
        this.epoch_creator_handle = ActorHandle(task_names.epoch_creator);
        this.trt_handle = ActorHandle(task_names.trt);
        this.net = new StdSecureNet(shared_net);

        this.trt_enable = trt_enable;

        this.rec_factory = RecordFactory(net.hash);
    }

    immutable(ContractProduct)*[DARTIndex] products;
    const(EpochContracts)*[long] epoch_contracts;

    TagionGlobals last_globals;
    TagionHead last_head;

    Fingerprint previous_epoch;
    long last_epoch_number;
    long last_consensus_epoch;

    struct EpochContracts {
        const(SignedContract)[] signed_contracts;
        immutable(Fingerprint)[] witnesses;
        sdt_t epoch_time;
    }

    struct Vote {
        const(ConsensusVoting)[] votes;
        RecordFactory.Recorder recorder;
        long epoch_number;
        Fingerprint future_bullseye;

    }

    Vote[long] votes;

    void produceContract(producedContract, immutable(ContractProduct)* product) {
        log("received ContractProduct");
        logContractStatus(product.contract.sign_contract.contract, ContractStatusCode.produced, "Received produced contract");
        auto product_index = net.hash.dartIndex(product.contract.sign_contract.contract);
        products[product_index] = product;
    }

    void epoch(consensusEpoch,
            immutable(EventPackage*)[] epacks,
            immutable(Fingerprint)[] witnesses,
            long epoch_number,
            const(sdt_t) epoch_time) @safe {
        last_epoch_number++;
        import tagion.utils.Term;

        log("%sEpoch round: %d time %s%s", BLUE, last_epoch_number, epoch_time, RESET);

        // check for votes. All other stuff will just be saved in an array. We will not process future epochs before the first one can be completely finished.
        immutable(ConsensusVoting)[] received_votes = epacks
            .filter!(epack => epack.event_body.payload.isRecord!ConsensusVoting)
            .map!(epack => immutable(ConsensusVoting)(epack.event_body.payload))
            .array;

        foreach (v; received_votes) {
            if (votes.get(v.epoch, Vote.init) !is Vote.init) {
                votes[v.epoch].votes ~= v;
            }
            else {
                log("VOTE IS INIT");
            }
        }
        // if the new number of votes is majority. We can allow further processing of the next epoch, and add the votes to the next epoch.

        auto signed_contracts = epacks
            .filter!(epack => epack.event_body.payload.isRecord!SignedContract)
            .map!(epack => immutable(SignedContract)(epack.event_body.payload))
            .array;

        auto inputs = signed_contracts
            .map!(signed_contract => signed_contract.contract.inputs)
            .join
            .array;

        auto req = dartCheckReadRR(id: last_epoch_number);
        epoch_contracts[req.id] = new const EpochContracts(signed_contracts, witnesses, epoch_time);

        if (inputs.length == 0) {
            createRecorder(req.Response(req.msg, req.id), inputs);
            return;
        }

        dart_handle.send(req, inputs);
    }

    void createRecorder(dartCheckReadRR.Response res, immutable(DARTIndex)[] not_in_dart) {

        DARTIndex[] used;

        auto recorder = rec_factory.recorder;
        used ~= not_in_dart;

        const epoch_contract = epoch_contracts.get(res.id, null);
        if (epoch_contract is null) {
            throw new ServiceException(format("unlinked epoch contract %s", res.id));
        }
        scope (exit) {
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

                const tvm_contract_outputs = products.get(net.hash.dartIndex(signed_contract.contract), null);
                if (tvm_contract_outputs is null) {
                    continue loop_signed_contracts;
                    log("contract not found asserting");
                }

                import core.time;
                import std.datetime;
                import tagion.utils.StdTime;

                const max_time = sdt_t((SysTime(cast(const long) epoch_contract.epoch_time) + BUFFER_TIME_SECONDS.seconds)
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
                products.remove(net.hash.dartIndex(signed_contract.contract));
            }
            catch (Exception e) {
                log("Contract Exception %s", e);
                continue loop_signed_contracts;
            }
        }

        WitnesHead withead;
        withead.witnesses = epoch_contract.witnesses;
        recorder.add(withead);

        Epoch non_voted_epoch;
        non_voted_epoch.epoch_number = res.id;
        non_voted_epoch.time = sdt_t(epoch_contract.epoch_time);

        BigNumber total = last_globals.total;
        BigNumber total_burned = last_globals.total_burned;
        long number_of_bills = last_globals.number_of_bills;
        long burnt_bills = last_globals.burnt_bills;

        void billStatistic(const(Archive) archive) {
            if (!archive.filed.isRecord!TagionBill) {
                return;
            }
            // log("GOING TO STAT BILL: %s, type: %s", bill.toPretty, archive.type;

            auto bill = TagionBill(archive.filed);

            if (archive.type == Archive.Type.REMOVE) {
                total -= bill.value.units;
                total_burned += bill.value.units;
                burnt_bills += 1;
                number_of_bills -= 1;
            }
            if (archive.type == Archive.Type.ADD) {
                total += bill.value.units;
                number_of_bills += 1;
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

        non_voted_epoch.previous = previous_epoch;
        previous_epoch = net.hash.calc(non_voted_epoch);
        last_consensus_epoch += 1;
        recorder.insert(non_voted_epoch, Archive.Type.ADD);

        // TODO: ADD PREVIOUS VOTES FROM PREVIOUS EPOCH HERE AND BULLSEYE

        Vote new_vote;
        new_vote.recorder = recorder.dup;
        votes[res.id] = new_vote;

        // we do not directly add the epoch here. Instead we calculate the future eye. Majority of the nodes then have to agree of this future eye before it is processed to the database. Until then no other epochs will be created / added.

        auto req = dartFutureEyeRR(res.id);
        dart_handle.send(req, RecordFactory.uniqueRecorder(recorder));
        // auto req = dartModifyRR(res.id);

    }

    void receiveFutureEye(dartFutureEyeRR.Response res, Fingerprint future_bullseye) {
        // add our own vote to the consensus vote
        const epoch_number = res.id;
        votes[epoch_number].future_bullseye = future_bullseye;

        ConsensusVoting own_vote = ConsensusVoting(
                epoch_number,
                net.pubkey,
                net.sign(future_bullseye),
        );

        epoch_creator_handle.send(Payload(), own_vote.toDoc);
        return;
    }

    void task() {
        {
            // start by reading the head
            immutable tagion_index = net.hash.dartId(HashNames.domain_name, TagionDomain);
            dart_handle.send(dartReadRR(), [tagion_index]);
            log("SENDING HEAD REQUEST TO DART");

            receive((dartReadRR.Response _, immutable(RecordFactory.Recorder) head_recorder) {
                if (!head_recorder.empty) {
                    log("FOUND A TAGIONHEAD");
                    // yay we found a head!
                    last_head = TagionHead(head_recorder[].front.filed);
                }
                else {
                    throw new ServiceError("Transcript booted without getting head");
                }
            });

            // now we locate the epoch
            immutable epoch_index = net.hash.dartId(HashNames.epoch, last_head.current_epoch);
            dart_handle.send(dartReadRR(), [epoch_index]);
            receive((dartReadRR.Response _, immutable(RecordFactory.Recorder) epoch_recorder) {
                if (!epoch_recorder.empty) {
                    auto doc = epoch_recorder[].front.filed;
                    if (doc.isRecord!Epoch) {
                        log("FOUND A EPOCH");
                        auto epoch = Epoch(doc);
                        last_epoch_number = epoch.epoch_number;
                        last_consensus_epoch = epoch.epoch_number;
                        last_globals = epoch.globals;
                    }
                    else if (doc.isRecord!GenesisEpoch) {
                        auto genesis_epoch = GenesisEpoch(doc);
                        last_epoch_number = genesis_epoch.epoch_number;
                        last_globals = genesis_epoch.globals;
                        log("FOUND A EPOCH");
                    }
                    else {
                        throw new ServiceError("The read epoch was not of type Epoch or GenesisEpoch");
                    }
                    previous_epoch = Fingerprint(net.hash.calc(doc));
                }
            });
        }
        log("Booting with globals: %s\n last_head: %s", last_globals.toPretty, last_head.toPretty);

        run(&epoch, &produceContract, &createRecorder, &receiveFutureEye);
    }

}
