module tagion.services.DARTSynchronization;

import std.exception : enforce, assumeUnique;
import std.format;
import std.file;
import std.path : baseName, buildPath, dirName, setExtension, stripExtension;
import std.range;
import std.stdio;
import core.time;
import core.thread;
import core.memory : pageSize;

import tagion.services.DART : DARTOptions, DARTService;
import tagion.services.rpcs;
import tagion.services.options : TaskNames, contract_sock_addr;
import tagion.services.messages;
import tagion.crypto.SecureNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.DART;
import tagion.dart.DARTcrud : dartBullseye;
import tagion.dart.DARTRemoteWorker;
import tagion.dart.DARTBasic : DARTIndex, Params;
import tagion.dart.DARTRim;
import tagion.dart.BlockFile : BlockFile, BLOCK_SIZE;
import tagion.actor;
import tagion.hibon.Document;
import tagion.hibon.HiBONException;
import tagion.json.JSONRecord;
import tagion.Keywords;
import tagion.utils.Term;
import tagion.utils.pretend_safe_concurrency;
import tagion.utils.pretend_safe_concurrency : receiveOnly;
import tagion.communication.HiRPC : HiRPC;
import tagion.logger.Logger;

@safe:

struct SockAddresses {
    string[] sock_addrs;
    string dart_prefix = "DART_";

    void setDefault() nothrow {
        sock_addrs ~= contract_sock_addr(dart_prefix);
    }

    void setPrefix(string prefix) nothrow {
        sock_addrs ~= contract_sock_addr(prefix ~ dart_prefix);
    }
}

pragma(msg, "fixme(cbr): Option cannot include a string array.");
struct DARTSyncOptions {
    uint socket_timeout_mil = 10_000;
    uint socket_attempts_mil = 30_000;
    string journal_path;

    mixin JSONRecord;
}

struct DARTSynchronization {

    struct ReplayFiles {
        string[] files;
    }

    void task(
            immutable(DARTSyncOptions) opts,
            immutable(SockAddresses) sock_addrs,
            shared(SecureNet) shared_net,
            string dst_dart_path
    ) {
        if (opts.journal_path.exists) {
            opts.journal_path.rmdirRecurse;
        }
        opts.journal_path.mkdirRecurse;

        enforce(dst_dart_path.exists, "DART does not exist");
        auto net = shared_net.clone;
        auto dest_db = new DART(net.hash, dst_dart_path);

        void compareTask(dartCompareRR req) {
            immutable result = bullseyesMatch(opts, sock_addrs, net, dest_db);
            req.respond(result);
        }

        void synchronizeTask(dartSyncRR req) {
            immutable journal_filenames = synchronize(opts, sock_addrs, dest_db);
            req.respond(journal_filenames);
        }

        void replayTask(dartReplayRR req, immutable(ReplayFiles) files) {
            replayWithFiles(dest_db, files);
            req.respond(true);
        }

        void recorderSynchronizeTask(syncRecorderRR req) {
            immutable result = recorderSynchronize(opts, sock_addrs, net, dest_db);
            req.respond(result);
        }

        run(&compareTask, &synchronizeTask, &replayTask, &recorderSynchronizeTask);
    }

private:

    immutable(bool) bullseyesMatch(
            immutable(DARTSyncOptions) opts,
            immutable(SockAddresses) sock_addrs,
            const SecureNet net,
            DART destination
    ) {
        try {
            RemoteRequestSender sender = new RemoteRequestSender(
                    opts.socket_timeout_mil,
                    opts.socket_attempts_mil,
                    sock_addrs.sock_addrs[0],
                    null
            );
            HiRPC hirpc = HiRPC(net);
            auto bullseyeRequestDoc = dartBullseye(hirpc).toDoc;
            const bullseyeResponseDoc = sender.send(bullseyeRequestDoc);

            auto response = hirpc.receive(bullseyeResponseDoc);
            auto message = response.message[Keywords.result].get!Document;
            const remoteFingerprint = message[Params.bullseye].get!Fingerprint;
            return remoteFingerprint == destination.bullseye;
        }
        catch (HiBONException e) {
            return false;
        }
    }

