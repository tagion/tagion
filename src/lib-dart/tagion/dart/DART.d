module tagion.dart.DART;

//import std.stdio;
import core.thread : Fiber;
import core.exception : RangeError;
import std.conv : ConvException;
//import std.stdio;

import std.traits : EnumMembers;
import std.format : format;

import tagion.basic.Basic : Buffer, FUNCTION_NAME, nameOf;
import tagion.Keywords;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;

import tagion.dart.DARTFile;
import tagion.gossip.InterfaceNet : SecureNet;
import tagion.communication.HiRPC;
import tagion.basic.Basic : EnumText;

import tagion.utils.Miscellaneous : toHexString, cutHex;
import tagion.Keywords : isValid;
//import tagion.Base : Check;
import tagion.basic.TagionExceptions : Check;
import tagion.dart.BlockFile : BlockFile;

alias hex=toHexString;

//import tagion.Debug;

enum SECTOR_MAX_SIZE = 1 << (ushort.sizeof*8);
uint calc_to_value(const ushort from_sector, const ushort to_sector) pure nothrow {
    return to_sector+((from_sector >= to_sector)?SECTOR_MAX_SIZE:0);
}

uint calc_sector_size(const ushort from_sector, const ushort to_sector) pure nothrow {
    immutable from=from_sector;
    immutable to=calc_to_value(from_sector, to_sector);
    return to-from;
}

Buffer convert_sector_to_rims(const ushort sector) pure nothrow {
    Buffer result=[sector >> 8*ubyte.sizeof, sector & ubyte.max];
    return result;
}

/++
 some text
 +/

class DART : DARTFile, HiRPC.Supports {
    immutable ushort from_sector;
    immutable ushort to_sector;
    HiRPC hirpc;
    this(SecureNet net, string filename, const ushort from_sector=0, const ushort to_sector=0) {
        super(net, filename);
        this.from_sector=from_sector;
        this.to_sector=to_sector;
        this.hirpc.net = net;
    }
    bool inRange(const ushort sector) pure nothrow  {
        return SectorRange.sectorInRange(sector, from_sector, to_sector);
    }

    // override Buffer modify(Recorder modify_records) {
    //     modify_records.removeOutOfRange(from_sector, to_sector);
    //     return super.modify(modify_records);
    // }

    SectorRange sectors() {
        return SectorRange(from_sector, to_sector);
    }

    static struct SectorRange {
        private ushort _sector;
        private ushort _from_sector;
        private ushort _to_sector;
        @property ushort from_sector() inout { return _from_sector; }
        @property ushort to_sector() inout { return _to_sector; }
        protected bool flag;
        this(const ushort from_sector, const ushort to_sector) {
            _from_sector = from_sector;
            _to_sector = to_sector;
            _sector=from_sector;
        }

        bool isFullRange() const pure nothrow{
            return _from_sector == _to_sector;
        }

        bool inRange(const ushort sector) const pure nothrow{
            return sectorInRange(sector, _from_sector, _to_sector);
        }

        bool inRange(Buffer sector) const pure nothrow{
            if(sector == []) return true;
            return sectorInRange(sector[0] | sector[1], _from_sector, _to_sector);
        }

        static bool sectorInRange(const ushort sector, const ushort from_sector, const ushort to_sector) pure nothrow  {
            if ( to_sector == from_sector ) {
                return true;
            }
            else {
                immutable ushort sector_origin=(sector-from_sector) & ushort.max;
                immutable ushort to_origin=(to_sector-from_sector) & ushort.max;
                return ( sector_origin < to_origin );
            }
        }

        bool empty() const pure nothrow {
            return !inRange(_sector) || flag;
        }

        void popFront() {
            if (!empty) {
                _sector++;
                if(_sector == _from_sector) flag = true;
            }
        }

        ushort front() const pure nothrow {
            return _sector;
        }

        string toString() inout{
            import std.string;
            return format("(%d, %d)", _from_sector, _to_sector);
        }

