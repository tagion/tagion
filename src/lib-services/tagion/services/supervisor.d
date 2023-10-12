/// Main node supervisor service for managing and starting other tagion services
module tagion.services.supervisor;

import std.path;
import std.file;
import std.stdio;
import std.socket;
import std.typecons;
import core.time;

import tagion.logger.Logger;
import tagion.actor;
import tagion.actor.exceptions;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.dart.DARTFile;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency : locate, send;
import tagion.services.options;
import tagion.services.DART;
import tagion.services.DARTInterface;
import tagion.services.inputvalidator;
import tagion.services.hirpc_verifier;
import tagion.services.epoch_creator;
import tagion.services.collector;
import tagion.services.TVM;
import tagion.services.transcript;

@safe
struct Supervisor {
    auto failHandler = (TaskFailure tf) { log("Supervisor caught exception: \n%s", tf); };

    void task(immutable(Options) opts, immutable(SecureNet) net) @safe {
        // immutable SecureNet net = (() @trusted => cast(immutable) new WaveNet(password))();

        const dart_path = opts.dart.dart_path;

        if (!dart_path.exists) {
            DARTFile.create(dart_path, net);
        }

        immutable tn = opts.task_names;
        auto dart_handle = spawn!DARTService(tn.dart, opts.dart, opts.replicator, tn, net);

        auto hirpc_verifier_handle = spawn!HiRPCVerifierService(tn.hirpc_verifier, opts.hirpc_verifier, tn, net);

        auto inputvalidator_handle = spawn!InputValidatorService(tn.inputvalidator, opts.inputvalidator, tn);

        auto epoch_creator_handle = spawn!EpochCreatorService(tn.epoch_creator, opts.epoch_creator, opts.wave
                .network_mode, opts.wave.number_of_nodes, net, opts.monitor, tn);

        auto collector_handle = spawn(immutable(CollectorService)(net, tn), tn.collector);
        auto tvm_handle = spawn(immutable(TVMService)(opts.tvm, tn), tn.tvm);

        auto transcript_handle = spawn!TranscriptService(tn.transcript, opts.transcript, net, tn);

        auto dart_interface_handle = spawn(immutable(DARTInterfaceService)(opts.dart_interface, tn), tn.dart_interface);

        auto services = tuple(dart_handle, hirpc_verifier_handle, inputvalidator_handle, epoch_creator_handle, collector_handle, tvm_handle, dart_interface_handle, transcript_handle);

        if (waitforChildren(Ctrl.ALIVE, 5.seconds)) {
            run(failHandler);
        }
        else {
            log.error("Not all children became Alive");
        }

        log("Supervisor stopping services");
        foreach (service; services) {
            if (service.state is Ctrl.ALIVE) {
                service.send(Sig.STOP);
            }
        }
        (() @trusted { // NNG shoould be safe
            import nngd;
            import core.time;

            NNGSocket input_sock = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
            input_sock.dial(opts.inputvalidator.sock_addr);
            input_sock.maxttl = 1;
            input_sock.recvtimeout = 1.msecs;
            input_sock.send("End!"); // Send arbitrary data to the inputvalidator so releases the socket and checks its mailbox
        })();
        waitforChildren(Ctrl.END);
        log("All services stopped");
    }
}

alias SupervisorHandle = ActorHandle!Supervisor;