    immutable(string[]) synchronize(
            immutable(DARTSyncOptions) opts,
            immutable(SockAddresses) sock_addrs,
            DART destination
    ) {
        enum stackPage = 256;

        const sz = pageSize * stackPage;
        const guard_page_size = pageSize;

        string[] journal_filenames;
        DARTRemoteWorker[string] remote_workers;
        auto rim_range = iota!ushort(256);
        auto sock_addr_arr = sock_addrs.sock_addrs;

        void synchronizeFiber(DARTRemoteWorker remote_worker, ushort current_rim) {
            auto dist_sync_fiber = destination.synchronizer(remote_worker, Rims(
                    [cast(ubyte) current_rim]), sz, guard_page_size);

            while (!dist_sync_fiber.empty) {
                (() @trusted => dist_sync_fiber.call)();
            }
            if (dist_sync_fiber.state == Fiber.State.TERM) {
                (() @trusted => dist_sync_fiber.reset)();
            }
        }

        void assignWorkers() {
            foreach (sock_addr; sock_addr_arr) {
                if (rim_range.empty)
                    break;

                const ushort current_rim = rim_range.front;
                const sector = current_rim << 8;
                rim_range.popFront;

                auto remote_worker = new DARTRemoteWorker(opts, sock_addr, destination);
                remote_workers[sock_addr] = remote_worker;

                immutable journal_filename = format("%s.%04x.dart_journal.hibon", opts.journal_path, sector);
                auto journalfile = File(journal_filename, "w");

                remote_worker.updateJournalFile(journalfile);

                scope (exit) {
                    if (journalfile.size > 0) {
                        journal_filenames ~= journal_filename;
                    }
                    journalfile.close;
                }

                try {
                    synchronizeFiber(remote_worker, current_rim);
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
            destination.replay(journal_filename);
        }
    }

    bool recorderSynchronize(
            immutable(DARTSyncOptions) opts,
            immutable(SockAddresses) sock_addrs,
            const SecureNet net,
            DART destination
    ) {
        import tagion.replicator.RecorderCrud;
        import tagion.replicator.RecorderBlock;
        import tagion.dart.Recorder;
        import tagion.script.common;
        import tagion.dart.DARTFile;
        import tagion.actor.exceptions;
        import tagion.wave.common;
        import tagion.hibon.HiBONRecord;

        bool bMatch = false;
        HiRPC hirpc = HiRPC(net);
        uint node_timeout_mil = 30_000;
        uint socket_addr_index = 0;

        while (!bMatch) {
            synchronize(opts, sock_addrs, destination);
            TagionHead tagion_head = getHead(destination, net);

            string current_sock_addrs = sock_addrs.sock_addrs[socket_addr_index];
            auto startTime = MonoTime.currTime();

            while (true) {
                try {
                    if (MonoTime.currTime() - startTime > node_timeout_mil.msecs &&
                            socket_addr_index + 1 < sock_addrs.sock_addrs.length) {
                        ++socket_addr_index;
                        break;
                    }

                    RemoteRequestSender sender = new RemoteRequestSender(
                            opts.socket_timeout_mil,
                            opts.socket_attempts_mil,
                            current_sock_addrs,
                            null
                    );

                    const recorder_read_request = hirpc.readRecorder(
                            EpochParam(tagion_head.current_epoch));
                    const recorder_block_doc = sender.send(recorder_read_request.toDoc);

                    if (recorder_block_doc.empty || !recorder_block_doc.isRecord!RecorderBlock)
                        break;

                    const block = RecorderBlock(recorder_block_doc);
                    auto factory = RecordFactory(net.hash);
                    auto recorder = factory.recorder(block.recorder_doc);
                    auto bullseye = destination.modify(recorder);

                    bMatch = bullseye == block.bullseye;
                    if (bMatch)
                        break;
                }
                catch (Exception e) {
                    break;
                }
            }
        }
        return bMatch;
    }
}

class RemoteRequestSender {

    protected DART.SynchronizationFiber fiber;
    uint socket_timeout_mil;
    uint socket_attempts_mil;
    string sock_addr;

    this(uint socket_timeout_mil, uint socket_attempts_mil, string sock_addr, DART
            .SynchronizationFiber fiber = null) {
        this.socket_timeout_mil = socket_timeout_mil;
        this.socket_attempts_mil = socket_attempts_mil;
        this.sock_addr = sock_addr;
        this.fiber = fiber;
    }

    Document send(const Document request_doc) {
        import nngd;
        import std.range;
        import std.typecons;

        NNGSocket socket = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        scope (exit)
            socket.close();

        socket.recvtimeout = socket_timeout_mil.msecs;
        int rc = socket.dial(sock_addr);
        enforce(rc == 0, format("Failed to dial %s", nng_errstr(rc)));

        rc = socket.send!(immutable(ubyte[]))(request_doc.serialize);
        enforce(rc == 0, format("Failed to send %s", nng_errstr(rc)));

        const attempts_timeout = socket_attempts_mil.msecs;
        auto startTime = MonoTime.currTime();

        while (true) {
            auto received = socket.receive!(immutable ubyte[])(Yes.Nonblock);
            if (!received.empty)
                return Document(received);

            if (MonoTime.currTime() - startTime > attempts_timeout) {
                return Document.init;
            }

            if (fiber) {
                (() @trusted => fiber.yield)();
            }
        }
        assert(0);
    }
}
