module tagion.dart.DART;

import std.stdio;
import core.thread : Fiber;
import core.exception : RangeError;
import std.conv : ConvException;

//import std.stdio;

import std.traits : EnumMembers;
import std.format : format;
import std.range : isInputRange, ElementType;
import std.algorithm.iteration : filter;

import tagion.basic.Basic : FUNCTION_NAME, nameOf;
import tagion.basic.Types : Buffer;
import tagion.Keywords;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord : HiBONRecord, RecordType, GetLabel, Label;
import tagion.hibon.HiBONJSON;

import tagion.dart.DARTFile;
import tagion.crypto.SecureInterfaceNet : HashNet, SecureNet;
import tagion.communication.HiRPC : HiRPC, HiRPCMethod, Callers;
import tagion.basic.Basic : EnumText;

import tagion.utils.Miscellaneous : toHexString, cutHex;
import tagion.Keywords : isValid;

//import tagion.Base : Check;
import tagion.basic.TagionExceptions : Check;
import tagion.dart.BlockFile : BlockFile;
import tagion.dart.Recorder : RecordFactory, Archive;

alias hex = toHexString;

//import tagion.Debug;

enum SECTOR_MAX_SIZE = 1 << (ushort.sizeof * 8);
@safe
uint calc_to_value(const ushort from_sector, const ushort to_sector) pure nothrow
{
    return to_sector + ((from_sector >= to_sector) ? SECTOR_MAX_SIZE : 0);
}

@safe
uint calc_sector_size(const ushort from_sector, const ushort to_sector) pure nothrow
{
    immutable from = from_sector;
    immutable to = calc_to_value(from_sector, to_sector);
    return to - from;
}

/++
 some text
 +/
@safe
class DART : DARTFile
{
    immutable ushort from_sector;
    immutable ushort to_sector;
    const HiRPC hirpc;

    /** Creates DART with given net and by given file path
    *       @param net Represent SecureNet for initializing DART
    *       @param filename Represent path to DART file to open
    *       @param from_sector Represents from angle for DART sharding. In development.
    *       @param to_sector Represents to angle for DART sharding. In development.
    */
    this(const SecureNet net,
        string filename,
        const ushort from_sector = 0,
        const ushort to_sector = 0) @safe
    {
        super(net, filename);
        this.from_sector = from_sector;
        this.to_sector = to_sector;
        this.hirpc = HiRPC(net);
    }

    /** Creates DART with given net and by given file path safely with catching possible exceptions
    *       @param net Represent SecureNet for initializing DART
    *       @param filename Represent path to DART file to open
    *       @param exception Field used for returning exception in case when something gone wrong
    *       @param from_sector Represents from angle for DART sharding. In development.
    *       @param to_sector Represents to angle for DART sharding. In development.
    */
    this(const SecureNet net,
        string filename,
        out Exception exception,
        const ushort from_sector = 0,
        const ushort to_sector = 0) nothrow @safe
    {
        try
        {
            this(net, filename, from_sector, to_sector);
        }
        catch (Exception e)
        {
            exception = e;
        }
    }

    bool inRange(const ushort sector) pure nothrow
    {
        return SectorRange.sectorInRange(sector, from_sector, to_sector);
    }

    SectorRange sectors() pure nothrow
    {
        return SectorRange(from_sector, to_sector);
    }

    static struct SectorRange
    {
        private
        {
            @Label("sector") ushort _sector;
            @Label("from") ushort _from_sector;
            @Label("to") ushort _to_sector;
        }
        @property ushort from_sector() inout
        {
            return _from_sector;
        }

        @property ushort to_sector() inout
        {
            return _to_sector;
        }

        @Label("") protected bool flag;
        mixin HiBONRecord!(q{
                this(const ushort from_sector, const ushort to_sector) pure nothrow @nogc {
                    _from_sector = from_sector;
                    _to_sector = to_sector;
                    _sector = from_sector;
                }
            });

        bool isFullRange() const pure nothrow
        {
            return _from_sector == _to_sector;
        }

        bool inRange(const ushort sector) const pure nothrow
        {
            return sectorInRange(sector, _from_sector, _to_sector);
        }

        bool inRange(const Rims rims) const pure nothrow
        {
            return sectorInRange(rims.sector, _from_sector, _to_sector);
        }

