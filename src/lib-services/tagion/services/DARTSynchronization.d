module tagion.services.DARTSynchronization;

import tagion.services.DART : DARTOptions, DARTService;
import tagion.crypto.SecureNet;
import tagion.dart.DART;
import tagion.dart.DARTRemoteWorker;
import tagion.crypto.Types : Fingerprint;
import tagion.services.DARTInterface;
import tagion.services.TRTService;
import tagion.services.options : TaskNames;
import tagion.utils.pretend_safe_concurrency : receiveOnly;
import tagion.dart.DARTcrud : dartBullseye;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.Keywords;
import tagion.dart.DARTBasic : DARTIndex, Params;
import tagion.dart.DARTRim;
import tagion.dart.BlockFile : BlockFile, BLOCK_SIZE;
import tagion.utils.Term;
import tagion.utils.pretend_safe_concurrency;
import tagion.actor;
import tagion.services.messages;
import tagion.dart.DART;
import tagion.json.JSONRecord;
import tagion.services.options : contract_sock_addr;
import tagion.hibon.HiBONException;

import std.exception : enforce, assumeUnique;
import std.format;
import std.path : baseName, buildPath, dirName, setExtension, stripExtension;
import std.file;
import std.stdio;
import std.range;
import core.time;
import core.thread;

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

    uint socket_timeout_mil = 1000;
    uint socket_attempts_mil = 30_000;
    string journal_path;
    // string dart_prefix;
    // string[] sock_addrs;

    // void setDefault() nothrow {
    // socket_timeout_mil = 1000;
    // socket_attempts_mil = 30_000;
    // dart_prefix = "DART_";
    // sock_addrs ~= contract_sock_addr(dart_prefix);
    // }

    // void setPrefix(string prefix) nothrow {
    //     sock_addrs ~= contract_sock_addr(prefix ~ dart_prefix);
    // }

    mixin JSONRecord;
}

/// Represents a DART Synchronization Service responsible for database sync tasks.
struct DARTSynchronization {

    struct ReplayFiles {
        string[] files;
    }

    /// Entry point for the synchronization task.
    void task(immutable(DARTSyncOptions) opts, immutable(SockAddresses) sock_addrs, shared(
            StdSecureNet) shared_net, string dst_dart_path) {
        if (opts.journal_path.exists) {
            opts.journal_path.rmdirRecurse;
        }
        opts.journal_path.mkdirRecurse;

        enforce(dst_dart_path.exists, "DART does not exist");
        auto net = new StdSecureNet(shared_net);
        auto dest_db = new DART(net, dst_dart_path);

        void compare(dartCompareRR req) @safe {
            immutable result = shouldSync(opts, sock_addrs, net, dest_db);
            req.respond(result);
        }

        void sync(dartSyncRR req) @safe {
            immutable journal_filenames = synchronize(opts, sock_addrs, dest_db);
            req.respond(journal_filenames);
        }

        void replay(dartReplayRR req, immutable(ReplayFiles) files) @safe {
            replayWithFiles(dest_db, files);
            req.respond(true);
        }

        run(&compare, &sync, &replay);
    }

private:
    immutable(bool) shouldSync(immutable(DARTSyncOptions) opts, immutable(SockAddresses) sock_addrs,
        const SecureNet net, DART destination) {
        try {
            RemoteRequestSender sender = new RemoteRequestSender(opts.socket_timeout_mil, opts.socket_attempts_mil,
                sock_addrs.sock_addrs[0], null);
            HiRPC hirpc = HiRPC(net);
            auto bullseyeRequestDoc = dartBullseye(hirpc).toDoc;
            const bullseyeResponseDoc = sender.send(bullseyeRequestDoc);
            auto response = hirpc.receive(bullseyeResponseDoc);
            auto message = response.message[Keywords.result].get!Document;
            const remoteIndex = message[Params.bullseye].get!DARTIndex;
            return remoteIndex == destination.bullseye;
        }
        catch (HiBONException e) {
            return false;
        }
    }

