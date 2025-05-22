/// Service for Transcript responsible for creating recorder for DART 
/// [DART Documentation](https://docs.tagion.org/tech/architecture/transcript)
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
import tagion.json.JSONRecord;
import tagion.utils.StdTime;
import tagion.utils.pretend_safe_concurrency;
import std.path : buildPath;
import std.file : exists;
import std.conv : to;
import tagion.logger.ContractTracker;

enum BUFFER_TIME_SECONDS = 30;

/**
 * TranscriptService actor
 * Receives: (inputDoc, Document)
 * Sends: (inputHiRPC, HiRPC.Receiver) to receiver_task, where Document is a correctly formatted HiRPC
**/
struct TranscriptService {

    const(SecureNet) net;
    immutable(size_t) number_of_nodes;

    ActorHandle dart_handle;
    ActorHandle epoch_creator_handle;
    ActorHandle epoch_commit_handle;

    RecordFactory rec_factory;

    this(const size_t number_of_nodes, shared(SecureNet) shared_net, immutable(TaskNames) task_names) {
        this.number_of_nodes = number_of_nodes;

        this.dart_handle = ActorHandle(task_names.dart);
        this.epoch_creator_handle = ActorHandle(task_names.epoch_creator);
        this.epoch_commit_handle = ActorHandle(task_names.epoch_commit);
        this.net = shared_net.clone;
        this.rec_factory = RecordFactory(net.hash);
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
        immutable(SignedContract)[] signed_contracts;
        Fingerprint[] witnesses;
        sdt_t epoch_time;
    }

    void produceContract(producedContract, immutable(ContractProduct)* product) {
        log("received ContractProduct");
        logContractStatus(product.contract.sign_contract.contract, ContractStatusCode.produced, "Received produced contract");
        auto product_index = net.hash.dartIndex(product.contract.sign_contract.contract);
        products[product_index] = product;
    }

    void receiveBullseye(EpochCommitRR.Response res, Fingerprint bullseye, Fingerprint block_fingerprint) {
        const epoch_number = res.id;

        votes[epoch_number].epoch.bullseye = bullseye;

        ConsensusVoting own_vote = ConsensusVoting(
                epoch_number,
                net.pubkey,
                net.sign(bullseye)
        );

        epoch_creator_handle.send(Payload(), own_vote.toDoc);
    }

    TagionGlobals last_globals;
    TagionHead last_head;

    Fingerprint previous_epoch;
    long last_epoch_number;
    long last_consensus_epoch;

    void epoch_shutdown(EpochShutdown, long shutdown_) {
        shutdown = shutdown_;
    }

    void epoch(consensusEpoch,
            immutable(EventPackage*)[] epacks,
            immutable(Fingerprint)[] witnesses,
            long epoch_number,
            const(sdt_t) epoch_time) @safe {
        last_epoch_number++;
        import tagion.utils.Term;

        log("%sEpoch round: %d time %s%s", BLUE, last_epoch_number, epoch_time, RESET);

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
                        import tagion.errors.ConsensusExceptions;

                        throw new ConsensusException(format("Bullseyes not the same on epoch %s", v
                                .value.epoch
                                .epoch_number));
                    }
                }

                // if the new length of the epoch is majority then we finish the epoch
                if (v.value.epoch.signs.length == number_of_nodes && v.value.epoch.epoch_number == last_consensus_epoch + 1) {
                    v.value.epoch.previous = previous_epoch;
                    previous_epoch = net.hash.calc(v.value.epoch);
                    last_consensus_epoch += 1;
                    recorder.insert(v.value.epoch, Archive.Type.ADD);
                    recorder.insert(v.value.locked_archives, Archive.Type.REMOVE);
                    votes.remove(v.value.epoch.epoch_number);
                }

            }

        }

        const epoch_contract = epoch_contracts.get(res.id, null);
        if (epoch_contract is null) {
            throw new ServiceException(format("unlinked epoch contract %s", res.id));
        }
        scope (exit) {
            epoch_contracts.remove(res.id);
        }

        if (shutdown !is long.init && last_consensus_epoch >= shutdown) {
            TagionHead new_head = TagionHead(
                    TagionDomain,
                    shutdown,
            );
            recorder.insert(new_head, Archive.Type.ADD);

            auto req = EpochCommitRR(res.id);
            epoch_commit_handle.send(req, res.id, RecordFactory.uniqueRecorder(recorder), epoch_contract.signed_contracts);
            ownerTid.prioritySend(Sig.STOP);
            thisActor.stop = true;
            return;
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

        /*
        Since we write all information that is known immediately we create the epoch chain block here and make it empty.
        The following information can be added:
            epoch_number
            time
            active
            deactivate
            globals
        This will be added to the DART. We also keep this in our cache in order to make the reads as few as possible.
        */
        Epoch non_voted_epoch;
        non_voted_epoch.epoch_number = res.id;
        non_voted_epoch.time = sdt_t(epoch_contract.epoch_time);

        // create the globals
        TagionGlobals new_globals = bill_statistics(recorder, last_globals);

        non_voted_epoch.globals = new_globals;

        TagionHead new_head = TagionHead(
                TagionDomain,
                res.id,
        );

        immutable(DARTIndex)[] locked_indices = recorder[]
            .filter!(a => a.type == Archive.Type.ADD)
            .map!(a => net.hash.dartIndex(a.filed))
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

        auto req = EpochCommitRR(res.id);
        epoch_commit_handle.send(req, res.id, RecordFactory.uniqueRecorder(recorder), epoch_contract.signed_contracts);
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
                        throw new ServiceError(
                            "The read epoch was not of type Epoch or GenesisEpoch");
                    }
                    previous_epoch = Fingerprint(net.hash.calc(doc));
                }
            });
        }
        log("Booting with globals: %s\n last_head: %s", last_globals.toPretty, last_head.toPretty);

        run(&epoch, &produceContract, &createRecorder, &receiveBullseye, &epoch_shutdown);
    }
}

