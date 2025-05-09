// DART database build on DARTFile including CRUD commands and synchronization
module tagion.dart.DART;
@safe:
import core.exception : RangeError;
import core.thread : Fiber;
import std.conv : ConvException;
import std.range : empty, zip;
import std.stdio;

//import std.stdio;
import std.algorithm.iteration : filter, map;
import std.format : format;
import std.range;
import std.traits : EnumMembers;
import tagion.basic.Types : Buffer;
import tagion.basic.basic : FUNCTION_NAME;
import tagion.basic.basic : EnumText, isinit;
import tagion.errors.tagionexceptions : Check;
import tagion.communication.HiRPC : Callers, HiRPC, HiRPCMethod;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.dart.DARTBasic : DARTIndex, KEY_SPAN, Params, Queries;
import tagion.dart.DARTFile;
import tagion.dart.DARTRim;
import CRUD = tagion.dart.DARTcrud;
import tagion.dart.Recorder : Archive, RecordFactory;
import tagion.dart.synchronizer : JournalSynchronizer, Synchronizer;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord : GetLabel, HiBONRecord, label, recordType;
import core.memory : pageSize;

/**
 * Calculates the to-angle on the angle circle 
 * Params:
 *   from_sector = angle from
 *   to_sector = angle to
 * Returns: 
 *   to angle
 */
uint calc_to_value(const ushort from_sector, const ushort to_sector) pure nothrow @nogc {
    return to_sector + ((from_sector >= to_sector) ? SECTOR_MAX_SIZE : 0);
}

unittest {
    // One sector
    assert(calc_to_value(0x46A6, 0x46A7) == 0x46A7);
    // Full round
    assert(calc_to_value(0x46A6, 0x46A6) == 0x46A6 + SECTOR_MAX_SIZE);
    // Round around
    assert(calc_to_value(0x46A7, 0x46A6) == 0x46A6 + SECTOR_MAX_SIZE);

}

/** 
     * Calculates the angle arc between from_sector to to_sector
     * Params:
     *   from_sector = angle from
     *   to_sector =  angle to
     * Returns: 
     *   sector size
     */
uint calc_sector_size(const ushort from_sector, const ushort to_sector) pure nothrow @nogc {
    immutable from = from_sector;
    immutable to = calc_to_value(from_sector, to_sector);
    return to - from;
}

unittest { // check calc_sector_size
    // Full round
    assert(calc_sector_size(0x543A, 0x543A) == SECTOR_MAX_SIZE);
    // One sector
    assert(calc_sector_size(0x543A, 0x543B) == 1);
    // Part angle
    assert(calc_sector_size(0x1000, 0xF000) == 0xE000);
    // Wrap around angle
    assert(calc_sector_size(0xF000, 0x1000) == 0x2000);
}
/** 
 * DART support for HiRPC(dartRead,dartRim,dartBullseye and dartModify)
 * DART include support for synchronization
 * Examples: [tagion.testbench.dart]
 */
class DART : DARTFile {
    immutable ushort from_sector;
    immutable ushort to_sector;
    const HiRPC hirpc;

    /** Creates DART with given net and by given file path
    * Params: 
    *   net = Represent HashNet for initializing DART
    *   filename = Represent path to DART file to open
    *   from_sector = Represents from angle for DART sharding. In development.
    *   to_sector = Represents to angle for DART sharding. In development.
    */
    this(const HashNet net,
            string filename,
            Flag!"read_only" read_only = No.read_only,
            const HiRPC hirpc = HiRPC.init,
            const ushort from_sector = 0,
            const ushort to_sector = 0) @safe {
        super(net, filename, read_only);
        this.from_sector = from_sector;
        this.to_sector = to_sector;
        this.hirpc = hirpc;
    }

    /** 
    * Creates DART with given net and by given file path safely with catching possible exceptions
    * Params:
    *       net  = Represent HashNet for initializing DART
    *       filename = Represent path to DART file to open
    *       exception = Field used for returning exception in case when something gone wrong
    *       from_sector = Represents from angle for DART sharding. In development.
    *       to_sector = Represents to angle for DART sharding. In development.
    */
    this(const HashNet net,
            string filename,
            out Exception exception,
            Flag!"read_only" read_only = No.read_only,
            const HiRPC hirpc = HiRPC.init,
            const ushort from_sector = 0,
            const ushort to_sector = 0) @safe nothrow {
        try {
            this(net, filename, read_only, hirpc, from_sector, to_sector);
        }
        catch (Exception e) {
            exception = e;
        }
    }