        static bool sectorInRange(
            const ushort sector,
            const ushort from_sector,
            const ushort to_sector) pure nothrow
        {
            if (to_sector == from_sector)
            {
                return true;
            }
            else
            {
                immutable ushort sector_origin = (sector - from_sector) & ushort.max;
                immutable ushort to_origin = (to_sector - from_sector) & ushort.max;
                return (sector_origin < to_origin);
            }
        }

        bool empty() const pure nothrow
        {
            return !inRange(_sector) || flag;
        }

        void popFront()
        {
            if (!empty)
            {
                _sector++;
                if (_sector == _from_sector)
                    flag = true;
            }
        }

        ushort front() const pure nothrow
        {
            return _sector;
        }

        string toString() inout
        {
            return format("(%d, %d)", _from_sector, _to_sector);
        }

        unittest
        {
            enum full_dart_sectors_count = ushort.max + 1;
            { //SectorRange: full sector iterator
                auto sector_range = SectorRange(0, 0);
                auto iteration = 0;
                foreach (sector; sector_range)
                {
                    iteration++;

                    if (iteration > full_dart_sectors_count)
                        assert(0, "Range overflow");
                }
                assert(iteration == full_dart_sectors_count);
            }
            { //SectorRange: full sector iterator
                auto sector_range = SectorRange(5, 5);
                auto iteration = 0;
                foreach (sector; sector_range)
                {
                    iteration++;

                    if (iteration > full_dart_sectors_count)
                        assert(0, "Range overflow");
                }
                assert(iteration == full_dart_sectors_count);
            }
            { //SectorRange:
                auto sector_range = SectorRange(1, 10);
                auto iteration = 0;
                foreach (sector; sector_range)
                {
                    iteration++;

                    if (iteration > 9)
                        assert(0, "Range overflow");
                }
                assert(iteration == 9);
            }
        }
    }

    mixin(EnumText!(q{Quries}, Callers!DART));

    alias HiRPCSender = HiRPC.Sender;
    alias HiRPCReceiver = HiRPC.Receiver;

    @RecordType("Rims")
    struct Rims
    {
        Buffer rims;
        protected enum root_rim = [];
        static immutable root = Rims(root_rim);
        ushort sector() const pure nothrow
        in
        {
            pragma(msg, "fixme(vp) have to be check: rims is root_rim");

            assert(rims.length >= ushort.sizeof || rims.length == 0,
                format("Rims size must be %d or more ubytes contain a sector but contains %d", ushort.sizeof, rims
                    .length));
        }
        do
        {
            if (rims.length == 0)
                return ushort.init;
            assert(rims.length == 1);
            ushort result = ushort(rims[0]) + ushort(rims[1] << ubyte.sizeof * 8);
            return result;
        }

        mixin HiBONRecord!(
            q{
                this(Buffer r) {
                    rims=r;
                }

                this(const ushort sector)
                out {
                    assert(rims.length is ushort.sizeof);
                }
                do  {
                    rims=[sector >> 8*ubyte.sizeof, sector & ubyte.max];
                }
            });

        string toString() const pure nothrow
        {
            return rims.toHexString;
        }
    }

    static
    {
        @HiRPCMethod() const(HiRPCSender) dartRead(Range)(
            Range fingerprints,
            HiRPC hirpc = HiRPC(null),
            uint id = 0)
                if (isInputRange!Range && is(ElementType!Range : const(Buffer)))
        { //if (is(ForeachType!Range : Buffer)) {
            auto params = new HiBON;
            auto params_fingerprints = new HiBON;
            params_fingerprints = fingerprints.filter!(b => b.length !is 0);
            // foreach (i, b; fingerprints) {
            //     if (b.length !is 0) {
            //         params_fingerprints[i] = b;
            //     }
            // }
            params[Params.fingerprints] = params_fingerprints;
            return hirpc.dartRead(params, id);
        }

        @HiRPCMethod() const(HiRPCSender) dartRim(
            ref const Rims rims,
            HiRPC hirpc = HiRPC(null),
            uint id = 0)
        {
            return hirpc.dartRim(rims, id);
        }

        @HiRPCMethod() const(HiRPCSender) dartModify(
            ref const RecordFactory.Recorder recorder,
            HiRPC hirpc = HiRPC(null),
            uint id = 0)
        {
            return hirpc.dartModify(recorder, id);
        }

        @HiRPCMethod() const(HiRPCSender) dartBullseye(
            HiRPC hirpc = HiRPC(null),
            uint id = 0)
        {
            return hirpc.dartBullseye(null, id);
        }
    }