// The bill statistic aggregates the information about the amount of bills and the total value of bills to the new statistic block
// It's job is not to check that aggregated amount is legal
TagionGlobals bill_statistics(RecordFactory.Recorder recorder, const TagionGlobals prev_globals) pure {
    TagionGlobals new_globals = prev_globals;

    foreach(const archive; recorder[]) {
        if (!archive.filed.isRecord!TagionBill) {
            continue;
        }

        auto bill = TagionBill(archive.filed);

        if (archive.type == Archive.Type.REMOVE) {
            new_globals.total -= bill.value.units;
            new_globals.total_burned += bill.value.units;
            new_globals.burnt_bills += 1;
            new_globals.number_of_bills -= 1;
        }
        if (archive.type == Archive.Type.ADD) {
            new_globals.total += bill.value.units;
            new_globals.number_of_bills += 1;
        }
    }
    return new_globals;
}

unittest {
    import tagion.basic.Types;
    RecordFactory factory = RecordFactory(hash_net);
    TagionGlobals globals = TagionGlobals(BigNumber(720), BigNumber(13), 8, 20);
    { // + 1 bill 
        TagionGlobals old_globals = globals;
        auto recorder = factory.recorder;
        // The time and public key is not important for the statistic
        recorder.insert(TagionBill(14.TGN, sdt_t(0), Pubkey.init, Buffer.init), Archive.Type.ADD);
        auto new_globals = bill_statistics(recorder, old_globals);
        assert(new_globals.total == BigNumber(720 + 14 * TagionCurrency.BASE_UNIT));
        assert(new_globals.total_burned == BigNumber(13));
        assert(new_globals.number_of_bills == 9);
        assert(new_globals.burnt_bills == 20);
    }
    { // - 1 bill 
        TagionGlobals old_globals = globals;
        auto recorder = factory.recorder;
        // The time and public key is not important for the statistic
        recorder.insert(TagionBill(14.TGN, sdt_t(0), Pubkey.init, Buffer.init), Archive.Type.REMOVE);
        auto new_globals = bill_statistics(recorder, old_globals);
        assert(new_globals.total == BigNumber(720 - 14 * TagionCurrency.BASE_UNIT));
        assert(new_globals.total_burned == BigNumber(13 + 14 * TagionCurrency.BASE_UNIT));
        assert(new_globals.number_of_bills == 7);
        assert(new_globals.burnt_bills == 21);
    }
    { // None bill
        TagionGlobals old_globals = globals;
        auto recorder = factory.recorder;
        // Anything than is not a bill should leave the statistic unchanged
        recorder.insert(PayScript([TagionBill(10.TGN, sdt_t(5), Pubkey.init, Buffer.init)]), Archive.Type.ADD);
        recorder.insert(PayScript([TagionBill(7.TGN, sdt_t(5), Pubkey.init, Buffer.init)]), Archive.Type.NONE);
        recorder.insert(PayScript([TagionBill(16.TGN, sdt_t(5), Pubkey.init, Buffer.init)]), Archive.Type.REMOVE);
        auto new_globals = bill_statistics(recorder, old_globals);
        assert(new_globals.total == old_globals.total);
        assert(new_globals.total_burned == old_globals.total_burned);
        assert(new_globals.number_of_bills == old_globals.number_of_bills);
        assert(new_globals.burnt_bills == old_globals.burnt_bills);
    }
}