    /** 
     * Check if the sector is within the DART angle
     * Params:
     *   sector = the sector in the DART
     * Returns: true of the sector is within the DART range
     */
    bool inRange(const ushort sector) pure nothrow {
        return SectorRange.sectorInRange(sector, from_sector, to_sector);
    }

    /** 
     * Creates a SectorRange for the DART
     * Returns: range of sectors
     */
    SectorRange sectors() pure nothrow {
        return SectorRange(from_sector, to_sector);
    }

    // mixin(EnumText!("__Queries", Callers!DART));
    static foreach (a, b; zip(Callers!DART, [EnumMembers!Queries])) {
        static assert(a is b, "Values not the same as in Queries");
    }

    /**
     * The dartBullseye method is called from opCall function
     * This function return current database bullseye.
     * Params:
received = the HiRPC received package
     * @param read_only - !Because this function is a read only the read_only parameter has no effect 
     * @return HiRPC result that contains current database bullseye
     */
    @HiRPCMethod private const(HiRPC.Sender) dartBullseye(
            ref const(HiRPC.Receiver) received,
            const bool read_only)
    in {
        mixin FUNCTION_NAME;
        assert(received.method.name == __FUNCTION_NAME__);
    }
    do {
        auto hibon_params = new HiBON;
        hibon_params[Params.bullseye] = bullseye;
        return hirpc.result(received, hibon_params);
    }
    /**
     * The dartRead method is called from opCall function
     * This function reads list of archive specified in the list of fingerprints.

     * The result is returned as a Recorder object
     * read from the DART

     * Note:
     * Because this function is a read only the read_only parameter has no effect

     * params: received is the HiRPC package
     * Example:
     * ---
     * // HiRPC metode
     * {
     *  ....
     *    message : {
     *        method : "dartRead"
     *            params : {
     *                fingerprints : [
     *                     <GENERIC>,
     *                     <GENERIC>,
     *                     .....
     *                          ]
     *                     }
     *                 ...
     *                }
     *             }

     * // HiRPC Result
     *   {
     *   ....
     *       message : {
     *           result : {
     *               recoder : <DOCUMENT> // Recorder
     *                   limit   : <UINT32> // Optional
     *       // This parameter is set if dart_indices list exceeds the limit
     *                    }
     *               }
     *   }
     * ---
     */
    @HiRPCMethod private const(HiRPC.Sender) dartRead(
            ref const(HiRPC.Receiver) received,
            const bool read_only)
    in {
        mixin FUNCTION_NAME;
        assert(received.method.name == __FUNCTION_NAME__);
    }
    do {
        const doc_dart_indices = received.method.params[Params.dart_indices].get!(Document);
        auto dart_indices = doc_dart_indices.range!(DARTIndex[]);
        const recorder = loads(dart_indices, Archive.Type.ADD);
        return hirpc.result(received, recorder.toDoc);
    }

    @HiRPCMethod private const(HiRPC.Sender) dartCheckRead(
            ref const(HiRPC.Receiver) received,
            const bool read_only)
    in {
        mixin FUNCTION_NAME;
        assert(received.method.name == __FUNCTION_NAME__);
    }
    do {
        auto doc_dart_indices = received.method.params[Params.dart_indices].get!(Document);
        auto dart_indices = doc_dart_indices.range!(DARTIndex[]);
        auto not_in_dart = checkload(dart_indices);

        auto params = new HiBON;
        auto params_dart_indices = new HiBON;
        params_dart_indices = not_in_dart.map!(f => cast(Buffer) f);
        params[Params.dart_indices] = params_dart_indices;
        return hirpc.result(received, params);
    }