    /++
     + The dartBullseye method is called from opCall function
     + This function return current database bullseye.
     + @param received - the HiRPC received package
     + @param read_only - !Because this function is a read only the read_only parameter has no effect 
     + @return HiRPC result that contains current database bullseye
     +/
    @HiRPCMethod private const(HiRPCSender) dartBullseye(ref const(HiRPCReceiver) received, const bool read_only)
    in
    {
        mixin FUNCTION_NAME;
        assert(received.method.name == __FUNCTION_NAME__);
    }
    do
    {
        auto hibon_params = new HiBON;
        hibon_params[Params.bullseye] = bullseye;
        return hirpc.result(received, hibon_params);
    }
    /++
     + The dartRead method is called from opCall function
     + This function reads list of archive specified in the list of fingerprints.

     + The result is returned as a Recorder object
     + read from the DART

     + Note:
     + Because this function is a read only the read_only parameter has no effect

     + params: received is the HiRPC package
     + Example:
     ---
     + // HiRPC metode
     + {
     +  ....
     +    message : {
     +        method : "dartRead"
     +            params : {
     +                fingerprints : [
     +                     <GENERIC>,
     +                     <GENERIC>,
     +                     .....
     +                          ]
     +                     }
     +                 ...
     +                }
     +             }

     + // HiRPC Result
     +   {
     +   ....
     +       message : {
     +           result : {
     +               recoder : <DOCUMENT> // Recorder
     +                   limit   : <UINT32> // Optional
     +       // This parameter is set if fingerprints list exceeds the limit
     +                    }
     +               }
     +   }
     ---
     +/
    private const(HiRPCSender) dartRead(
        ref const(HiRPCReceiver) received,
        const bool read_only)
    in
    {
        mixin FUNCTION_NAME;
        assert(received.method.name == __FUNCTION_NAME__);
    }
    do
    {
        // HiRPC.check_element!Document(received.params, Params.fingerprints);
        const doc_fingerprints = received.method.params[Params.fingerprints].get!(Document);
        auto fingerprints = doc_fingerprints.range!(Buffer[]);
        const recorder = loads(fingerprints, Archive.Type.ADD);
        return hirpc.result(received, recorder.toDoc);
    }
    /++
     +  The dartRim method is called from opCall function
     +
     +  This method reads the Branches object at the specified rim
     +
     +  Note:
     +  Because this function is a read only the read_only parameter has no effect
     +
     +  Params:
     +      received is the HiRPC package
     +  Example:
     +  ---
     +  // HiRPC format
     +
     +  {
     +      ....
     +      message : {
     +        method : "dartRim",
     +            params : {
     +                rims : <GENERIC>
     +            }
     +        }
     +  }
     +
     +  // HiRPC Result
     +  {
     +    ....
     +    message : {
     +        result : {
     +            branches : <DOCUMENT> // Branches
     +            limit    : <UINT32> // Optional
     +                // This parameter is set if fingerprints list exceeds the limit
     +            }
     +        }
     +  }
     +
     + ----
     +/
    private const(HiRPCSender) dartRim(
        ref const(HiRPCReceiver) received,
        const bool read_only)
    in
    {
        mixin FUNCTION_NAME;
        assert(received.method.name == __FUNCTION_NAME__);
    }
    do
    {
        //HiRPC.check_element!Buffer(received.params, Params.rims);
        immutable params = received.params!Rims;

        const rim_branches = branches(params.rims);
        HiBON hibon_params;
        if (!rim_branches.empty)
        {
            //            hibon_params=new HiBON;
            hibon_params = rim_branches.toHiBON(true);
        }
        else if (params.rims.length > ushort.sizeof)
        {
            hibon_params = new HiBON;
            // It not branches so maybe it is an archive
            immutable key = params.rims[$ - 1];
            const super_branches = branches(params.rims[0 .. $ - 1]);
            if (!super_branches.empty)
            {
                immutable index = super_branches.indices[key];
                if (index !is INDEX_NULL)
                {
                    // The archive is added to a recorder
                    immutable data = blockfile.load(index);
                    const doc = Document(data);
                    auto super_recorder = recorder;
                    super_recorder.add(doc);
                    return hirpc.result(received, super_recorder);

                    //                    hibon_params[Params.recorder]=super_recorder.toDoc;
                }
            }
        }
        return hirpc.result(received, hibon_params);
    }

