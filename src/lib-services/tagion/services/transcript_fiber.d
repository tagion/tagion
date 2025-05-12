module tagion.services.transcript_fiber;

@safe:

import std.algorithm;
import std.array;
import std.format;

import tagion.actor;
import tagion.crypto.Types;
import tagion.crypto.SecureNet;
import tagion.dart.DARTBasic;
import tagion.dart.Recorder;
import tagion.hashgraph.HashGraphBasic;
import tagion.hibon.BigNumber;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.logger;
import tagion.logger.ContractTracker;
import tagion.script.common;
import tagion.script.execute;
import tagion.script.standardnames;
import tagion.services.tasknames;
import tagion.services.messages;
import tagion.services.exception;
import tagion.utils.Term;
import tagion.utils.StdTime;
import conc = tagion.utils.pretend_safe_concurrency;

private enum BUFFER_TIME_SECONDS = 30;

struct TranscriptService {
    const(SecureNet) net;
    const(size_t) number_of_nodes;

    ActorHandle dart_handle;
    ActorHandle epoch_creator_handle;
    ActorHandle epoch_commit_handle;

    RecordFactory rec_factory;

    this(const size_t number_of_nodes, shared(SecureNet) shared_net, immutable(TaskNames) task_names) {
        this.number_of_nodes = number_of_nodes,
        this.net = shared_net.clone;

        this.dart_handle = ActorHandle(task_names.dart);
        this.epoch_creator_handle = ActorHandle(task_names.epoch_creator);
        this.epoch_commit_handle = ActorHandle(task_names.epoch_commit);

        this.rec_factory = RecordFactory(net.hash);
    }

    immutable(ContractProduct)*[DARTIndex] products;

    void produceContract(producedContract, immutable(ContractProduct)* product) {
        logContractStatus(product.contract.sign_contract.contract, ContractStatusCode.produced, "Received produced contract");
        auto product_index = net.hash.dartIndex(product.contract.sign_contract.contract);
        products[product_index] = product;
    }

    long shutdown;
    void epoch_shutdown(EpochShutdown, long shutdown_) {
        shutdown = shutdown_;
    }

    TagionGlobals last_globals;
    TagionHead last_head;
    Fingerprint previous_epoch;
    long last_epoch_number;
    long last_consensus_epoch;

    static struct Votes {
        const(ConsensusVoting)[] votes;
        Epoch epoch;
        LockedArchives locked_archives;
    }