        unittest{
            enum full_dart_sectors_count = ushort.max+1;
            {//SectorRange: full sector iterator
                auto sector_range = SectorRange(0, 0);
                auto iteration = 0;
                foreach(sector; sector_range){
                    iteration++;

                    if(iteration > full_dart_sectors_count) assert(0, "Range overflow");
                }
                assert(iteration == full_dart_sectors_count);
            }
            {//SectorRange: full sector iterator
                auto sector_range = SectorRange(5, 5);
                auto iteration = 0;
                foreach(sector; sector_range){
                    iteration++;

                    if(iteration > full_dart_sectors_count) assert(0, "Range overflow");
                }
                assert(iteration == full_dart_sectors_count);
            }
            {//SectorRange:
                auto sector_range = SectorRange(1, 10);
                auto iteration = 0;
                foreach(sector; sector_range){
                    iteration++;

                    if(iteration > 9) assert(0, "Range overflow");
                }
                assert(iteration == 9);
            }
        }
    }
    protected enum _quries = [
        nameOf!dartRead,
        nameOf!dartRim,
        nameOf!dartModify,
        nameOf!dartFullRead
        ];


    mixin(EnumText!("Quries", _quries));

    mixin HiRPC.Support!Quries;

    alias HiRPCSender=HiRPC.HiRPCSender;
    alias HiRPCReceiver=HiRPC.HiRPCReceiver;

    static {
        const(HiRPCSender) dartRead(Range)(scope Range fingerprints, HiRPC hirpc = HiRPC(null), uint id = 0) { //if (is(ForeachType!Range : Buffer)) {
            auto params=new HiBON;
            auto params_fingerprints=new HiBON;
            foreach(i, b; fingerprints) {
                if ( b.length !is 0 ) {
                    params_fingerprints[i]=b;
                }
            }
            params[Params.fingerprints]=params_fingerprints;
            return hirpc.dartRead(params, id);
        }

        const(HiRPCSender) dartRim(scope const(Buffer) rims, HiRPC hirpc = HiRPC(null), uint id = 0) {
            auto params=new HiBON;
            params[Params.rims]=rims;
            return hirpc.dartRim(params, id);
        }

        const(HiRPCSender) dartModify(scope const Recorder recorder, HiRPC hirpc = HiRPC(null), uint id = 0) {
            auto params=new HiBON;
            params[Params.recorder]=recorder.toHiBON;
            return hirpc.dartModify(params, id);
        }
    }

