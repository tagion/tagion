module tagion.tools.dartutil.synchronize;

import std.file : remove;
import std.format;
import tagion.communication.HiRPC;
import tagion.dart.BlockFile;
import tagion.dart.DART;
import tagion.dart.DARTRim;
import tagion.dart.synchronizer;
import tagion.hibon.Document;
import tagion.tools.Basic : nobose, noboseln, verbose;
import tagion.utils.Term;

@safe
class DARTUtilSynchronizer : JournalSynchronizer {
    protected DART source;
    protected DART destination;
    this(BlockFile journalfile, DART destination, DART source) {
        this.source = source;
        this.destination = destination;
        super(journalfile);
    }

    //
    // This function emulates the connection between two DART's
    // in a single thread
    //
    const(HiRPC.Receiver) query(ref const(HiRPC.Sender) request) {
        Document send_request_to_source(const Document foreign_doc) {
            //
            // Remote excution
            // Receive on the foreign end
            const foreign_receiver = source.hirpc.receive(foreign_doc);
            // Make query in to the foreign DART
            const foreign_response = source(foreign_receiver);

            return foreign_response.toDoc;
        }

        immutable foreign_doc = request.toDoc;
        (() @trusted { fiber.yield; })();
        // Here a yield loop should be implement to poll for response from the foriegn DART
        // A timeout should also be implemented in this poll loop
        const response_doc = send_request_to_source(foreign_doc);
        //
        // Process the response returned for the foreign DART
        //
        const received = destination.hirpc.receive(response_doc);
        return received;
    }

    override void finish() {
        //            journalfile.close;
        _finished = true;
    }

}

@safe
string[] synchronize(DART destination, DART source, string journal_basename) {
    string[] journal_filenames;
    uint count;
    enum line_width = 32;
    //    foreach (sector; destination.sectors) {
    foreach (ushort _rim; 0 .. ubyte.max + 1) {
        ushort sector = cast(ushort)(_rim << 8);
        const(ubyte)[] rims;
        verbose("Sector %04x", sector);
        immutable journal_filename = format("%s.%04x.dart_journal", journal_basename, sector);
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
        auto synch = new DARTUtilSynchronizer(journalfile, destination, source);

        auto destination_synchronizer = destination.synchronizer(synch, Rims([cast(ubyte) _rim]));
        while (!destination_synchronizer.empty) {
            (() @trusted { destination_synchronizer.call; })();
        }

    }
    noboseln("Replay journal filenames");
    verbose("Replay journal filenames");
    count = 0;
    foreach (journal_filename; journal_filenames) {
        destination.replay(journal_filename);
        verbose("Replay %s", journal_filename);
        nobose("%s*%s", GREEN, RESET);
        count++;
        if (count % line_width == 0) {
            noboseln("!");
        }
    }
    noboseln("\n%d journal files has been syncronized", count);
    return journal_filenames;
}