    /++
     +  The dartModify method is called from opCall function
     +
     +  This function execute and modify function according to the recorder parameter
     +
     +  Note:
     +  This function will fail if read only the read_only is true
     +
     +  Params: received is the HiRPC package
     +
     +   Example:
     +  ---
     +     // HiRPC format
     +   {
     +       ....
     +       message : {
     +           method : "dartModify"
     +           params : {
     +               recorder : <DOCUNENT> // Recorder object
     +           }
     +       }
     +   }
     +
     +  // HiRPC Result
     +  {
     +       ....
     +       message : {
     +           result   : {
     +           bullseye : <GENERIC> // Returns the update bullseye of the DART
     +           }
     +       }
     +  }
     +
     ---
     +/

    @HiRPCMethod private const(HiRPCSender) dartModify(
        ref const(HiRPCReceiver) received,
        const bool read_only)
    in
    {
        mixin FUNCTION_NAME;
        assert(received.method.name == __FUNCTION_NAME__);
    }
    do
    {
        HiRPC.check(!read_only, "The DART is read only");
        //HiRPC.check_element!Document(received.params, Params.recorder);
        //        scope recorder_doc=received.method.params[Params.recorder].get!Document;
        const recorder = manufactor.recorder(received.method.params);
        immutable bullseye = modify(recorder);
        auto hibon_params = new HiBON;
        hibon_params[Params.bullseye] = bullseye;
        return hirpc.result(received, hibon_params);
    }