    /**
     *  The dartRim method is called from opCall function
     *
     *  This method reads the Branches object at the specified rim
     *
     *  Note:
     *  Because this function is a read only the read_only parameter has no effect
     *
     *  Params:
     *      received is the HiRPC package
     *  Example:
     *  ---
     *  // HiRPC format
     *
     *  {
     *      ....
     *      message : {
     *        method : "dartRim",
     *            params : {
     *                rims : <GENERIC>
     *            }
     *        }
     *  }
     *
     *  // HiRPC Result
     *  {
     *    ....
     *    message : {
     *        result : {
     *            branches : <DOCUMENT> // Branches
     *            limit    : <UINT32> // Optional
     *                // This parameter is set if fingerprints list exceeds the limit
     *            }
     *        }
     *  }
     *
     * ----
     */
    @HiRPCMethod private const(HiRPC.Sender) dartRim(
            ref const(HiRPC.Receiver) received,
            const bool read_only)
    in {
        mixin FUNCTION_NAME;
        assert(received.method.name == __FUNCTION_NAME__);
    }
    do {
        import tagion.dart.BlockFile : Index;

        immutable params = received.params!Rims;

        const rim_branches = branches(params.path);
        HiBON hibon_params;

        if (!params.key_leaves.empty) {
            if (!rim_branches.empty) {
                auto super_recorder = recorder;
                foreach (key; params.key_leaves) {
                    const index = rim_branches.indices[key];
                    if (index.isinit) {
                        HiRPC.Error not_found;
                        not_found.message = format("No archive found on %(%02x %):%02x", params.path, key);
                        super_recorder.add(not_found);
                        continue;
                    }
                    immutable data = blockfile.load(index);
                    const doc = Document(data);
                    super_recorder.add(doc);

                }
                return hirpc.result(received, super_recorder);
            }
        }
        else if (!rim_branches.empty) {
            hibon_params = rim_branches.toHiBON(true);
        }
        else if (params.path.length > ushort.sizeof || !params.key_leaves.empty) {
            hibon_params = new HiBON;
            // It not branches so maybe it is an archive
            immutable key = params.path[$ - 1];
            const super_branches = branches(params.path[0 .. $ - 1]);
            if (!super_branches.empty) {
                const index = super_branches.indices[key];
                if (index != Index.init) {
                    // The archive is added to a recorder
                    immutable data = blockfile.load(index);
                    const doc = Document(data);
                    auto super_recorder = recorder;
                    super_recorder.add(doc);
                    return hirpc.result(received, super_recorder);
                }
            }

        }
        return hirpc.result(received, hibon_params);
    }

    /**
     *  The dartModify method is called from opCall function
     *
     *  This function execute and modify function according to the recorder parameter
     *
     *  Note:
     *  This function will fail if read only the read_only is true
     *
     *
     *   Example:
     *  ---
     *     // HiRPC format
     *   {
     *       ....
     *       message : {
     *           method : "dartModify"
     *           params : {
     *               recorder : <DOCUNENT> // Recorder object
     *           }
     *       }
     *   }
     *
     *  // HiRPC Result
     *  {
     *       ....
     *       message : {
     *           result   : {
     *           bullseye : <GENERIC> // Returns the update bullseye of the DART
     *           }
     *       }
     *  }
     *
     * ---
     * Params: received is the HiRPC package
     * Returns: HiBON Sender 
     */

    @HiRPCMethod private const(HiRPC.Sender) dartModify(
            ref const(HiRPC.Receiver) received,
            const bool read_only)
    in {
        mixin FUNCTION_NAME;
        assert(received.method.name == __FUNCTION_NAME__);
    }
    do {
        HiRPC.check(!read_only, "The DART is read only");
        const recorder = manufactor.recorder(received.method.params);
        immutable bullseye = modify(recorder);
        auto hibon_params = new HiBON;
        hibon_params[Params.bullseye] = bullseye;
        return hirpc.result(received, hibon_params);
    }

    /**
     * This function handles HPRC Queries to the DART
     * Params:
     *     received = Request HiRPC object
     * If read_only is true deleting and erasing data in the DART will return an error
     * Note.
     * When the DART is accessed from an external HiRPC this flag should be kept false.
     *
     * Returns:
     *     The response from HPRC if the method is supported
     *     else the response return is marked empty
     */
    const(HiRPC.Sender) opCall(
            ref const(HiRPC.Receiver) received,
            const bool read_only = true) {
        import std.conv : to;

        const method = received.method;
        switch (method.name) {
            static foreach (call; Callers!DART) {
        case call:
                enum code = format(q{return %s(received, read_only);}, call);
                mixin(code);
            }
        default:
            // Empty
        }
        immutable message = format("Method '%s' not supported", method.name);
        return hirpc.error(received, message, 22);
    }

