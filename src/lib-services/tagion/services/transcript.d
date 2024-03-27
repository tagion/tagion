/// Service for Transcript responsible for creating recorder for DART 
/// [DART Documentation](https://docs.tagion.org/docus/architecture/transcript)
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
import tagion.services.messages;
import tagion.services.options : TaskNames;
import tagion.services.exception;
import tagion.utils.JSONCommon;
import tagion.utils.StdTime;
import tagion.utils.pretend_safe_concurrency;
import std.process : thisProcessID;
import std.path : buildPath;
import std.file : exists;
import std.conv : to;
import tagion.logger.ContractTracker;

@safe:

shared static size_t graceful_shutdown;
enum BUFFER_TIME_SECONDS = 30;

struct TranscriptOptions {
    string shutdown_folder = "/tmp/";
    string shutdown_file_prefix = "epoch_shutdown_";
    mixin JSONCommon;
}

/**
 * TranscriptService actor
 * Receives: (inputDoc, Document)
 * Sends: (inputHiRPC, HiRPC.Receiver) to receiver_task, where Document is a correctly formatted HiRPC
**/
struct TranscriptService {

    const(SecureNet) net;
    immutable(TranscriptOptions) opts;
    immutable(size_t) number_of_nodes;

    ActorHandle dart_handle;
    ActorHandle epoch_creator_handle;
    ActorHandle trt_handle;

    bool trt_enable;
    const string process_file_name;
    const string process_file_path;

    RecordFactory rec_factory;

    this(immutable(TranscriptOptions) opts, const size_t number_of_nodes, shared(StdSecureNet) shared_net, immutable(TaskNames) task_names, bool trt_enable) {
        this.opts = opts;
        this.number_of_nodes = number_of_nodes;

        this.dart_handle = ActorHandle(task_names.dart);
        this.epoch_creator_handle = ActorHandle(task_names.epoch_creator);
        this.trt_handle = ActorHandle(task_names.trt);
        this.net = new StdSecureNet(shared_net);

        this.trt_enable = trt_enable;

        this.rec_factory = RecordFactory(net);

        this.process_file_name = format("%s%d", opts.shutdown_file_prefix, thisProcessID());
        this.process_file_path = buildPath(opts.shutdown_folder, process_file_name);
    }

    Votes[long] votes;
    immutable(ContractProduct)*[DARTIndex] products;
    const(EpochContracts)*[long] epoch_contracts;

    long shutdown;


    struct Votes {
        const(ConsensusVoting)[] votes;
        Epoch epoch;
        LockedArchives locked_archives;
    }

    struct EpochContracts {
        const(SignedContract)[] signed_contracts;
        sdt_t epoch_time;
    }

    void produceContract(producedContract, immutable(ContractProduct)* product) {
        log("received ContractProduct");
        logContractStatus(product.contract.sign_contract.contract, ContractStatusCode.produced, "Received produced contract");
        auto product_index = net.dartIndex(product.contract.sign_contract.contract);
        products[product_index] = product;
    }

    void receiveBullseye(dartModifyRR.Response res, Fingerprint bullseye) {
        import tagion.utils.Miscellaneous : cutHex;

        const epoch_number = res.id;

        votes[epoch_number].epoch.bullseye = bullseye;

        ConsensusVoting own_vote = ConsensusVoting(
                epoch_number,
                net.pubkey,
                net.sign(bullseye)
        );

        epoch_creator_handle.send(Payload(), own_vote.toDoc);
    }

    TagionGlobals last_globals = TagionGlobals(BigNumber(1000_000_000), BigNumber(0), long(
            10_0000), long(0));
    TagionHead last_head = TagionHead(TagionDomain, 0);

    Fingerprint previous_epoch = Fingerprint([1, 2, 3, 4]);
    long last_epoch_number = 0;
    long last_consensus_epoch = 0;