    immutable(string[]) synchronize(immutable(DARTSyncOptions) opts,
        immutable(SockAddresses) sock_addrs, DART destination) {

        string[] journal_filenames;
        DARTRemoteWorker[string] remote_workers;
        auto rim_range = iota!ushort(256);

        auto sock_addr_arr = sock_addrs.sock_addrs;

        void synchronizeFiber(DARTRemoteWorker remote_worker, ushort current_rim) {
            auto dist_sync_fiber = destination.synchronizer(remote_worker, Rims(
                    [
                        cast(ubyte) current_rim
                    ]));

            while (!dist_sync_fiber.empty) {
                (() @trusted => dist_sync_fiber.call)();
            }
            // Ensure that fiber is really empty.
            auto current_state = dist_sync_fiber.state;

            if (current_state == Fiber.State.TERM) {
                writefln("-------- Fiber.State.TERM at %s --------", remote_worker.sock_addr);
                (() @trusted => dist_sync_fiber.reset)();
            }
        }

        void assignWorkers() {
            foreach (sock_addr; sock_addr_arr) {
                if (rim_range.empty) {
                    break;
                }

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
                    writefln("-------- HiBONException at %s --------", sock_addr);
                    break;
                }
            }
        }

        do {
            assignWorkers();
            writefln("-------- rim_range.empty is %s --------", rim_range.empty);
            writefln("-------- remote_workers.empty is %s --------", remote_workers.empty);
        }
        while (!rim_range.empty && !remote_workers.empty);

        return (() @trusted => assumeUnique(journal_filenames))();
    }

    void replayWithFiles(DART destination, immutable(ReplayFiles) journal_filenames) {
        foreach (journal_filename; journal_filenames.files) {
            destination.replay(journal_filename);
        }
    }
}

class RemoteRequestSender {

    protected DART.SynchronizationFiber fiber;

    uint socket_timeout_mil;
    uint socket_attempts_mil;
    string sock_addr;

    this(uint socket_timeout_mil, uint socket_attempts_mil, string sock_addr, DART
            .SynchronizationFiber fiber = null) {
        this.socket_attempts_mil = socket_attempts_mil;
        this.socket_timeout_mil = socket_timeout_mil;
        this.sock_addr = sock_addr;
        this.fiber = fiber;
    }

    /// Sends a remote request and returns the received document.
    /// Handles socket communication with a attempts_timeout and ensures resources are cleaned up.
    Document send(const Document request_doc) {

        import nngd;
        import std.range;

        NNGSocket socket = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        scope (exit) {
            writefln("-------- Close the socket %s --------", sock_addr);
            socket.close();
        }

        socket.recvtimeout = socket_timeout_mil.msecs;
        writefln("-------- Trying to dial a socket %s --------", sock_addr);
        int rc = socket.dial(sock_addr);
        enforce(rc == 0, format("Failed to dial %s", nng_errstr(rc))); // change to check()

        writefln("-------- Send to the socket %s --------", sock_addr);
        rc = socket.send!(immutable(ubyte[]))(request_doc.serialize);
        enforce(rc == 0, format("Failed to send %s", nng_errstr(rc)));

        const attempts_timeout = socket_attempts_mil.msecs;
        auto startTime = MonoTime.currTime();

        // Loop to check receivedBytes with attempts_timeout handling
        while (true) {
            // TODO: CHeck if it runs in parallel.
            writefln("-------- Waiting for receive at %s --------", sock_addr);
            auto received = socket.receive!(immutable ubyte[])();
            if (!received.empty) {
                writefln("-------- Received a document at %s --------", sock_addr);
                return Document(received); // Exit the loop if data is received
                // return Document.init; // Exit the loop if received time out waiting for data
            }
            // Check if the attempts_timeout has elapsed
            if (MonoTime.currTime() - startTime > attempts_timeout) {
                writefln("-------- startTime > attempts_timeout at %s --------", sock_addr);
                return Document.init; // Exit the loop if received time out waiting for data
            }
            if (fiber) {
                writefln("-------- fiber.yield at %s --------", sock_addr);
                // Yield to avoid blocking while waiting for data
                (() @trusted => fiber.yield)();
            }
        }
        assert(0);
    }
}