    /**
     * Creates a synchronization fiber from a synchroizer 
     * Params:
     *   synchonizer = synchronizer to be used
     *   rims = selected rim path
     * Returns: 
     *  synchronization fiber
     */
    SynchronizationFiber synchronizer(Synchronizer synchonizer, const Rims rims, size_t sz = pageSize * Fiber
            .defaultStackPages,
            size_t guardPageSize = pageSize) {

        return new SynchronizationFiber(rims, synchonizer, sz, guardPageSize);
    }

    /**
     * Synchronizer which supports synchronization from multiplet DART's 
     */
    @safe
    class SynchronizationFiber : Fiber {
        protected Synchronizer sync;

        // static size_t default_page_size = defaultStackPages;
        // static size_t guard_page_size = guardPageSize; 

        immutable(Rims) root_rims;
        size_t fiberPageSize;

        this(const Rims root_rims,
                Synchronizer sync,
                size_t sz = pageSize * Fiber.defaultStackPages,
                size_t guardPageSize = pageSize) @trusted {
            this.root_rims = root_rims;
            this.sync = sync;
            sync.set(this.outer, this, this.outer.hirpc);
            super(&run, sz, guardPageSize);
        }

        protected uint _id;
        /* 
         * Id for the HiRPC
         * Returns: HiRPC id
        */
        @property uint id() {
            if (_id == 0) {
                _id = hirpc.generateId();
            }
            return _id;
        }

        /**
         * Function to handle synchronization stage for the DART
         */
        final void run()
        in {
            assert(sync);
            assert(blockfile);
        }
        do {
            void iterate(const Rims params) @safe {
                //
                // Request Branches or Recorder at rims from the foreign DART.
                //
                const local_branches = branches(params.path);
                const request_branches = CRUD.dartRim(rims: params, hirpc: hirpc, id: id);
                const result_branches = sync.query(request_branches);
                if (Branches.isRecord(result_branches.response.result)) {
                    const foreign_branches = result_branches.result!Branches;
                    //
                    // Read all the archives from the foreign DART
                    //
                    const request_archives = CRUD.dartRead(
                            foreign_branches
                            .dart_indices, hirpc, id);
                    const result_archives = sync.query(request_archives);
                    auto foreign_recoder = manufactor.recorder(result_archives.response.result);
                    //
                    // The rest of the fingerprints which are not in the foreign_branches must be sub-branches
                    // 

                    auto local_recorder = recorder;
                    scope (success) {
                        sync.record(local_recorder);
                    }
                    foreach (const ubyte key; 0 .. KEY_SPAN) {
                        const sub_rims = Rims(params.path ~ key);
                        const local_print = local_branches.dart_index(key);
                        const foreign_print = foreign_branches.dart_index(key);
                        auto foreign_archive = foreign_recoder.find(foreign_print);
                        if (foreign_archive) {
                            if (local_print != foreign_print) {
                                local_recorder.insert(foreign_archive);
                                sync.removeRecursive(sub_rims);
                            }
                        }
                        else if (!foreign_print.isinit) {
                            // Foreign is points to branches
                            if (!local_print.empty) {
                                const possible_branches_data = load(local_branches, key);
                                if (!Branches.isRecord(Document(possible_branches_data))) {
                                    // If branch is an archive then it is removed because if it exists in foreign DART
                                    // this archive will be added later
                                    local_recorder.remove(local_print);
                                }
                            }
                            iterate(sub_rims);
                        }
                        else if (!local_print.empty) {
                            sync.removeRecursive(sub_rims);
                        }
                    }
                }
                else {
                    if (result_branches.isRecord!(RecordFactory.Recorder)) {
                        auto foreign_recoder = manufactor.recorder(result_branches.response.result);
                        sync.record(foreign_recoder);
                    }
                    //
                    // The foreign DART does not contain data at the rims
                    //
                    sync.removeRecursive(params);
                }
            }

            iterate(root_rims);
            sync.finish;
        }
        /**
         * Checks if the synchronized  has reached the end 
         * Returns: true if empty
         */
        final bool empty() const pure nothrow {
            return sync.finished;
        }
    }

    /**
     * Replays the journal file to update the DART
     * The update HiBON-stream-file can be generated from the synchroning process from an foreign dart
     *
     * If the process is broken for some reason this the resumed by running the replay function again
     * on the same block file
     *
     * Params:
     *     journal_filename = Name of the HiBON-file to be replaied
     *
     * Throws:
     *     The function will throw an exception if something went wrong in the process.
     */
    void replay(const(string) journal_filename) {
        import tagion.hibon.HiBONFile;
        import std.range;

        auto journalfile = File(journal_filename, "r");

        scope (exit) {
            journalfile.close;
        }
        // Adding and Removing archives

        foreach (doc; HiBONRangeArray(journalfile).retro) {
            auto action_recorder = recorder(doc);
            modify(action_recorder);
        }

    }

