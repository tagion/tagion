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
import tagion.services.DART;
import tagion.services.DARTInterface;
import tagion.services.TVM;
import tagion.services.collector;
import tagion.services.epoch_creator;
import tagion.services.hirpc_verifier;
import tagion.services.inputvalidator;
import tagion.services.options;
import tagion.services.replicator;
import tagion.services.transcript;
import tagion.services.TRTService;
import tagion.services.nodeinterface;
import tagion.services.messages;
import tagion.services.exception;

@safe
struct Supervisor {
    enum failHandler_ = (TaskFailure tf) @safe nothrow {
        log.error("%s", tf);

        if(cast(immutable(ServiceError))tf.throwable !is null) {
            thisActor.stop = true;
        }
        else {
            sendOwner(tf);
        }
    };

    static assert(isFailHandler!(typeof(failHandler_)));

    void task(immutable(Options) opts, shared(StdSecureNet) shared_net) @safe {
        immutable tn = opts.task_names;

        ActorHandle[] handles;

        handles ~= spawn!ReplicatorService(tn.replicator, opts.replicator);
        handles ~= spawn!DARTService(tn.dart, opts.dart, tn, shared_net, opts.trt.enable);

        if (opts.trt.enable) {
            handles ~= spawn!TRTService(tn.trt, opts.trt, tn, shared_net);
        }

        handles ~= spawn!HiRPCVerifierService(tn.hirpc_verifier, opts.hirpc_verifier, tn);

        handles ~= spawn!InputValidatorService(tn.inputvalidator, opts.inputvalidator, tn);

        with (NetworkMode) final switch (opts.wave.network_mode) {
        case INTERNAL:
            break;
        case LOCAL:
            handles ~= _spawn!NodeInterfaceService(tn.node_interface, opts.node_interface, tn
                    .epoch_creator);
            break;
        case PUB:
            assert(0, "NetworkMode not supported");
            break;
        }

        // signs data
        handles ~= spawn!EpochCreatorService(tn.epoch_creator, opts.epoch_creator, opts.wave
                .network_mode, opts.wave.number_of_nodes, shared_net, tn);

        // verifies signature
        handles ~= _spawn!CollectorService(tn.collector, tn);

        handles ~= _spawn!TVMService(tn.tvm, tn);

        // signs data
        auto transcript_handle = _spawn!TranscriptService(
                tn.transcript,
                TranscriptOptions(),
                opts.wave.number_of_nodes,
                shared_net,
                tn,
                opts.trt.enable
        );
        handles ~= transcript_handle;

        handles ~= spawn(immutable(DARTInterfaceService)(opts.dart_interface, opts.trt, tn), tn.dart_interface);

        version(NO_WAIT) {
            run(
                (EpochShutdown m, long shutdown_) { //
                    transcript_handle.send(m, shutdown_);
                },
                failHandler_,
            );
        }
        else {
            if (waitforChildren(Ctrl.ALIVE, Duration.max)) {
                run();
            }
            else {
                log.error("Not all children became Alive");
            }
        }

        log("Supervisor stopping services");
        foreach (handle; handles) {
            handle.prioritySend(Sig.STOP);
        }

        (() @trusted { // NNG should be safe
            import core.time;
            import nngd;

            NNGSocket input_sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
            input_sock.dial(opts.inputvalidator.sock_addr);
            input_sock.maxttl = 1;
            input_sock.recvtimeout = 1.msecs;
            input_sock.send("End!"); // Send arbitrary data to the inputvalidator so releases the socket and checks its mailbox
        })();
        waitforChildren(Ctrl.END, 10.seconds);
        log("All services stopped");
    }
}
