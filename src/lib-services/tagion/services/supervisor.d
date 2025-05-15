/// Main node supervisor service for managing and starting other tagion services
module tagion.services.supervisor;

import core.time;
import std.file;
import std.path;
import std.stdio;
import std.typecons;
import tagion.GlobalSignals : stopsignal;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.crypto.SecureNet;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.dart.DARTFile;
import tagion.logger.Logger;
import tagion.gossip.AddressBook;
import tagion.services.DART;
import tagion.services.rpcserver;
import tagion.services.TVM;
import tagion.services.collector;
import tagion.services.epoch_creator;
import tagion.services.hirpc_verifier;
import tagion.services.options;
import tagion.services.replicator;
import tagion.services.epoch_commit;

version (NEW_TRANSCRIPT) {
    import tagion.services.trans;
}
else {
    import tagion.services.transcript;
}
import tagion.services.TRTService;
import tagion.services.nodeinterface;
// import tagion.services.mode0_nodeinterface;
import tagion.services.messages;
import tagion.services.exception;

@safe
struct Supervisor {
    enum failHandler_ = (TaskFailure tf) @safe nothrow{
        log.error("%s", tf);

        if (cast(immutable(ServiceError)) tf.throwable !is null) {
            thisActor.stop = true;
        }
        else {
            sendOwner(tf);
        }
    };

    static assert(isFailHandler!(typeof(failHandler_)));

    void task(immutable(Options) opts, shared(SecureNet) shared_net, shared(AddressBook) addressbook) @safe {
        immutable tn = opts.task_names;

        ActorHandle[] handles;

        ActorHandle replicator_handle = spawn!ReplicatorService(tn.replicator, opts.replicator);
        handles ~= replicator_handle;
        ActorHandle dart_handle = spawn!DARTService(tn.dart, opts.dart, shared_net);
        handles ~= dart_handle;

        ActorHandle trt_handle;
        if (opts.trt.enable) {
            trt_handle = spawn!TRTService(tn.trt, opts.trt, tn, shared_net);
            handles ~= trt_handle;
        }

        handles ~= spawn!HiRPCVerifierService(tn.hirpc_verifier, opts.hirpc_verifier, tn);

        final switch (opts.wave.network_mode) {
        case NetworkMode.INTERNAL:
            /* handles ~= _spawn!Mode0NodeInterfaceService( */
            /*         tn.node_interface, */
            /*         shared_net, */
            /*         addressbook, */
            /*         tn.epoch_creator */
            /* ); */
            break;
        case NetworkMode.LOCAL,
            NetworkMode.MIRROR:
            handles ~= _spawn!NodeInterfaceService(
                    tn.node_interface,
                    opts.node_interface,
                    shared_net,
                    addressbook,
                    tn.epoch_creator
            );
            break;
        }

        // signs data
        handles ~= spawn!EpochCreatorService(tn.epoch_creator, opts.epoch_creator, opts.wave
                .network_mode, opts.wave.number_of_nodes, shared_net, addressbook, tn);

        // verifies signature
        handles ~= _spawn!CollectorService(tn.collector, tn);

        handles ~= _spawn!TVMService(tn.tvm, tn);
        handles ~= _spawn!EpochCommit(tn.epoch_commit, dart_handle, replicator_handle, trt_handle);

        // signs data
        auto transcript_handle = _spawn!TranscriptService(
                tn.transcript,
                opts.wave.number_of_nodes,
                shared_net,
                tn,
        );

        handles ~= transcript_handle;

        handles ~= spawn(immutable(RPCServer)(opts.rpcserver, opts.trt, tn), tn.rpcserver);

        run(
                (EpochShutdown m, long shutdown_) { //
            transcript_handle.send(m, shutdown_);
        },
                failHandler_,
        );

        log("Supervisor stopping services");
        foreach (handle; handles) {
            handle.prioritySend(Sig.STOP);
        }

        waitforChildren(Ctrl.END, 10.seconds);
        log("All services stopped");
    }
}