    version (unittest) {
        import std.stdio : File;
        import tagion.basic.Types : FileExtension;
        import std.path;

        static class TestSynchronizer : JournalSynchronizer {
            protected DART foreign_dart;
            protected DART owner;
            this(File journalfile, DART owner, DART foreign_dart) {
                this.foreign_dart = foreign_dart;
                this.owner = owner;
                super(journalfile);
            }

            //
            // This function emulates the connection between two DART's
            // in a single thread
            //
            const(HiRPC.Receiver) query(ref const(HiRPC.Sender) request) {
                Document send_request_to_foreign_dart(const Document foreign_doc) {
                    //
                    // Remote execution
                    // Receive on the foreign end
                    const foreign_receiver = foreign_dart.hirpc.receive(foreign_doc);
                    // Make query in to the foreign DART
                    const foreign_response = foreign_dart(foreign_receiver);

                    return foreign_response.toDoc;
                }

                immutable foreign_doc = request.toDoc;
                (() @trusted { fiber.yield; })();
                // Here a yield loop should be implement to poll for response from the foreign DART
                // A timeout should also be implemented in this poll loop
                const response_doc = send_request_to_foreign_dart(foreign_doc);
                //
                // Process the response returned for the foreign DART
                //
                const received = owner.hirpc.receive(response_doc);
                return received;
            }
        }

    }

