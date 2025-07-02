module tagion.services.DARTSyncService;

import std.exception : enforce, assumeUnique;
import std.format;
import std.file;
import std.path : baseName, buildPath, dirName, setExtension, stripExtension;
import std.range;
import std.stdio;
import std.typecons;
import core.time;
import core.thread;
import core.memory : pageSize;
import nngd;

import tagion.services.DART : DARTOptions, DARTService;
import tagion.services.options : TaskNames, contract_sock_addr;
import tagion.services.messages;
import tagion.crypto.SecureNet;
import tagion.crypto.Types : Fingerprint, Pubkey;
import tagion.dart.DART;
import tagion.dart.DARTcrud : dartBullseye;
import tagion.dart.DARTSynchronizer;
import tagion.dart.synchronizer;
import tagion.dart.DARTBasic : DARTIndex, Params;
import tagion.dart.DARTRim;
import tagion.dart.BlockFile : BlockFile, BLOCK_SIZE;
import tagion.actor;
import tagion.hibon.Document;
import tagion.hibon.HiBONException;
import tagion.json.JSONRecord;
import tagion.Keywords;
import tagion.utils.Term;
import tagion.utils.pretend_safe_concurrency : receive, receiveOnly;
import tagion.communication.HiRPC : HiRPC;
import tagion.logger.Logger;
import tagion.gossip.AddressBook;
import tagion.dart.DARTSynchronizationFiber;

@safe:

struct JournalOptions {
    string journal_path;

    void setPrefix(string prefix) nothrow {
        journal_path = prefix ~ journal_path;
    }

    mixin JSONRecord;
}

struct DARTSyncService {

    struct ReplayFiles {
        string[] files;
    }

    void task(
        string journal_path,
        shared(SecureNet) shared_net,
        string dst_dart_path,
        shared(AddressBook) addressbook,
        immutable(TaskNames) task_names,
    ) {
        import tagion.services.options;
        import tagion.services.nodeinterface;

        if (journal_path.exists) {
            journal_path.rmdirRecurse;
        }
        journal_path.mkdirRecurse;

        enforce(dst_dart_path.exists, "DART does not exist");
        auto net = shared_net.clone;
        auto dest_db = new DART(net.hash, dst_dart_path);

        ActorHandle handle = ActorHandle(task_names.node_interface);

        void compareTask(dartCompareRR req) {
            immutable result = bullseyesMatch(net, addressbook, handle, dest_db);
            req.respond(result);
        }

        void synchronizeTask(dartSyncRR req) {
            immutable journal_filenames = synchronize(journal_path, addressbook, task_names, dest_db);
            req.respond(journal_filenames);
        }

        void replayTask(dartReplayRR req, immutable(ReplayFiles) files) {
            replayWithFiles(dest_db, files);
            req.respond(true);
        }

        void recorderSynchronizeTask(syncRecorderRR req) {
            immutable result = recorderSynchronize(journal_path, addressbook, task_names, handle, net, dest_db);
            req.respond(result);
        }

        run(&compareTask, &synchronizeTask, &replayTask, &recorderSynchronizeTask);
    }

private:
    immutable(bool) bullseyesMatch(
        const SecureNet net,
        shared(AddressBook) addressbook,
        ActorHandle node_interface_handle,
        DART destination
    ) {

        import tagion.dart.DARTcrud;
        import tagion.hibon.Document;

        import std.random : randomShuffle;
        import std.array : array;

        auto channels = addressbook.keys.dup.array;
        randomShuffle(channels);

        enum max_retries = 3; // Probably should take it from env.
        uint default_timeout_mil = 10_000;
        auto total_timeout = (max_retries * channels.length * default_timeout_mil).msecs;
        auto start_time = MonoTime.currTime();

        foreach (channel; channels) {
            auto address = addressbook[channel].get.address;
            for (int attempt = 1; attempt <= max_retries; ++attempt) {
                if (MonoTime.currTime() - start_time > total_timeout) {
                    throw new Exception(
                        "bullseyesMatch: total timeout exceeded while checking addresses.");
                }

                try {
                    node_interface_handle.send(NodeReq(), channel, dartBullseye().toDoc);
                    const bullseye_response_doc = receiveOnly!(NodeReq.Response, Document)[1];

                    HiRPC hirpc = HiRPC(net);
                    auto response = hirpc.receive(bullseye_response_doc);
                    auto message = response.message[Keywords.result].get!Document;
                    const remote_bullseye = message[Params.bullseye].get!Fingerprint;

                    return remote_bullseye == destination.bullseye;
                }

                catch (Exception e) {
                    writeln("bullseyesMatch: attempt ", attempt, " failed for ", address, ": ", e
                            .msg);
                }
            }
        }

        throw new Exception("bullseyesMatch: all attempts to all addresses failed.");
    }