    void epoch(consensusEpoch,
            immutable(EventPackage*)[] epacks,
            immutable(Fingerprint)[] witnesses,
            long epoch_number,
            const(sdt_t) epoch_time) {
        last_epoch_number++;
        log("%sEpoch round: %d time %s%s", BLUE, last_epoch_number, epoch_time, RESET);
        if (shutdown !is long.init) {
            log("%sShutdown is scheduled for epoch %d%s", YELLOW, shutdown, RESET);
        }

        immutable(ConsensusVoting)[] received_votes = epacks
            .filter!(epack => epack.event_body.payload.isRecord!ConsensusVoting)
            .map!(epack => immutable(ConsensusVoting)(epack.event_body.payload))
            .array;

        Votes[long] votes;
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

        DARTIndex[] used;
        if(!inputs.empty) {
            // Make sure that alle of the inputs in the contract are still in the dart.
            dart_handle.send(dartCheckReadRR(last_epoch_number), inputs);
            conc.receive((dartCheckReadRR.Response _, immutable(DARTIndex)[] not_in_dart) {
                    used ~= not_in_dart;
            });
        }
        else {
            used ~= inputs;
        }

        auto recorder = rec_factory.recorder;
        
        foreach (epoch_votes; votes.byValue.array.sort!((a, b) => a.epoch.epoch_number < b.epoch.epoch_number)) {
            // add the new signatures to the epoch. We only want to do it if there are new signatures
            if (epoch_votes.epoch.bullseye !is Fingerprint.init) {
                // add the signatures to the epoch. Only add them if the signature match ours
                foreach (single_vote; epoch_votes.votes) {
                    // check that we have not already added the signature
                    if (epoch_votes.epoch.signs.canFind(single_vote.signed_bullseye)) {
                        continue;
                    }
                    if (single_vote.verifyBullseye(net, epoch_votes.epoch.bullseye)) {
                        epoch_votes.epoch.signs ~= single_vote.signed_bullseye;
                    }
                    else {
                        import tagion.errors.ConsensusExceptions;

                        throw new ConsensusException(format("Bullseyes not the same on epoch %s",
                                epoch_votes.epoch.epoch_number));
                    }
                }

                // if the new length of the epoch is majority then we finish the epoch
                if (epoch_votes.epoch.signs.length == number_of_nodes && epoch_votes.epoch.epoch_number == last_consensus_epoch + 1) {
                    epoch_votes.epoch.previous = previous_epoch;
                    previous_epoch = net.hash.calc(epoch_votes.epoch);
                    last_consensus_epoch += 1;
                    recorder.insert(epoch_votes.epoch, Archive.Type.ADD);
                    recorder.insert(epoch_votes.locked_archives, Archive.Type.REMOVE);
                    votes.remove(epoch_votes.epoch.epoch_number);
                }
            }
        }

        if (shutdown !is long.init && last_consensus_epoch >= shutdown) {
            TagionHead new_head = TagionHead(
                    TagionDomain,
                    shutdown,
            );
            recorder.insert(new_head, Archive.Type.ADD);

            auto req = EpochCommitRR(epoch_number);
            epoch_commit_handle.send(req, immutable(long)(epoch_number), RecordFactory.uniqueRecorder(recorder), signed_contracts);
            conc.prioritySend(conc.ownerTid, Sig.STOP);
            thisActor.stop = true;
            return;
        }

        loop_signed_contracts:
        foreach (signed_contract; signed_contracts) {
            try {
                foreach (input; signed_contract.contract.inputs) {
                    if (used.canFind(input)) {
                        log("input already in used list");
                        continue loop_signed_contracts;
                    }
                }

                const tvm_contract_outputs = products.get(net.hash.dartIndex(signed_contract.contract), null);
                if (tvm_contract_outputs is null) {
                    log("contract not found asserting");
                    continue loop_signed_contracts;
                }

                import core.time;
                import std.datetime;
                import tagion.utils.StdTime;

                const max_time = sdt_t((SysTime(cast(const long) epoch_time) + BUFFER_TIME_SECONDS.seconds)
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
        
        // Update the newest witness fingeprints
        WitnesHead withead;
        withead.witnesses = witnesses;
        recorder.add(withead);

        /*
        Update the Epoch chain 
        Since we write all inromation that is known immediately we create the epoch chain block here and make it empty.
        The following information can be added:
            epoch_number
            time
            active
            deactivate
            globals
        This will be added to the DART. We also keep this in our cache in order to make the reads as few as possible.
        */
        Epoch non_voted_epoch;
        non_voted_epoch.epoch_number = epoch_number;
        non_voted_epoch.time = sdt_t(epoch_time);

        // Update bill statistics
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
                epoch_number,
        );

        immutable(DARTIndex)[] locked_indices = recorder[]
            .filter!(a => a.type == Archive.Type.ADD)
            .map!(a => net.hash.dartIndex(a.filed))
            .array;

        LockedArchives outputs = LockedArchives(epoch_number, locked_indices);

        if (shutdown is long.init || epoch_number < shutdown) {
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

        auto req = EpochCommitRR();
        epoch_commit_handle.send(req, immutable(long)(epoch_number), RecordFactory.uniqueRecorder(recorder), signed_contracts);
        conc.receive((EpochCommitRR.Response res, Fingerprint bullseye) {
                assert(res.id == req.id);
                votes[epoch_number].epoch.bullseye = bullseye;
                ConsensusVoting own_vote = ConsensusVoting(
                        epoch_number,
                        net.pubkey,
                        net.sign(bullseye)
                );
                epoch_creator_handle.send(Payload(), own_vote.toDoc);
        });

    }


    void task() {
        // start by reading the head
        immutable tagion_index = net.hash.dartId(HashNames.domain_name, TagionDomain);
        dart_handle.send(dartReadRR(), [tagion_index]);
        log("SENDING HEAD REQUEST TO DART");

        conc.receive((dartReadRR.Response _, immutable(RecordFactory.Recorder) head_recorder) {
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
        conc.receive((dartReadRR.Response _, immutable(RecordFactory.Recorder) epoch_recorder) {
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
        log("Booting with globals: %s\n last_head: %s", last_globals.toPretty, last_head.toPretty);
        // TODO request head
        // TODO locate epoch

        run(&epoch, &produceContract, &epoch_shutdown);
        /* auto scheduler = new conc.FiberScheduler(); */
        /* conc.scheduler_start(scheduler, { */
        /*     run(&epoch, &produceContract, &epoch_shutdown); */
        /* }); */
    }
}
