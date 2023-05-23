module tagion.tools.dartutil.synchronize;

import std.format;
import tagion.communication.HiRPC;
import tagion.dart.DART;
import tagion.dart.BlockFile;
import tagion.hibon.Document;

@safe
class DARTUtilSynchronizer : DART.StdSynchronizer {
    protected DART source;
    protected DART destination;
    this(string journal_filename, DART destination, DART source) {
        this.source = source;
        this.destination = destination;
        super(journal_filename);
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
}

@safe
string[] synchronize(DART destination, DART source, string journal_basename) {
    string[] journal_filenames;
    foreach (sector; destination.sectors) {
        immutable journal_filename = format("%s.%04x.dart_journal", journal_basename, sector);
        journal_filenames ~= journal_filename;
        BlockFile.create(journal_filename, DART.stringof, BLOCK_SIZE);
        auto synch = new DARTUtilSynchronizer(journal_filename, destination, source);

        auto destination_synchronizer = destination.synchronizer(synch, DART.Rims(sector));
        while (!destination_synchronizer.empty) {
            (() @trusted { destination_synchronizer.call; })();
        }

    }

    foreach (journal_filename; journal_filenames) {
        destination.replay(journal_filename);
    }
    return journal_filenames;
}