    immutable(string[]) synchronize(
        string journal_path,
        shared(AddressBook) addressbook,
        immutable(TaskNames) task_names,
        DART destination
    ) {
        enum stackPage = 256;

        const sz = pageSize * stackPage;
        const guard_page_size = pageSize;

        string[] journal_filenames;
        Synchronizer[Pubkey] remote_workers;
        auto rim_range = iota!ushort(256);

        void synchronizeFiber(Synchronizer dart_synchronizer, ushort current_rim) {
            version (DEDICATED_DART_SYNC_FIBER) {
                auto dist_sync_fiber = synchronizer(dart_synchronizer, destination, Rims(
                        [cast(ubyte) current_rim]), sz, guard_page_size);
            }
            else {
                auto dist_sync_fiber = destination.synchronizer(dart_synchronizer, Rims(
                        [cast(ubyte) current_rim]), sz, guard_page_size);
            }

            while (!dist_sync_fiber.empty) {
                (() @trusted => dist_sync_fiber.call)();
            }
            if (dist_sync_fiber.state == Fiber.State.TERM) {
                (() @trusted => dist_sync_fiber.reset)();
            }
        }

        void assignWorkers() {
            auto channels = addressbook.keys.dup.array;
            foreach (channel; channels) {
                if (rim_range.empty)
                    break;

                const ushort current_rim = rim_range.front;
                const sector = current_rim << 8;
                rim_range.popFront;

                auto dart_synchronizer = new DARTSynchronizer(destination, channel, task_names);
                remote_workers[channel] = dart_synchronizer;

                immutable journal_filename = format("%s.%04x.dart_journal.hibon", journal_path, sector);
                auto journalfile = File(journal_filename, "w");
                dart_synchronizer.updateJournalFile(journalfile);

                scope (exit) {
                    if (journalfile.size > 0) {
                        journal_filenames ~= journal_filename;
                    }
                    journalfile.close;
                }

                try {
                    synchronizeFiber(dart_synchronizer, current_rim);
                }
                catch (HiBONException e) {
                    break;
                }
            }
        }

        do {
            assignWorkers();
        }
        while (!rim_range.empty && !remote_workers.empty);

        return (() @trusted => assumeUnique(journal_filenames))();
    }

    void replayWithFiles(DART destination, immutable(ReplayFiles) journal_filenames) {
        foreach (journal_filename; journal_filenames.files) {
            version (DEDICATED_DART_SYNC_FIBER) {
                replay(destination, journal_filename);
            }
            else {
                destination.replay(journal_filename);
            }
        }
    }

    bool recorderSynchronize(
        string journal_path,
        shared(AddressBook) addressbook,
        immutable(TaskNames) task_names,
        ActorHandle node_interface_handle,
        const SecureNet net,
        DART destination
    ) {
        import tagion.script.methods;
        import tagion.replicator.RecorderBlock;
        import tagion.dart.Recorder;
        import tagion.script.common;
        import tagion.dart.DARTFile;
        import tagion.actor.exceptions;
        import tagion.wave.common;
        import tagion.hibon.HiBONRecord;

        bool bullseye_match = false;
        HiRPC hirpc = HiRPC(net);
        auto channels = addressbook.keys.dup.array;
        uint node_timeout_mil = 30_000;
        uint pub_key_index = 0;

        while (!bullseye_match) {
            synchronize(journal_path, addressbook, task_names, destination);
            TagionHead tagion_head = getHead(destination);
            auto channel = channels[pub_key_index];
            auto startTime = MonoTime.currTime();

            while (true) {
                try {
                    if (MonoTime.currTime() - startTime > node_timeout_mil.msecs &&
                        pub_key_index + 1 < channels.length) {
                        ++pub_key_index;
                        break;
                    }

                    const recorder_read_request = hirpc.readRecorder(
                        EpochParam(tagion_head.current_epoch));

                    node_interface_handle.send(NodeReq(), channel, recorder_read_request
                            .toDoc);
                    const recorder_block_doc = receiveOnly!(NodeReq.Response, Document)[1];

                    if (recorder_block_doc.empty || !recorder_block_doc.isRecord!RecorderBlock)
                        break;

                    const block = RecorderBlock(recorder_block_doc);
                    auto factory = RecordFactory(net.hash);
                    auto recorder = factory.recorder(block.recorder_doc);
                    auto bullseye = destination.modify(recorder);

                    bullseye_match = bullseye == block.bullseye;
                    if (bullseye_match)
                        break;
                }
                catch (Exception e) {
                    break;
                }
            }
        }
        return bullseye_match;
    }
}