    void epoch(consensusEpoch,
        immutable(EventPackage*)[] epacks,
        immutable(long) epoch_number,
        const(sdt_t) epoch_time) @safe {
        last_epoch_number += 1;
        import tagion.utils.Term;

        log("%sEpoch round: %d time %s%s", BLUE, last_epoch_number, epoch_time, RESET);

        if (process_file_path.exists && shutdown is long.init) {
            // open the file and set the shutdown sig
            auto f = File(process_file_path, "r");
            scope (exit) {
                f.close;
            }
            shutdown = (() @trusted => f.byLine.front.to!long)();
        }
        if (shutdown !is long.init) {
            log("%sShutdown is scheduled for epoch %d%s", YELLOW, shutdown, RESET);

        }

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
        req.id = last_epoch_number;
        epoch_contracts[req.id] = new const EpochContracts(signed_contracts, epoch_time);

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

        /*
            The vote array is already updated. We must go through all the different vote indices and update the epoch that was stored in the dart if any new votes are found.
        */

        pragma(msg, "fixme(pr): instead of sorting each time there must be a better way for us to do this");
        foreach (v; votes.byKeyValue.array.sort!((a, b) => a.value.epoch.epoch_number < b
                .value.epoch.epoch_number)) {
            // add the new signatures to the epoch. We only want to do it if there are new signatures
            if (v.value.epoch.bullseye !is Fingerprint.init) {
                // add the signatures to the epoch. Only add them if the signature match ours
                foreach (single_vote; v.value.votes) {
                    // check that we have not already added the signature
                    if (v.value.epoch.signs.canFind(single_vote.signed_bullseye)) {
                        continue;
                    }
                    if (single_vote.verifyBullseye(net, v.value.epoch.bullseye)) {
                        v.value.epoch.signs ~= single_vote.signed_bullseye;
                    }
                    else {
                        import tagion.basic.ConsensusExceptions;

                        throw new ConsensusException(format("Bullseyes not the same on epoch %s", v
                                .value.epoch
                                .epoch_number));
                    }
                }

                // if the new length of the epoch is majority then we finish the epoch
                if (v.value.epoch.signs.length == number_of_nodes && v.value.epoch.epoch_number == last_consensus_epoch + 1) {
                    v.value.epoch.previous = previous_epoch;
                    previous_epoch = net.calcHash(v.value.epoch);
                    last_consensus_epoch += 1;
                    recorder.insert(v.value.epoch, Archive.Type.ADD);
                    recorder.insert(v.value.locked_archives, Archive.Type.REMOVE);
                    votes.remove(v.value.epoch.epoch_number);
                }

            }

        }

        if (shutdown !is long.init && last_consensus_epoch >= shutdown) {
            auto req = dartModifyRR();
            req.id = res.id;

            TagionHead new_head = TagionHead(
                TagionDomain,
                shutdown,
            );
            recorder.insert(new_head, Archive.Type.ADD);

            import core.atomic;

            dart_handle.send(req, RecordFactory.uniqueRecorder(recorder), cast(immutable) res
                    .id);
            graceful_shutdown.atomicOp!"+="(1);
            thisActor.stop = true;
            return;
        }

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

                if (trt_enable) {
                    immutable doc = signed_contract.contract.toDoc;
                    trt_handle.send(trtContract(), doc, last_epoch_number);
                }

                used ~= signed_contract.contract.inputs;
                products.remove(net.dartIndex(signed_contract.contract));
            }
            catch (Exception e) {
                log("Contract Exception %s", e);
                continue loop_signed_contracts;
            }
        }

        /*
        Since we write all inromation that is known immediately we create the epoch chain block here and make it empty.
        The following information can be added:
            epoch_number
            time
            active
            deactivate
            globals
        This will be added to thed DART. We also keep this in our cache in order to make the reads as few as possible.
        */
        Epoch non_voted_epoch;
        non_voted_epoch.epoch_number = res.id;
        non_voted_epoch.time = sdt_t(epoch_contract.epoch_time);
        // create the globals

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
        immutable(DARTIndex)[] locked_indices = recorder[]
            .filter!(a => a.type == Archive.Type.ADD)
            .map!(a => net.dartIndex(a.filed))
            .array;

        LockedArchives outputs = LockedArchives(res.id, locked_indices);

        if (shutdown is long.init || res.id < shutdown) {
            recorder.insert(new_head, Archive.Type.ADD);
            recorder.insert(non_voted_epoch, Archive.Type.ADD);
            recorder.insert(outputs, Archive.Type.ADD);
        }

        last_head = new_head;
        last_globals = new_globals;

        Votes new_vote;
        new_vote.epoch = non_voted_epoch;
        new_vote.locked_archives = outputs;
        votes[non_voted_epoch.epoch_number] = new_vote;

        auto req = dartModifyRR();
        req.id = res.id;

        dart_handle.send(req, RecordFactory.uniqueRecorder(recorder), cast(immutable) res.id);
    }

    void task() {
        log("PROCESS FILE PATH %s", process_file_path);

        {
            bool head_found;
            // start by reading the head
            immutable tagion_index = net.dartKey(StdNames.name, TagionDomain);
            dart_handle.send(dartReadRR(), [tagion_index]);
            log("SENDING HEAD REQUEST TO DART");

            receive((dartReadRR.Response _, immutable(RecordFactory.Recorder) head_recorder) {
                if (!head_recorder.empty) {
                    log("FOUND A TAGIONHEAD");
                    // yay we found a head!
                    last_head = TagionHead(head_recorder[].front.filed);
                    head_found = true;
                }
                else {
                    log("NO HEAD FOUND");
                    /* throw new ServiceError("Transcript booted without getting head"); */
                }

            });

            if (head_found) {
                // now we locate the epoch
                immutable epoch_index = net.dartKey(StdNames.epoch, last_head.current_epoch);
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
                        previous_epoch = Fingerprint(net.calcHash(doc));
                    }
                });
            }
        }
        log("Booting with globals: %s\n last_head: %s", last_globals.toPretty, last_head.toPretty);

        run(&epoch, &produceContract, &createRecorder, &receiveBullseye);
    }
}
