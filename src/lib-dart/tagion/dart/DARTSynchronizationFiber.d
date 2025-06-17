module tagion.dart.DARTSynchronizationFiber;

import core.exception : RangeError;
import core.thread : Fiber;
import core.memory : pageSize;
import std.conv : ConvException;
import std.range : empty, zip;
import std.stdio;
import tagion.dart.synchronizer;
import tagion.dart.DARTRim;
import tagion.dart.DART;
import CRUD = tagion.dart.DARTcrud;
import tagion.dart.DARTFile;
import tagion.dart.DARTBasic;
import tagion.communication.HiRPC;
import tagion.hibon.Document;
import tagion.dart.Recorder;
import tagion.basic.basic : isinit;

@safe
class DARTSynchronizationFiber : Fiber {
    protected Synchronizer sync;

    immutable(Rims) root_rims;
    size_t fiberPageSize;
    DART owner;

    this(Synchronizer sync,
        DART owner,
        const Rims root_rims,
        size_t sz = pageSize * Fiber.defaultStackPages,
        size_t guardPageSize = pageSize,
    ) @trusted {
        this.sync = sync;
        this.owner = owner,
        this.root_rims = root_rims;
        // sync.set(owner, this, owner.hirpc);
        super(&run, sz, guardPageSize);
    }

    protected uint _id;
    /* 
         * Id for the HiRPC
         * Returns: HiRPC id
        */
    @property uint id() {
        if (_id == 0) {
            _id = owner.hirpc.generateId();
        }
        return _id;
    }

    /**
         * Function to handle synchronization stage for the DART
         */
    final void run()
    in {
        assert(sync);
        // assert(owner.blockfile);
    }
    do {
        void iterate(const Rims params) @safe {
            //
            // Request Branches or Recorder at rims from the foreign DART.
            //
            const local_branches = owner.branches(params.path);
            // const request_branches = CRUD.dartRim(params, owner.hirpc, id);
            const request_branches = CRUD.dartRim(rims: params, hirpc: owner.hirpc, id: id);
            const result_branches = sync.query(request_branches);
            if (DARTFile.Branches.isRecord(result_branches.response.result)) {
                const foreign_branches = result_branches.result!(DARTFile.Branches);
                //
                // Read all the archives from the foreign DART
                //
                const request_archives = CRUD.dartRead(
                    foreign_branches
                        .dart_indices, owner.hirpc, id);
                const result_archives = sync.query(request_archives);
                auto foreign_recoder = owner.recorder(result_archives.response.result);
                //
                // The rest of the fingerprints which are not in the foreign_branches must be sub-branches
                // 

                auto local_recorder = owner.recorder;
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
                            const possible_branches_data = owner.load(local_branches, key);
                            if (!DARTFile.Branches.isRecord(Document(possible_branches_data))) {
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
                    auto foreign_recoder = owner.recorder(result_branches.response.result);
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

void replay(DART owner, const(string) journal_filename) {
    import tagion.hibon.HiBONFile;
    import std.range;

    auto journalfile = File(journal_filename, "r");

    scope (exit) {
        journalfile.close;
    }

    foreach (doc; HiBONRangeArray(journalfile).retro) {
        auto action_recorder = owner.recorder(doc);
        owner.modify(action_recorder);
    }
}