    /++
     + This function handels HPRC quries to the DART
     + Params:
     +     received = Request HiRPC object
     + If read_only is true deleting and erasing data in the DART will return an error
     + Note.
     + When the DART is accessed from an external HiRPC this flag should be kept false.
     +
     + Returns:
     +     The response from HPRC if the method is supported
     +     else the response return is marked empty
     +/
    const(HiRPCSender) opCall(
        ref const(HiRPCReceiver) received,
        const bool read_only = true)
    {
        import std.conv : to;

        const method = received.method;
        switch (method.name)
        {
            static foreach (call; Callers!DART)
            {
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

    @safe
    interface Synchronizer
    {
        /++
         + Recommend to put a yield the SynchronizationFiber between send and receive between the DART's
         +/
        const(HiRPCReceiver) query(ref const(HiRPCSender) request);
        /++
         + Stores the add and remove actions in the journal replay log file
         +/
        void record(RecordFactory.Recorder recorder);
        /++
         + This function is call when hole branches doesn't exist in the foreign DART
         + and need to be removed in the local DART
         +/
        void remove_recursive(const Rims rims);
        /++
         + This function is called when the SynchronizationFiber run function finishes
         +/
        void finish();
        /++
         + Called in by the SynchronizationFiber constructor
         + which enable the query function to yield the run function in SynchronizationFiber
         +
         + Params:
         +     owner = is the dart to be modified
         +     fiber = is the synchronizer fiber object
         +/
        void set(DART owner, SynchronizationFiber fiber, HiRPC hirpc);
        /++
         + Returns:
         +     If the SynchronizationFiber has finished then this function returns `true`
         +/
        bool empty() const pure nothrow;
    }

    @RecordType("Journal") struct Journal
    {
        uint index;
        RecordFactory.Recorder recorder;
        enum indexName = GetLabel!(index).name;
        enum recorderName = GetLabel!(recorder).name;
        this(RecordFactory manufactor, const Document doc)
        {

            

                .check(isRecord(doc), format("Document is not a %s", ThisType.stringof));
            index = doc[indexName].get!uint;
            const recorder_doc = doc[recorderName].get!Document;
            recorder = manufactor.recorder(recorder_doc);
        }

        this(const RecordFactory.Recorder recorder, const uint index) const pure nothrow @nogc
        {
            this.recorder = recorder;
            this.index = index;
        }

        mixin HiBONRecord!"{}";
    }

    //            import std.stdio;
    @safe
    static abstract class StdSynchronizer : Synchronizer
    {

        protected SynchronizationFiber fiber; /// Contains the reference to SynchronizationFiber
        immutable uint chunck_size; /// Max number of archives operates in one recorder action
        protected
        {
            BlockFile journalfile; /// The actives is stored in this journal file. Which late can be run via the replay function
            bool _finished; /// Finish flag set when the Fiber function returns
            bool _timeout; /// Set via the timeout method to indicate and network timeout
            DART owner;
            uint index; /// Current block index
            HiRPC hirpc;
        }
        /++
         + Params:
         +     journal_filename = Name of blockfile used for recording the modification journal
         +                        Must be created by BlockFile.create method
         +     chunck_size = Set the max number of archives removed per chuck
         +/
        this(string journal_filename, const uint chunck_size = 0x400)
        {
            journalfile = BlockFile(journal_filename);
            this.chunck_size = chunck_size;
        }

        void record(const RecordFactory.Recorder recorder) @safe
        {
            if (!recorder.empty)
            {
                const journal = const(Journal)(recorder, index);
                auto hibon = new HiBON;
                const allocated = journalfile.save(journal.toDoc.serialize);
                index = allocated.begin_index;
                journalfile.root_index = index;
                scope (exit)
                {
                    journalfile.store;
                }
            }
        }

        void remove_recursive(const Rims params)
        {
            auto rim_walker = owner.rimWalkerRange(params.rims);
            uint count = 0;
            auto recorder_worker = owner.recorder;
            foreach (archive_data; rim_walker)
            {
                const archive_doc = Document(archive_data);

                recorder_worker.remove(archive_doc);
                count++;
                if (count > chunck_size)
                {
                    record(recorder_worker);
                    count = 0;
                    recorder_worker.clear;
                }
            }
            record(recorder_worker);
        }

        void set(
            DART owner,
            SynchronizationFiber fiber,
            HiRPC hirpc) nothrow @trusted
        {
            import std.conv : emplace;

            this.fiber = fiber;
            this.owner = owner;
            emplace(&this.hirpc, hirpc);
        }

        void finish()
        {
            journalfile.close;
            _finished = true;
        }

        void timeout()
        {
            journalfile.close;
            _timeout = true;
        }

        bool empty() const pure nothrow
        {
            return (_finished || _timeout);
        }

        bool timeout() const pure nothrow
        {
            return _timeout;
        }
    }

    SynchronizationFiber synchronizer(Synchronizer synchonizer, const Rims rims)
    {
        return new SynchronizationFiber(rims, synchonizer);
    }

    private DART that() pure nothrow @nogc
    {
        return this;
    }

    @safe
    class SynchronizationFiber : Fiber
    {
        protected Synchronizer sync;

        immutable(Rims) root_rims;

        this(const Rims root_rims, Synchronizer sync) @trusted
        {
            this.root_rims = root_rims;
            this.sync = sync;
            sync.set(that, this, that.hirpc);
            super(&run);
        }

        protected uint _id;
        @property uint id()
        {
            if (_id == 0)
            {
                _id = hirpc.generateId();
            }
            return _id;
        }

        final void run()
        in
        {
            assert(sync);
            assert(blockfile);
        }
        do
        {
            void iterate(const Rims params) @safe
            {
                //
                // Request Branches or Recorder at rims from the foreign DART.
                //
                const local_branches = branches(params.rims);
                const request_branches = dartRim(params, hirpc, id);
                const result_branches = sync.query(request_branches);
                if (!Branches.isRecord(result_branches.response.result))
                {
                    if (result_branches.isRecord!(RecordFactory.Recorder))
                    {
                        auto foreign_recoder = manufactor.recorder(result_branches.method.params);
                        sync.record(foreign_recoder);
                    }
                    //
                    // The foreign DART does not contain data at the rims
                    //
                    sync.remove_recursive(params);
                }
                else
                {
                    const foreign_branches = result_branches.result!Branches;
                    //
                    // Read all the archives from the foreign DART
                    //
                    const request_archives = dartRead(foreign_branches.fingerprints, hirpc, id);
                    const result_archives = sync.query(request_archives);
                    auto foreign_recoder = manufactor.recorder(result_archives.response.result);
                    //
                    // The rest of the fingerprints which are not in the foreign_branches must be sub-branches
                    // The archive fingerprints is removed from the branches
                    // Archive[Buffer] set_of_archives;
                    // foreach (a; foreign_recoder.archives[]) {
                    //     set_of_archives[a.fingerprint] = a;
                    // }
                    //                    sync.record(foreign_recoder);

                    auto foreign_fingerprints = foreign_branches.fingerprints.dup;
                    auto local_recorder = recorder;
                    scope (success)
                    {
                        sync.record(local_recorder);
                    }
                    foreach (k, foreign_print; foreign_fingerprints)
                    {
                        immutable key = cast(ubyte) k;
                        immutable sub_rims = Rims(params.rims ~ key);
                        immutable local_print = local_branches.fingerprint(key);
                        // auto foreign_archive = (foreign_print in set_of_archives);
                        auto foreign_archive = foreign_recoder.find(foreign_print);
                        if (foreign_archive)
                        {
                            if (local_print != foreign_print)
                            {
                                local_recorder.insert(foreign_archive);
                                sync.remove_recursive(sub_rims);
                            }
                        }
                        else if (foreign_print)
                        {
                            // Foreign is poits to branches
                            if (local_print)
                            {
                                const possible_branches_data = load(local_branches, key);
                                if (!Branches.isRecord(Document(possible_branches_data)))
                                {
                                    // If branch is an archive then it is removed because if it exists in foreign DART
                                    // this archive will be added later
                                    local_recorder.remove(local_print);
                                }
                            }
                            iterate(sub_rims);
                        }
                        else if (local_print)
                        {
                            sync.remove_recursive(sub_rims);
                        }
                    }
                }
            }
            //            scope local_branches=branches(root_rims);
            iterate(root_rims);
            sync.finish;
        }

        final bool empty() const pure nothrow
        {
            return sync.empty;
        }
    }

    /++
     + Replays the journal file to update the DART
     + The update blockfile can be generated from the synchroning process from an foreign dart
     +
     + If the process is broken for some reason this the resumed by running the replay function again
     + on the same block file
     +
     + Params:
     +     journal_filename = Name of the BlockFile to be replaied
     +
     + Throws:
     +     The function will throw an exception if something went wrong in the process.
     +/
    void replay(const(string) journal_filename)
    {
        auto journalfile = BlockFile(journal_filename, true);
        scope (exit)
        {
            journalfile.close;
        }
        // Adding and Removing archives
        void local_replay(bool remove)() @safe
        {
            for (uint index = journalfile.masterBlock.root_index; index !is INDEX_NULL;

                

                )
            {
                immutable data = journalfile.load(index);
                const doc = Document(data);
                auto journal_replay = Journal(manufactor, doc);
                index = journal_replay.index;
                auto action_recorder = recorder;
                foreach (a; journal_replay.recorder.archives[])
                {
                    static if (remove)
                    {
                        if (a.type is Archive.Type.REMOVE)
                        {
                            action_recorder.insert(a);
                        }
                    }
                    else
                    {
                        if (a.type !is Archive.Type.REMOVE)
                        {
                            action_recorder.insert(a);
                        }
                    }
                }
                modify(action_recorder);
            }

        }
        // All the remove actives is perform before the new archives are added
        // Remove
        local_replay!true;
        // Add
        local_replay!false;

    }

    version (unittest)
    {
        static class TestSynchronizer : StdSynchronizer
        {
            protected DART foreign_dart;
            protected DART owner;
            this(string journal_filename, DART owner, DART foreign_dart)
            {
                this.foreign_dart = foreign_dart;
                this.owner = owner;
                super(journal_filename);
            }

            //
            // This function emulates the connection between two DART's
            // in a single thread
            //
            const(HiRPCReceiver) query(ref const(HiRPCSender) request)
            {
                Document send_request_to_foreign_dart(const Document foreign_doc)
                {
                    //
                    // Remote excution
                    // Receive on the foreign end
                    const foreign_receiver = foreign_dart.hirpc.receive(foreign_doc);
                    // Make query in to the foreign DART
                    const foreign_response = foreign_dart(foreign_receiver);

                    return foreign_response.toDoc;
                }

                immutable foreign_doc = request.toDoc;
                (() @trusted { fiber.yield; })();
                // Here a yield loop should be implement to poll for response from the foriegn DART
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

    unittest
    {
        import tagion.utils.Random;
        import tagion.dart.BlockFile;
        import tagion.basic.Basic : tempfile, assumeTrusted;
        import tagion.dart.DARTFakeNet : DARTFakeNet;

        enum TEST_BLOCK_SIZE = 0x80;

        auto net = new DARTFakeNet("very_secret");

        immutable filename = fileId!DART.fullpath;
        immutable filename_A = fileId!DART("A_").fullpath;
        immutable filename_B = fileId!DART("B_").fullpath;
        immutable filename_C = fileId!DART("C_").fullpath;

        { // Remote Synchronization test

            import std.file : remove;

            auto rand = Random!ulong(1234_5678_9012_345UL);
            enum N = 1000;
            auto random_tabel = new ulong[N];
            foreach (ref r; random_tabel)
            {
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
                const ulong[] same_sector_tabel = [
                    0xABB9_13ab_cdef_1234,
                    0xABB9_14ab_cdef_1234,
                    0xABB9_15ab_cdef_1234

                ];
                // writefln("Test 0.0");
                foreach (test_no; 0 .. 3)
                {
                    DARTFile.create(filename_A);
                    DARTFile.create(filename_B);
                    RecordFactory.Recorder recorder_B;
                    RecordFactory.Recorder recorder_A;
                    // Recorder recorder_B;
                    auto dart_A = new DART(net, filename_A, from, to);
                    auto dart_B = new DART(net, filename_B, from, to);
                    string[] journal_filenames;
                    scope (success)
                    {
                        // writefln("Exit scope");
                        dart_A.close;
                        dart_B.close;
                        filename_A.remove;
                        filename_B.remove;
                        foreach (journal_filename; journal_filenames)
                        {
                            journal_filename.remove;
                        }
                    }

                    switch (test_no)
                    {
                    case 0:
                        write(dart_A, same_sector_tabel[0 .. 1], recorder_A);
                        write(dart_B, same_sector_tabel[0 .. 0], recorder_B);
                        break;
                    case 1:
                        write(dart_A, same_sector_tabel[0 .. 1], recorder_A);
                        write(dart_B, same_sector_tabel[1 .. 2], recorder_B);
                        break;
                    case 2:
                        write(dart_A, same_sector_tabel[0 .. 2], recorder_A);
                        write(dart_B, same_sector_tabel[1 .. 3], recorder_B);
                        break;
                    default:
                        assert(0);
                    }
                    // writefln("\n------ %d ------", test_no);
                    // writefln("dart_A.dump");
                    // dart_A.dump;
                    // writefln("dart_B.dump");
                    // dart_B.dump;
                    // writefln("dart_A.fingerprint=%s", dart_A.fingerprint.cutHex);
                    // writefln("dart_B.fingerprint=%s", dart_B.fingerprint.cutHex);

                    foreach (sector; dart_A.sectors)
                    {
                        immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                        journal_filenames ~= journal_filename;
                        BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                        auto synch = new TestSynchronizer(journal_filename, dart_A, dart_B);
                        auto dart_A_synchronizer = dart_A.synchronizer(synch, DART.Rims(sector));
                        // D!(sector, "%x");
                        while (!dart_A_synchronizer.empty)
                        {
                            (() @trusted => dart_A_synchronizer.call)();
                        }
                    }
                    foreach (journal_filename; journal_filenames)
                    {
                        dart_A.replay(journal_filename);
                    }
                    // writefln("dart_A.dump");
                    // dart_A.dump;
                    // writefln("dart_B.dump");
                    // dart_B.dump;
                    // writefln("dart_A.fingerprint=%s", dart_A.fingerprint.cutHex);
                    // writefln("dart_B.fingerprint=%s", dart_B.fingerprint.cutHex);

                    assert(dart_A.fingerprint == dart_B.fingerprint);
                    if (test_no == 0)
                    {
                        assert(dart_A.fingerprint is null);
                    }
                    else
                    {
                        assert(dart_A.fingerprint !is null);
                    }
                    //                   assert(0, "UNITTEST END");
                }
                //                   assert(0, "UNITTEST END");
            }

            { // Single element different sectors
                //
                // writefln("Test 0.1");
                DARTFile.create(filename_A);
                DARTFile.create(filename_B);
                RecordFactory.Recorder recorder_B;
                RecordFactory.Recorder recorder_A;
                // Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, from, to);
                auto dart_B = new DART(net, filename_B, from, to);
                string[] journal_filenames;
                scope (success)
                {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                    foreach (journal_filename; journal_filenames)
                    {
                        journal_filename.remove;
                    }
                }

                write(dart_B, random_tabel[0 .. 1], recorder_B);
                write(dart_A, random_tabel[1 .. 2], recorder_A);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;

                foreach (sector; dart_A.sectors)
                {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch = new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, DART.Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty)
                    {
                        (() @trusted => dart_A_synchronizer.call)();
                    }
                }
                foreach (journal_filename; journal_filenames)
                {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);
            }

            { // Synchronization of an empty DART
                // from DART A against DART B when DART A is empty
                // writefln("Test 1");

                DARTFile.create(filename_A);
                DARTFile.create(filename_B);
                RecordFactory.Recorder recorder_B;
                // Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, from, to);
                auto dart_B = new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope (success)
                {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                    foreach (journal_filename; journal_filenames)
                    {
                        journal_filename.remove;
                    }
                }

                write(dart_B, random_tabel[0 .. 17], recorder_B);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;

                //
                // Synchronize DART_B -> DART_A
                //
                // Collecting the journal file

                foreach (sector; dart_A.sectors)
                {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch = new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, DART.Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty)
                    {
                        (() @trusted => dart_A_synchronizer.call)();
                    }
                }
                foreach (journal_filename; journal_filenames)
                {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            { // Synchronization of a DART A which is a subset of DART B
                // writefln("Test 2");
                DARTFile.create(filename_A);
                DARTFile.create(filename_B);
                RecordFactory.Recorder recorder_A;
                RecordFactory.Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, from, to);
                auto dart_B = new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope (success)
                {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }

                write(dart_A, random_tabel[0 .. 17], recorder_A);
                write(dart_B, random_tabel[0 .. 27], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach (sector; dart_A.sectors)
                {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch = new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, DART.Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty)
                    {
                        (() @trusted { dart_A_synchronizer.call; })();
                    }
                }

                foreach (journal_filename; journal_filenames)
                {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            { // Synchronization of a DART A where DART A is a superset of DART B
                // writefln("Test 3");
                DARTFile.create(filename_A);
                DARTFile.create(filename_B);
                RecordFactory.Recorder recorder_A;
                RecordFactory.Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, from, to);
                auto dart_B = new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope (success)
                {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }

                write(dart_A, random_tabel[0 .. 27], recorder_A);
                write(dart_B, random_tabel[0 .. 17], recorder_B);
                //                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach (sector; dart_A.sectors)
                {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch = new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, DART.Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty)
                    {
                        (() @trusted { dart_A_synchronizer.call; })();
                    }
                }

                foreach (journal_filename; journal_filenames)
                {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            // ----------------
            { // Synchronization of a DART A where DART A is complementary of DART B
                // writefln("Test 4");
                DARTFile.create(filename_A);
                DARTFile.create(filename_B);
                RecordFactory.Recorder recorder_A;
                RecordFactory.Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, from, to);
                auto dart_B = new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope (success)
                {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }

                write(dart_A, random_tabel[0 .. 27], recorder_A);
                write(dart_B, random_tabel[28 .. 54], recorder_B);
                //                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach (sector; dart_A.sectors)
                {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch = new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, DART.Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty)
                    {
                        (() @trusted { dart_A_synchronizer.call; })();
                    }
                }

                foreach (journal_filename; journal_filenames)
                {
                    // writefln("JOURNAL_FILENAME=%s", journal_filename);
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            { // Synchronization of a DART A where DART A of DART B has common data
                // writefln("Test 5");
                DARTFile.create(filename_A);
                DARTFile.create(filename_B);
                RecordFactory.Recorder recorder_A;
                RecordFactory.Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, from, to);
                auto dart_B = new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope (success)
                {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }

                write(dart_A, random_tabel[0 .. 54], recorder_A);
                write(dart_B, random_tabel[28 .. 81], recorder_B);
                //                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach (sector; dart_A.sectors)
                {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch = new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, DART.Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty)
                    {
                        (() @trusted { dart_A_synchronizer.call; })();
                    }
                }

                foreach (journal_filename; journal_filenames)
                {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            { // Synchronization of a Large DART A where DART A of DART B has common data
                // writefln("Test 6");
                DARTFile.create(filename_A);
                DARTFile.create(filename_B);
                RecordFactory.Recorder recorder_A;
                RecordFactory.Recorder recorder_B;
                auto dart_A = new DART(net, filename_A, from, to);
                auto dart_B = new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope (success)
                {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }

                write(dart_A, random_tabel[0 .. 544], recorder_A);
                write(dart_B, random_tabel[288 .. 811], recorder_B);
                //                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach (sector; dart_A.sectors)
                {
                    immutable journal_filename = format("%s.%04x.dart_journal", tempfile, sector);
                    journal_filenames ~= journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch = new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer = dart_A.synchronizer(synch, DART.Rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty)
                    {
                        (() @trusted { dart_A_synchronizer.call; })();
                    }
                }

                foreach (journal_filename; journal_filenames)
                {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                //dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);
            }
        }
    }
}
