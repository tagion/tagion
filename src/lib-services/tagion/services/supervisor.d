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
import core.memory;

@safe
struct Supervisor {
    // auto failHandler = (TaskFailure tf) @trusted { log("Stoping program because Supervisor caught exception: \n%s", tf); };

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

        // signs data
        handles ~= spawn!EpochCreatorService(tn.epoch_creator, opts.epoch_creator, opts.wave
                .network_mode, opts.wave.number_of_nodes, shared_net, opts.monitor, tn);

        // verifies signature
        handles ~= _spawn!CollectorService(tn.collector, tn);

        handles ~= _spawn!TVMService(tn.tvm, tn);

        // signs data
        handles ~= spawn!TranscriptService(tn.transcript, TranscriptOptions.init, opts.wave.number_of_nodes, shared_net, tn);

        handles ~= spawn(immutable(DARTInterfaceService)(opts.dart_interface, opts.trt, tn), tn
                .dart_interface);

        if (waitforChildren(Ctrl.ALIVE, Duration.max)) {
            run();
        }
        else {
            log.error("Not all children became Alive");
        }

        log("Supervisor stopping services");
        foreach (handle; handles) {
            if (handle.state is Ctrl.ALIVE) {
                handle.send(Sig.STOP);
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
