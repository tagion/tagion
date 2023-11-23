/// Main node supervisor service for managing and starting other tagion services
module tagion.services.supervisor;

import core.time;
import std.file;
import std.path;
import std.socket;
import std.stdio;
import std.typecons;
import tagion.GlobalSignals : stopsignal;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.crypto.SecureInterfaceNet;
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
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency : locate, send;

@safe
struct Supervisor {
    // auto failHandler = (TaskFailure tf) @trusted { log("Stoping program because Supervisor caught exception: \n%s", tf); };

    void task(immutable(Options) opts, shared(StdSecureNet) shared_net) @safe {
        immutable tn = opts.task_names;

        auto replicator_handle = spawn!ReplicatorService(tn.replicator, opts.replicator);

        // signs data for hirpc response
        auto dart_handle = spawn!DARTService(tn.dart, opts.dart, tn, shared_net, opts.trt.enable);

        ActorHandle trt_handle;
        if (opts.trt.enable) {
            trt_handle = spawn!TRTService(tn.trt, opts.trt, tn, shared_net);
        }

        auto hirpc_verifier_handle = spawn!HiRPCVerifierService(tn.hirpc_verifier, opts.hirpc_verifier, tn);

        auto inputvalidator_handle = spawn!InputValidatorService(tn.inputvalidator, opts.inputvalidator, tn);

        // signs data
        auto epoch_creator_handle = spawn!EpochCreatorService(tn.epoch_creator, opts.epoch_creator, opts.wave
                .network_mode, opts.wave.number_of_nodes, shared_net, opts.monitor, tn);

        // verifies signature
        auto collector_handle = _spawn!CollectorService(tn.collector, tn);

        auto tvm_handle = _spawn!TVMService(tn.tvm, tn);

        // signs data
        auto transcript_handle = spawn!TranscriptService(tn.transcript, TranscriptOptions.init, opts.wave.number_of_nodes, shared_net, tn);

        auto dart_interface_handle = spawn(immutable(DARTInterfaceService)(opts.dart_interface, tn), tn.dart_interface);

        auto services = tuple(dart_handle, replicator_handle, hirpc_verifier_handle, inputvalidator_handle, epoch_creator_handle, collector_handle, tvm_handle, dart_interface_handle, transcript_handle);

        if (waitforChildren(Ctrl.ALIVE, 20.seconds)) {
            run;
        }
        else {
            log.error("Not all children became Alive");
        }

        log("Supervisor stopping services");
        if (opts.trt.enable) {
            trt_handle.send(Sig.STOP);
        }
        foreach (service; services) {
            if (service.state is Ctrl.ALIVE) {
                service.send(Sig.STOP);
            }

        }
        (() @trusted { // NNG shoould be safe
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