 private const(HiRPCSender) dartFullRead(ref const(HiRPCReceiver) received, const bool read_only)
        in {
            mixin FUNCTION_NAME;
            assert(received.message.method == __FUNCTION_NAME__);
        }
    do {
        // HiRPC.check_element!Document(received.params, Params.fingerprints);
        scope result=loadAll(Recorder.Archive.Type.ADD);
        return hirpc.result(received, result);
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
    private const(HiRPCSender) dartRead(ref const(HiRPCReceiver) received, const bool read_only)
        in {
            mixin FUNCTION_NAME;
            assert(received.message.method == __FUNCTION_NAME__);
        }
    do {
        HiRPC.check_element!Document(received.params, Params.fingerprints);
        scope doc_fingerprints=received.params[Params.fingerprints].get!(Document);
        scope fingerprints=doc_fingerprints.range!(Buffer[]);
        scope recorder=loads(fingerprints, Recorder.Archive.Type.ADD);
        return hirpc.result(received, recorder.toHiBON);
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
    private const(HiRPCSender) dartRim(ref const(HiRPCReceiver) received, const bool read_only)
        in {
            mixin FUNCTION_NAME;
            assert(received.message.method == __FUNCTION_NAME__);
        }
    do {
        HiRPC.check_element!Buffer(received.params, Params.rims);
        immutable rims=received.params[Params.rims].get!Buffer;
        auto hibon_params=new HiBON;
        scope rim_branches=branches(rims);
        if ( !rim_branches.empty ) {
            hibon_params[Params.branches]=rim_branches.toHiBON(true);
        }
        else if ( rims.length > ushort.sizeof ) {
            // It not branches so maybe it is an archive
            immutable key=rims[$-1];
            scope super_branches=branches(rims[0..$-1]);
            if ( !super_branches.empty ) {
                immutable index=super_branches.indices[key];
                if ( index !is INDEX_NULL ) {
                    // The archive is added to a recorder
                    immutable data=blockfile.load(index);
                    auto super_recorder=recorder;
                    super_recorder.add(data);
                    hibon_params[Params.recorder]=super_recorder.toHiBON;
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

    private const(HiRPCSender) dartModify(ref const(HiRPCReceiver) received, const bool read_only)
        in {
            mixin FUNCTION_NAME;
            assert(received.message.method == __FUNCTION_NAME__);
        }
    do {
        HiRPC.check(!read_only, "The DART is read only");
        HiRPC.check_element!Document(received.params, Params.recorder);
        scope recorder_doc=received.params[Params.recorder].get!Document;
        scope recorder=Recorder(net, recorder_doc);
        immutable bullseye=modify(recorder);
        auto hibon_params=new HiBON;
        hibon_params[Params.bullseye]=bullseye;
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
    const(HiRPCSender) opCall(ref scope const(HiRPCReceiver) received, const bool read_only=true) {
        switch (received.message.method) {
            static foreach(method; EnumMembers!Quries) {
                mixin(format("case Quries.%s: return %s(received, read_only);", method, method));
            }
        default:
            immutable message=format("Method '%s' not supported", received.message.method);
            return hirpc.error(received, message, 22);
        }
        assert(0);
    }

    interface Synchronizer {
        /++
         + Recommend to put a yield the SynchronizationFiber between send and receive between the DART's
         +/
        const(HiRPCReceiver) query(scope ref const(HiRPCSender) request);
        /++
         + Stores the add and remove actions in the journal replay log file
         +/
        void record(Recorder recorder);
        /++
         + This function is call when hole branches doesn't exist in the foreign DART
         + and need to be removed in the local DART
         +/
        void remove_recursive(const(Buffer) rims);
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

            import std.stdio;
    static abstract class StdSynchronizer : Synchronizer {

        protected SynchronizationFiber fiber; /// Contains the reference to SynchronizationFiber
        immutable uint chunck_size;         /// Max number of archives operates in one recorder action
        protected {
            BlockFile journalfile;          /// The actives is stored in this journal file. Which late can be run via the replay function
            bool _finished;                 /// Finish flag set when the Fiber function returns
            bool _timeout;                  /// Set via the timeout method to indicate and network timeout
            DART owner;
            uint index;                     /// Current block index
            HiRPC hirpc;
        }
        /++
         + Params:
         +     journal_filename = Name of blockfile used for recording the modification journal
         +                        Must be created by BlockFile.create method
         +     chunck_size = Set the max number of archives removed per chuck
         +/
        this(string journal_filename, const uint chunck_size=0x400) {
            journalfile=BlockFile(journal_filename);
            this.chunck_size=chunck_size;
        }

        void record(Recorder recorder) {
//            writefln("RECORD %s", recorder.empty);
            if ( !recorder.empty ) {
                auto hibon=new HiBON;
                hibon[Params.index]=index;
                hibon[Params.recorder]=recorder.toHiBON;
                auto data=hibon.serialize;
                auto doc=Document(data);
//                writefln("--->%s", doc.toText);
                const allocated=journalfile.save(data);
                index=allocated.begin_index;
                journalfile.root_index=index;
                scope(exit) {
                    journalfile.store;
                }
            }
//            writeln("END RECORD");
        }

        void remove_recursive(Buffer rims) {
            scope rim_walker=owner.rimWalkerRange(rims);
            uint count=0;
            scope recorder_worker=owner.recorder;
//            writefln("Recursive remove %s", rims.cutHex);
            foreach(archive_data; rim_walker) {
                recorder_worker.remove(archive_data);
                auto archive_doc=Document(archive_data);
//                writefln("\tremove archive %s", archive_doc.toText);
//                scope archive=new Recorder.Archive(owner.net, archive_doc);
                // immutable print=owner.net.calcHash(archive_data);
                // auto doc=Document(archive_data);

                //recorder_worker.remove_by_print(archive.fingerprint);
                count++;
                if ( count > chunck_size ) {
                    // Remove the collected archives
                    //owner.modify(recorder_worker);
                    record(recorder_worker);
                    count=0;
                    // journalfile.save(recorder_worker.toHiBON.serialize);
                    // journalfile.store;
                    recorder_worker.clear;
                }
            }
            record(recorder_worker);
        }

        void set(DART owner, SynchronizationFiber fiber, HiRPC hirpc) nothrow {
            this.fiber=fiber;
            this.owner=owner;
            this.hirpc = hirpc;
        }

        void finish() {
            journalfile.close;
            _finished=true;
        }

        void timeout() {
            journalfile.close;
            _timeout=true;
        }

        bool empty() const pure nothrow {
            return (_finished || _timeout);
        }

        bool timeout() const pure nothrow {
            return _timeout;
        }
    }

    SynchronizationFiber synchronizer(Synchronizer synchonizer, const(Buffer) rims) {
        return new SynchronizationFiber(rims, synchonizer);
    }

    private DART that() {
        return this;
    }

    class SynchronizationFiber : Fiber {
        protected Synchronizer sync;

        immutable(Buffer) root_rims;

        this(Buffer root_rims, Synchronizer sync) {
            this.root_rims=root_rims;
            this.sync=sync;
            sync.set(that, this, that.hirpc);
            super(&run);
        }

        protected uint _id;
        @property uint id(){
            if(_id==0){
                _id = hirpc.generateId();
            }
            return _id;
        }

        final void run()
            in {
                assert(sync);
                assert(blockfile);
            }
        do {
            import std.stdio;
            void iterate(Buffer rims, immutable(string) indent) {
                //
                // Request Branches or Recorder at rims from the foreign DART.
                //
                scope local_branches=branches(rims);
                scope request_branches=dartRim(rims, hirpc, id);
                scope result_branches =sync.query(request_branches);
//                scope Recorder foreign_recoder;
                if ( !result_branches.params.hasElement(Params.branches) ) {
                    if ( result_branches.params.hasElement(Params.recorder) ) {
                        scope foreign_recoder=Recorder(net, result_branches.params);
                        sync.record(foreign_recoder);
                    }
                    //
                    // The foreign DART does not contain data at the rims
                    //
                    sync.remove_recursive(rims);
                }
                else {
                    scope foreign_branches_doc=result_branches.params[Params.branches].get!Document;
                    scope foreign_branches=Branches(foreign_branches_doc);
                    //
                    // Read all the archives from the foreign DART
                    //
                    scope request_archives=dartRead(foreign_branches.fingerprints, hirpc, id);
                    scope result_archives=sync.query(request_archives);
                    scope foreign_recoder=Recorder(net, result_archives.params);
                    //
                    // The rest of the fingerprints which are not in the foreign_branches must be sub-branches
                    // The archive fingerprints is removed from the branches
                    Recorder.Archive[Buffer] set_of_archives;
                    foreach(a; foreign_recoder.archives[]) {
                        set_of_archives[a.fingerprint]=a;
                    }
//                    sync.record(foreign_recoder);

                    auto foreign_fingerprints=foreign_branches.fingerprints.dup;
                    auto local_recorder=recorder;
                    scope(success) {
                        sync.record(local_recorder);
                    }
                    foreach(k, foreign_print; foreign_fingerprints) {
                        immutable key=cast(ubyte)k;
                        immutable sub_rims=rims~key;
                        immutable local_print  =local_branches.fingerprint(key);
                        auto foreign_archive=(foreign_print in set_of_archives);
                        if ( foreign_archive ) {
                            if ( local_print != foreign_print ) {
                                local_recorder.insert(*foreign_archive);
                                sync.remove_recursive(sub_rims);
                            }
                        }
                        else if ( foreign_print ) {
                            // Foreign is poits to branches
                            if ( local_print ) {
                                scope possible_branches_data=load(local_branches, key);
                                if ( !Branches.isBranches(Document(possible_branches_data)) ) {
                                    // If branch is an archive then it is removed because if it exists in foreign DART
                                    // this archive will be added later
                                    local_recorder.remove_by_print(local_print);
                                }
                            }
                            iterate(sub_rims, indent~"**");
                        }
                        else if ( local_print ) {
                            sync.remove_recursive(sub_rims);
                        }
                    }
                }
            }
//            scope local_branches=branches(root_rims);
            iterate(root_rims, "");
            import std.stdio;
//            sync.store_remove_recursive;
            sync.finish;
        }

        final bool empty() const pure nothrow {
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
    void replay(const(string) journal_filename) {
        auto journalfile=BlockFile(journal_filename, true);
        scope(exit) {
            journalfile.close;
        }
        // Adding and Removing archives
        void local_replay(bool remove)() {
//            writefln("journalfile.masterBlock.root_index=%d", journalfile.masterBlock.root_index);
            for(uint index=journalfile.masterBlock.root_index; index !is INDEX_NULL;) {
//                writefln("INDEX=%d", index);
                immutable data=journalfile.load(index);
                scope doc=Document(data);
                index=doc[Params.index].get!uint;

                scope replay_recorder_doc=doc[Params.recorder].get!Document;
//                writefln("%s", replay_recorder_doc.toText);

                scope replay_recorder=Recorder(net, replay_recorder_doc);
                scope action_recorder=recorder;
                foreach(a; replay_recorder.archives[]) {
                    static if (remove) {
                        if ( a.type is Recorder.Archive.Type.REMOVE ) {
                            action_recorder.insert(a);
                        }
                    }
                    else {
                        if ( a.type !is Recorder.Archive.Type.REMOVE ) {
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

    version(unittest) {
        static class TestSynchronizer : StdSynchronizer {
            protected DART foreign_dart;
            protected DART owner;
            this(string journal_filename, DART owner, DART foreign_dart) {
                this.foreign_dart=foreign_dart;
                this.owner=owner;
                super(journal_filename);
            }

            //
            // This function emulates the connection between two DART's
            // in a single thread
            //
            const(HiRPCReceiver) query(ref scope const(HiRPCSender) request) {
                Buffer send_request_to_forien_dart(Buffer data){
                    //
                    // Remote excution
                    // Receive on the foreign end
                    auto foreigen_doc=Document(data);
                    const foreigen_receiver=foreign_dart.hirpc.receive(foreigen_doc);
                    // Make query in to the foreign DART
                    const foreign_respones=foreign_dart(foreigen_receiver);
                    immutable foreign_data=foreign_dart.hirpc.toHiBON(foreign_respones).serialize;
                    return foreign_data;
                }

                immutable foreign_data=owner.hirpc.toHiBON(request).serialize;
                fiber.yield;
                // Here a yield loop should be implement to poll for response from the foriegn DART
                // A timeout should also be implemented in this poll loop
                immutable response_data=send_request_to_forien_dart(foreign_data);
                //
                // Process the response returned for the foreign DART
                //
                auto doc=Document(response_data);
                auto received=owner.hirpc.receive(doc);
                return received;
            }
        }


    }
    version(none)
    unittest {
        import tagion.utils.Random;
        import tagion.dart.BlockFile;
        import tagion.Base : tempfile;

        auto net=new TestNet;

        immutable filename=fileId!DART.fullpath;
        immutable filename_A=fileId!DART("A_").fullpath;
        immutable filename_B=fileId!DART("B_").fullpath;
        immutable filename_C=fileId!DART("C_").fullpath;

        { // Remote Synchronization test

            import std.file : remove;
            auto rand=Random!ulong(1234_5678_9012_345UL);
            enum N=1000;
            auto random_tabel=new ulong[N];
            foreach(ref r; random_tabel) {
                immutable sector=rand.value(0x0000_0000_0000_ABBAUL, 0x0000_0000_0000_ABBDUL) << (8*6);
                r=rand.value(0x0000_1234_5678_0000UL | sector, 0x0000_1334_FFFF_0000UL | sector);
            }

            //
            // The the following unittest dart A and B covers the same range angle
            //
            enum from=0xABB9;
            enum to=0xABBD;

            import std.stdio;
            { // Single element same sector sectors
               const ulong[] same_sector_tabel=[
                   0xABB9_13ab_cdef_1234,
                   0xABB9_14ab_cdef_1234,
                   0xABB9_15ab_cdef_1234

                   ];
               // writefln("Test 0.0");
               foreach(test_no; 0..3) {
                   DARTFile.create_dart(filename_A);
                   DARTFile.create_dart(filename_B);
                   Recorder recorder_B;
                   Recorder recorder_A;
                   // Recorder recorder_B;
                   auto dart_A=new DART(net, filename_A, from, to);
                   auto dart_B=new DART(net, filename_B, from, to);
                   string[] journal_filenames;
                   scope(success) {
                       // writefln("Exit scope");
                       dart_A.close;
                       dart_B.close;
                       filename_A.remove;
                       filename_B.remove;
                       foreach(journal_filename; journal_filenames) {
                           journal_filename.remove;
                       }
                   }

                   switch(test_no) {
                   case 0:
                       write(dart_A, same_sector_tabel[0..1], recorder_A);
                       write(dart_B, same_sector_tabel[0..0], recorder_B);
                       break;
                   case 1:
                       write(dart_A, same_sector_tabel[0..1], recorder_A);
                       write(dart_B, same_sector_tabel[1..2], recorder_B);
                       break;
                   case 2:
                       write(dart_A, same_sector_tabel[0..2], recorder_A);
                       write(dart_B, same_sector_tabel[1..3], recorder_B);
                       break;
                   default:
                       assert(0);
                   }
                   // writefln("dart_A.dump");
                   // dart_A.dump;
                   // writefln("dart_B.dump");
                   // dart_B.dump;
                   // writefln("dart_A.fingerprint=%s", dart_A.fingerprint.cutHex);
                   // writefln("dart_B.fingerprint=%s", dart_B.fingerprint.cutHex);

                   foreach(sector; dart_A.sectors) {
                       immutable journal_filename=format("%s.%04x.dart_journal", tempfile ,sector);
                       journal_filenames~=journal_filename;
                       BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                       auto synch=new TestSynchronizer(journal_filename, dart_A, dart_B);
                       auto dart_A_synchronizer=dart_A.synchronizer(synch, convert_sector_to_rims(sector));
                       // D!(sector, "%x");
                       while (!dart_A_synchronizer.empty) {
                           dart_A_synchronizer.call;
                       }
                   }
                   foreach(journal_filename; journal_filenames) {
                       dart_A.replay(journal_filename);
                   }
                   // writefln("dart_A.dump");
                   // dart_A.dump;
                   // writefln("dart_B.dump");
                   // dart_B.dump;
                   // writefln("dart_A.fingerprint=%s", dart_A.fingerprint.cutHex);
                   // writefln("dart_B.fingerprint=%s", dart_B.fingerprint.cutHex);

                   assert(dart_A.fingerprint == dart_B.fingerprint);
                   if (test_no == 0) {
                       assert(dart_A.fingerprint is null);
                   }
                   else {
                       assert(dart_A.fingerprint !is null);
                   }
//                   assert(0, "UNITTEST END");
               }
//                   assert(0, "UNITTEST END");
            }

            { // Single element different sectors
              //
               // writefln("Test 0.1");
               DARTFile.create_dart(filename_A);
               create_dart(filename_B);
               Recorder recorder_B;
               Recorder recorder_A;
               // Recorder recorder_B;
               auto dart_A=new DART(net, filename_A, from, to);
               auto dart_B=new DART(net, filename_B, from, to);
               string[] journal_filenames;
               scope(success) {
                   // writefln("Exit scope");
                   dart_A.close;
                   dart_B.close;
                   filename_A.remove;
                   filename_B.remove;
                   foreach(journal_filename; journal_filenames) {
                       journal_filename.remove;
                   }
               }

                write(dart_B, random_tabel[0..1], recorder_B);
                write(dart_A, random_tabel[1..2], recorder_A);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;

               foreach(sector; dart_A.sectors) {
                   immutable journal_filename=format("%s.%04x.dart_journal", tempfile ,sector);
                   journal_filenames~=journal_filename;
                   BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                   auto synch=new TestSynchronizer(journal_filename, dart_A, dart_B);
                   auto dart_A_synchronizer=dart_A.synchronizer(synch, convert_sector_to_rims(sector));
                   // D!(sector, "%x");
                   while (!dart_A_synchronizer.empty) {
                       dart_A_synchronizer.call;
                   }
               }
               foreach(journal_filename; journal_filenames) {
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
              // from Dart A against Dart B when Dart A is empty
               // writefln("Test 1");

                DARTFile.create_dart(filename_A);
                create_dart(filename_B);
                Recorder recorder_B;
                // Recorder recorder_B;
                auto dart_A=new DART(net, filename_A, from, to);
                auto dart_B=new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope(success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                    foreach(journal_filename; journal_filenames) {
                        journal_filename.remove;
                    }
                }

                write(dart_B, random_tabel[0..17], recorder_B);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;

                //
                // Synchronize DART_B -> DART_A
                //
                // Collecting the journal file

                foreach(sector; dart_A.sectors) {
                    immutable journal_filename=format("%s.%04x.dart_journal", tempfile ,sector);
                    journal_filenames~=journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch=new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer=dart_A.synchronizer(synch, convert_sector_to_rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        dart_A_synchronizer.call;
                    }
                }
                foreach(journal_filename; journal_filenames) {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            // version(none)
            { // Synchronization of a Dart A which is a subset of Dart B
                // writefln("Test 2");
                create_dart(filename_A);
                create_dart(filename_B);
                Recorder recorder_A;
                Recorder recorder_B;
                auto dart_A=new DART(net, filename_A, from, to);
                auto dart_B=new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope(success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }


                write(dart_A, random_tabel[0..17], recorder_A);
                write(dart_B, random_tabel[0..27], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach(sector; dart_A.sectors) {
                    immutable journal_filename=format("%s.%04x.dart_journal", tempfile ,sector);
                    journal_filenames~=journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch=new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer=dart_A.synchronizer(synch, convert_sector_to_rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        dart_A_synchronizer.call;
                    }
                }

                foreach(journal_filename; journal_filenames) {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);

            }

            // version(none)
            { // Synchronization of a DART A where DART A is a superset of DART B
                // writefln("Test 3");
                create_dart(filename_A);
                create_dart(filename_B);
                Recorder recorder_A;
                Recorder recorder_B;
                auto dart_A=new DART(net, filename_A, from, to);
                auto dart_B=new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope(success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }


                write(dart_A, random_tabel[0..27], recorder_A);
                write(dart_B, random_tabel[0..17], recorder_B);
//                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach(sector; dart_A.sectors) {
                    immutable journal_filename=format("%s.%04x.dart_journal", tempfile ,sector);
                    journal_filenames~=journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch=new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer=dart_A.synchronizer(synch, convert_sector_to_rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        dart_A_synchronizer.call;
                    }
                }

//                version(none)
                foreach(journal_filename; journal_filenames) {
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
                create_dart(filename_A);
                create_dart(filename_B);
                Recorder recorder_A;
                Recorder recorder_B;
                auto dart_A=new DART(net, filename_A, from, to);
                auto dart_B=new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope(success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }


                write(dart_A, random_tabel[0..27], recorder_A);
                write(dart_B, random_tabel[28..54], recorder_B);
//                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach(sector; dart_A.sectors) {
                    immutable journal_filename=format("%s.%04x.dart_journal", tempfile ,sector);
                    journal_filenames~=journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch=new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer=dart_A.synchronizer(synch, convert_sector_to_rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        dart_A_synchronizer.call;
                    }
                }

//                version(none)
                foreach(journal_filename; journal_filenames) {
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
                create_dart(filename_A);
                create_dart(filename_B);
                Recorder recorder_A;
                Recorder recorder_B;
                auto dart_A=new DART(net, filename_A, from, to);
                auto dart_B=new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope(success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }


                write(dart_A, random_tabel[0..54], recorder_A);
                write(dart_B, random_tabel[28..81], recorder_B);
//                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach(sector; dart_A.sectors) {
                    immutable journal_filename=format("%s.%04x.dart_journal", tempfile ,sector);
                    journal_filenames~=journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch=new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer=dart_A.synchronizer(synch, convert_sector_to_rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        dart_A_synchronizer.call;
                    }
                }

//                version(none)
                foreach(journal_filename; journal_filenames) {
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
                create_dart(filename_A);
                create_dart(filename_B);
                Recorder recorder_A;
                Recorder recorder_B;
                auto dart_A=new DART(net, filename_A, from, to);
                auto dart_B=new DART(net, filename_B, from, to);
                //
                string[] journal_filenames;
                scope(success) {
                    // writefln("Exit scope");
                    dart_A.close;
                    dart_B.close;
                    filename_A.remove;
                    filename_B.remove;
                }


                write(dart_A, random_tabel[0..544], recorder_A);
                write(dart_B, random_tabel[288..811], recorder_B);
//                write(dart_B, random_table[0..17], recorder_B);
                // writefln("bulleye_A=%s bulleye_B=%s", dart_A.fingerprint.cutHex,  dart_B.fingerprint.cutHex);
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint != dart_B.fingerprint);

                foreach(sector; dart_A.sectors) {
                    immutable journal_filename=format("%s.%04x.dart_journal", tempfile ,sector);
                    journal_filenames~=journal_filename;
                    BlockFile.create(journal_filename, DART.stringof, TEST_BLOCK_SIZE);
                    auto synch=new TestSynchronizer(journal_filename, dart_A, dart_B);
                    auto dart_A_synchronizer=dart_A.synchronizer(synch, convert_sector_to_rims(sector));
                    // D!(sector, "%x");
                    while (!dart_A_synchronizer.empty) {
                        dart_A_synchronizer.call;
                    }
                }

//                version(none)
                foreach(journal_filename; journal_filenames) {
                    dart_A.replay(journal_filename);
                }
                // writefln("dart_A.dump");
                // dart_A.dump;
                // writefln("dart_B.dump");
                // dart_B.dump;
                assert(dart_A.fingerprint !is null);
                assert(dart_A.fingerprint == dart_B.fingerprint);
            }
        }
    }
}