    ///Examples: how use the DART
    unittest {
        import tagion.basic.basic : assumeTrusted, tempfile;
        import tagion.dart.DARTFakeNet : DARTFakeNet;
        import tagion.dart.Recorder;
        import tagion.utils.Random;

        enum TEST_BLOCK_SIZE = 0x80;

        const net = new DARTFakeNet;

        immutable filename = fileId!DART.fullpath;
        immutable filename_A = fileId!DART("A_").fullpath;
        immutable filename_B = fileId!DART("B_").fullpath;
        immutable filename_C = fileId!DART("C_").fullpath;

        { // Remote Synchronization test

            import std.file : remove;

            auto rand = Random!ulong(1234_5678_9012_345UL);
            enum N = 1000;
            auto random_table = new ulong[N];
            foreach (ref r; random_table) {
                immutable sector = rand.value(0x0000_0000_0000_ABBAUL, 0x0000_0000_0000_ABBDUL) << (
                        8 * 6);
                r = rand.value(0x0000_1234_5678_0000UL | sector, 0x0000_1334_FFFF_0000UL | sector);
            }

            //
            // The the following unittest dart A and B covers the same range angle
            //
            enum from = 0xABB9;
            enum to = 0xABBD;

            //            import std.stdio;
            { // Single element same sector sectors
                const ulong[] same_sector_table = [
                    0xABB9_13ab_cdef_1234,
                    0xABB9_14ab_cdef_1234,
                    0xABB9_15ab_cdef_1234

                ];
                // writefln("Test 0.0");
                foreach (test_no; 0 .. 3) {
                    DARTFile.create(filename_A, net);
                    DARTFile.create(filename_B, net);
                    RecordFactory.Recorder recorder_B;
                    RecordFactory.Recorder recorder_A;
                    // Recorder recorder_B;
                    auto dart_A = new DART(net, filename_A, No.read_only, HiRPC.init, from, to);
                    auto dart_B = new DART(net, filename_B, No.read_only, HiRPC.init, from, to);
                    string[] journal_filenames;
                    scope (success) {
                        // writefln("Exit scope");
                        dart_A.close;
                        dart_B.close;
                        filename_A.remove;
                        filename_B.remove;
                        foreach (journal_filename; journal_filenames) {
                            journal_filename.remove;
                        }
                    }

                    switch (test_no) {
                    case 0:
                        write(dart_A, same_sector_table[0 .. 1], recorder_A);
                        write(dart_B, same_sector_table[0 .. 0], recorder_B);
                        break;
                    case 1:
                        write(dart_A, same_sector_table[0 .. 1], recorder_A);
                        write(dart_B, same_sector_table[1 .. 2], recorder_B);
                        break;
                    case 2:
                        write(dart_A, same_sector_table[0 .. 2], recorder_A);
                        write(dart_B, same_sector_table[1 .. 3], recorder_B);
                        break;
                    default:
                        assert(0);
                    }
                    //writefln("\n------ %d ------", test_no);
                    //writefln("dart_A.dump");
                    //dart_A.dump;
                    //writefln("dart_B.dump");
                    //dart_B.dump;
                    //writefln("dart_A.fingerprint=%s", dart_A.fingerprint.cutHex);
                    //writefln("dart_B.fingerprint=%s", dart_B.fingerprint.cutHex);

                    foreach (sector; dart_A.sectors) {
                        immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector).setExtension(
                                FileExtension
                                .hibon);
                        journal_filenames ~= journal_filename;
                        //BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                        auto journalfile = File(journal_filename, "w");
                        auto synch = new TestSynchronizer(journalfile, dart_A, dart_B);
                        auto dart_A_synchronizer = dart_A.synchronizer(synch, Rims(sector));
                        // D!(sector, "%x");
                        while (!dart_A_synchronizer.empty) {
                            (() @trusted => dart_A_synchronizer.call)();
                        }
                    }
                    foreach (journal_filename; journal_filenames) {
                        dart_A.replay(journal_filename);
                    }
                    //writefln("dart_A.dump");
                    //dart_A.dump;
                    //writefln("dart_B.dump");
                    //dart_B.dump;
                    //writefln("dart_A.fingerprint=%(%02x%)", dart_A.fingerprint);
                    //writefln("dart_B.fingerprint=%(%02x%)", dart_B.fingerprint);

                    assert(dart_A.fingerprint == dart_B.fingerprint);
                    if (test_no == 0) {
                        assert(dart_A.fingerprint.isinit);
                    }
                    else {
                        assert(!dart_A.fingerprint.isinit);
                    }
                }
            }

            { // Single element different sectors
                //
                // writefln("Test 0.1");
                DARTFile.create(filename_A, net);
                DARTFile.create(filename_B, net);
                RecordFactory.Recorder recorder_B;
                RecordFactory.Recorder recorder_A;
                // Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, No.read_only, HiRPC.init, from, to);
                auto dart_B = new DART(net, filename_B, No.read_only, HiRPC.init, from, to);
                string[] journal_filenames;
                scope (success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                    foreach (journal_filename; journal_filenames) {
                        journal_filename.remove;
                    }
                }

                write(dart_B, random_table[0 .. 1], recorder_B);
                write(dart_A, random_table[1 .. 2], recorder_A);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;

                foreach (sector; dart_A.sectors) {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    //BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto journalfile = File(journal_filename, "w");
                    auto synch = new TestSynchronizer(journalfile, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        (() @trusted => dart_A_synchronizer.call)();
                    }
                }
                foreach (journal_filename; journal_filenames) {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint == dart_B.fingerprint);
            }

            { // Synchronization of an empty DART 
                // from DART A against DART B with ONE archive when DART A is empty
                DARTFile.create(filename_A, net);
                DARTFile.create(filename_B, net);
                RecordFactory.Recorder recorder_B;
                // Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, No.read_only, HiRPC.init, from, to);
                auto dart_B = new DART(net, filename_B, No.read_only, HiRPC.init, from, to);
                //
                string[] journal_filenames;
                scope (success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                    foreach (journal_filename; journal_filenames) {
                        journal_filename.remove;
                    }
                }

                const ulong[] single_archive = [0xABB9_13ab_11ef_0923];

                write(dart_B, single_archive, recorder_B);
                // dart_B.dump;

                //
                // Synchronize DART_B -> DART_A
                //
                // Collecting the journal file

                foreach (sector; dart_A.sectors) {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    auto journalfile = File(journal_filename, "w");
                    auto synch = new TestSynchronizer(journalfile, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        (() @trusted => dart_A_synchronizer.call)();
                    }
                }
                foreach (journal_filename; journal_filenames) {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            { // Synchronization of an empty DART
                // from DART A against DART B when DART A is empty
                // writefln("Test 1");

                DARTFile.create(filename_A, net);
                DARTFile.create(filename_B, net);
                RecordFactory.Recorder recorder_B;
                // Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, No.read_only, HiRPC.init, from, to);
                auto dart_B = new DART(net, filename_B, No.read_only, HiRPC.init, from, to);
                //
                string[] journal_filenames;
                scope (success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                    foreach (journal_filename; journal_filenames) {
                        journal_filename.remove;
                    }
                }

                write(dart_B, random_table[0 .. 17], recorder_B);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;

                //
                // Synchronize DART_B -> DART_A
                //
                // Collecting the journal file

                foreach (sector; dart_A.sectors) {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    auto journalfile = File(journal_filename, "w");
                    auto synch = new TestSynchronizer(journalfile, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        (() @trusted => dart_A_synchronizer.call)();
                    }
                }
                foreach (journal_filename; journal_filenames) {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            { // Synchronization of a DART A which is a subset of DART B
                // writefln("Test 2");
                DARTFile.create(filename_A, net);
                DARTFile.create(filename_B, net);
                RecordFactory.Recorder recorder_A;
                RecordFactory.Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, No.read_only, HiRPC.init, from, to);
                auto dart_B = new DART(net, filename_B, No.read_only, HiRPC.init, from, to);
                //
                string[] journal_filenames;
                scope (success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }

                write(dart_A, random_table[0 .. 17], recorder_A);
                write(dart_B, random_table[0 .. 27], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach (sector; dart_A.sectors) {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    auto journalfile = File(journal_filename, "w");
                    auto synch = new TestSynchronizer(journalfile, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        (() @trusted { dart_A_synchronizer.call; })();
                    }
                }

                foreach (journal_filename; journal_filenames) {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            { // Synchronization of a DART A where DART A is a superset of DART B
                // writefln("Test 3");
                DARTFile.create(filename_A, net);
                DARTFile.create(filename_B, net);
                RecordFactory.Recorder recorder_A;
                RecordFactory.Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, No.read_only, HiRPC.init, from, to);
                auto dart_B = new DART(net, filename_B, No.read_only, HiRPC.init, from, to);
                //
                string[] journal_filenames;
                scope (success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }

                write(dart_A, random_table[0 .. 27], recorder_A);
                write(dart_B, random_table[0 .. 17], recorder_B);
                //                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach (sector; dart_A.sectors) {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    auto journalfile = File(journal_filename, "w");
                    auto synch = new TestSynchronizer(journalfile, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        (() @trusted { dart_A_synchronizer.call; })();
                    }
                }

                foreach (journal_filename; journal_filenames) {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            { // Synchronization of a DART A where DART A is complementary of DART B
                // writefln("Test 4");
                DARTFile.create(filename_A, net);
                DARTFile.create(filename_B, net);
                RecordFactory.Recorder recorder_A;
                RecordFactory.Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, No.read_only, HiRPC.init, from, to);
                auto dart_B = new DART(net, filename_B, No.read_only, HiRPC.init, from, to);
                //
                string[] journal_filenames;
                scope (success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }

                write(dart_A, random_table[0 .. 27], recorder_A);
                write(dart_B, random_table[28 .. 54], recorder_B);
                //                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach (sector; dart_A.sectors) {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    auto journalfile = File(journal_filename, "w");
                    auto synch = new TestSynchronizer(journalfile, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        (() @trusted { dart_A_synchronizer.call; })();
                    }
                }

                foreach (journal_filename; journal_filenames) {
                    // writefln("JOURNAL_FILENAME=%s", journal_filename);
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint == dart_B.fingerprint);
            }

            { // Synchronization of a DART A where DART A of DART B has common data
                DARTFile.create(filename_A, net);
                DARTFile.create(filename_B, net);
                RecordFactory.Recorder recorder_A;
                RecordFactory.Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, No.read_only, HiRPC.init, from, to);
                auto dart_B = new DART(net, filename_B, No.read_only, HiRPC.init, from, to);
                //
                string[] journal_filenames;
                scope (success) {
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }

                write(dart_A, random_table[0 .. 54], recorder_A);
                write(dart_B, random_table[28 .. 81], recorder_B);
                //                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach (sector; dart_A.sectors) {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    auto journalfile = File(journal_filename, "w");
                    auto synch = new TestSynchronizer(journalfile, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, Rims(sector));
                    while (!dart_A_synchronizer.empty) {
                        (() @trusted { dart_A_synchronizer.call; })();
                    }
                }

                foreach (journal_filename; journal_filenames) {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(!dart_A.fingerprint.isinit);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }
        }

    }
}
