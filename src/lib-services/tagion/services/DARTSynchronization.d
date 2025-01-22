module tagion.services.DARTSynchronization;

import tagion.services.DART : DARTOptions, DARTService;
import tagion.crypto.SecureNet;
import tagion.dart.DART;
import tagion.dart.DARTRemoteSynchronizer;
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
import tagion.tools.Basic : nobose, noboseln, verbose;
import tagion.utils.Term;
import tagion.utils.pretend_safe_concurrency;
import tagion.actor;
import tagion.services.messages;
import tagion.dart.DART;

import std.exception : enforce, assumeUnique;
import std.format;
import std.path : baseName, buildPath, dirName, setExtension, stripExtension;
import std.file;
import std.stdio;
import core.time;
import tagion.json.JSONRecord;

struct DARTSyncOptions {
    import tagion.services.options : contract_sock_addr;

    uint socket_timeout_mil = 1000;
    uint socket_attempts_mil = 30_000;
    string dart_prefix = "DART_";
    string src_sock_addr;
    string journal_path;

    void setDefault() @safe nothrow {
        src_sock_addr = contract_sock_addr(dart_prefix);
    }

    void setPrefix(string prefix) @safe nothrow {
        src_sock_addr = contract_sock_addr(prefix ~ dart_prefix);
    }

    mixin JSONRecord;
}

/// Represents a DART Synchronization Service responsible for database sync tasks.
@safe
struct DARTSynchronization {

    struct ReplayFiles {
        string[] files;
    }

    /// Entry point for the synchronization task.
    void task(immutable(DARTSyncOptions) opts, shared(StdSecureNet) shared_net, string dst_dart_path) {
        if (opts.journal_path.exists) {
            opts.journal_path.rmdirRecurse;
        }
        opts.journal_path.mkdirRecurse;

        enforce(dst_dart_path.exists, "DART does not exist");
        auto net = new StdSecureNet(shared_net);
        auto dest_db = new DART(net, dst_dart_path);

        void compare(dartCompareRR req) @safe {
            immutable result = shouldSync(opts, net, dest_db);
            req.respond(result);
        }

        void sync(dartSyncRR req) @safe {
            immutable journal_filenames = synchronize(opts, dest_db);
            req.respond(journal_filenames);
        }

        void replay(dartReplayRR req, immutable(ReplayFiles) files) @safe {
            replayWithFiles(dest_db, files);
            req.respond(true);
        }

        run(&compare, &sync, &replay);
    }

private:
    immutable(bool) shouldSync(immutable(DARTSyncOptions) opts, const SecureNet net, DART destination) {

        RemoteRequestSender sender = new RemoteRequestSender(opts, null);
        HiRPC hirpc = HiRPC(net);
        auto bullseyeRequestDoc = dartBullseye(hirpc).toDoc;
        const bullseyeResponseDoc = sender.send(bullseyeRequestDoc);
        auto response = hirpc.receive(bullseyeResponseDoc);
        auto message = response.message[Keywords.result].get!Document;
        const remoteIndex = message[Params.bullseye].get!DARTIndex;
        return remoteIndex == destination.bullseye;
    }

    immutable(string[]) synchronize(immutable(DARTSyncOptions) opts, DART destination) {
        string[] journal_filenames;
        uint count;
        enum line_width = 32;

        foreach (ushort _rim; 0 .. ubyte.max + 1) {
            ushort sector = cast(ushort)(_rim << 8);
            immutable journal_filename = format("%s.%04x.dart_journal.hibon", opts.journal_path, sector);
            auto journalfile = File(journal_filename, "w");
            scope (exit) {
                if (journalfile.size > 0) {
                    journal_filenames ~= journal_filename;
                    verbose("Journalfile %s", journal_filename);
                    nobose("%s#%s", YELLOW, RESET);
                }
                else {
                    nobose("%sX%s", BLUE, RESET);
                }
                count++;
                if (count % line_width == 0) {
                    noboseln("!");
                }
                journalfile.close;
            }
            auto synch = new DARTRemoteSynchronizer(opts, destination, journalfile);
            auto destination_synchronizer = destination.synchronizer(synch, Rims([
                    cast(ubyte) _rim
                ]));
            while (!destination_synchronizer.empty) {
                (() @trusted { destination_synchronizer.call; })();
            }
        }

        return (() @trusted => assumeUnique(journal_filenames))();
    }

    void replayWithFiles(DART destination, immutable(ReplayFiles) journal_filenames) {
        uint count = 0;
        enum line_width = 32;

        foreach (journal_filename; journal_filenames.files) {
            destination.replay(journal_filename);
            verbose("Replay %s", journal_filename);
            nobose("%s*%s", GREEN, RESET);
            count++;
            if (count % line_width == 0) {
                noboseln("!");
            }
        }
        noboseln("\n%d journal files has been synchronized", count);
    }
}

@safe
class RemoteRequestSender {

    protected DARTSyncOptions opts;
    protected DART.SynchronizationFiber fiber;

    this(immutable(DARTSyncOptions) opts, DART.SynchronizationFiber fiber = null){
        this.opts = opts;
        this.fiber = fiber;
    }

    /// Sends a remote request and returns the received document.
    /// Handles socket communication with a timeout and ensures resources are cleaned up.
    Document send(const Document request_doc) {

        import nngd;
        import std.range;

        NNGSocket socket = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        scope (exit) {
            socket.close();
        }

        socket.recvtimeout = opts.socket_timeout_mil.msecs;

        int rc = socket.dial(opts.src_sock_addr);
        enforce(rc == 0, format("Failed to dial %s", nng_errstr(rc)));

        rc = socket.send!(immutable(ubyte[]))(request_doc.serialize);
        enforce(rc == 0, format("Failed to send %s", nng_errstr(rc)));

        const timeout = opts.socket_attempts_mil.msecs;
        auto startTime = MonoTime.currTime();

        // Loop to check receivedBytes with timeout handling
        while (true) {
            auto received = socket.receive!(immutable ubyte[])();
            if (!received.empty) {
                return Document(received); // Exit the loop if data is received
            }
            // Check if the timeout has elapsed
            if (MonoTime.currTime() - startTime > timeout) {
                return Document.init; // Exit the loop if received time out waiting for data
            }
            if (fiber !is null) {
                // Yield to avoid blocking while waiting for data
                (() @trusted { fiber.yield; })();
            }
        }
        assert(0);
    }
}
