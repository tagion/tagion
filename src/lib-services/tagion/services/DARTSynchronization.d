module tagion.services.DARTSynchronization;

import tagion.services.DART : DARTOptions, DARTService;
import tagion.crypto.SecureNet;
import tagion.dart.DART;
import tagion.dart.DARTRemoteSynchronizer;
import tagion.crypto.Types : Fingerprint;
// This should not be include in the code it only for test
//import tagion.testbench.tools.Environment;
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

import std.exception : enforce, assumeUnique;
import std.format;
import std.path : baseName, buildPath, dirName, setExtension, stripExtension;
import std.file;
import std.stdio;
import core.time;
import tagion.json.JSONRecord;

struct DARTSyncOptions{
    string journal_path;

    mixin JSONRecord;
}

/// Represents a DART Synchronization Service responsible for database sync tasks.
@safe
struct DARTSynchronization {

    struct ReplayFiles {
        string[] files;
    }

    /// Entry point for the synchronization task.
    void task(immutable(DARTSyncOptions) opts, shared(StdSecureNet) shared_net, string dst_dart_path, string src_sock_addr) {
        if (opts.journal_path.exists) {
            opts.journal_path.rmdirRecurse;
        }
        opts.journal_path.mkdirRecurse;

        enforce(dst_dart_path.exists, "DART does not exist");
        auto net = new StdSecureNet(shared_net);
        auto dest_db = new DART(net, dst_dart_path);

        void sync(dartSyncRR req) @safe {
            immutable journal_filenames = synchronize(opts.journal_path, dest_db, src_sock_addr);
            req.respond(journal_filenames);
        }

        void replay(dartReplayRR req, immutable(ReplayFiles) files) @safe {
            replayWithFiles(dest_db, files);
            req.respond(true);
        }

        run(&sync, &replay);
    }

private:
    immutable(string[]) synchronize(string journal_basename, DART destination, string src_sock_addr) {
        string[] journal_filenames;
        uint count;
        enum line_width = 32;

        foreach (ushort _rim; 0 .. ubyte.max + 1) {
            ushort sector = cast(ushort)(_rim << 8);
            immutable journal_filename = format("%s.%04x.dart_journal.hibon", journal_basename, sector);
            BlockFile.create(journal_filename, DART.stringof, BLOCK_SIZE);
            auto journalfile = BlockFile(journal_filename);

            scope (exit) {
                if (!journalfile.empty) {
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
            auto synch = new DARTRemoteSynchronizer(journalfile, destination, src_sock_addr);
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
