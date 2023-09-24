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
import tagion.services.inputvalidator;
import tagion.services.hirpc_verifier;
import tagion.services.epoch_creator;

@safe
struct Supervisor {
    auto failHandler = (TaskFailure tf) { log("Supervisor caught exception: \n%s", tf); };

    void task(immutable(Options) opts, immutable(SecureNet) net) @safe {
        // immutable SecureNet net = (() @trusted => cast(immutable) new WaveNet(password))();

        const dart_filename = opts.dart.dart_filename;

        if (!dart_filename.exists) {
            DARTFile.create(dart_filename, net);
        }

        immutable tn = opts.task_names;
        auto dart_handle = spawn!DARTService(tn.dart, opts.dart, opts.replicator, tn.replicator, net);

        auto hirpc_verifier_handle = spawn!HiRPCVerifierService(tn.hirpc_verifier, opts.hirpc_verifier, tn.collector, net);

        auto inputvalidator_handle = spawn!InputValidatorService(tn.inputvalidator, opts.inputvalidator, tn
                .hirpc_verifier);

        auto epoch_creator_handle = spawn!EpochCreatorService(tn.epoch_creator, opts.epoch_creator, opts.wave
                .network_mode, opts.wave.number_of_nodes, net, opts.monitor);

        auto services = tuple(dart_handle, hirpc_verifier_handle, inputvalidator_handle, epoch_creator_handle);

        if (waitforChildren(Ctrl.ALIVE, 5.seconds)) {
            run(failHandler);
        }
        else {
            log.error("Not all children became Alive");
        }

        foreach (service; services) {
            if (service.state is Ctrl.ALIVE) {
                service.send(Sig.STOP);
            }
        }
        (() @trusted { // NNG shoould be safe
            import nngd;

            NNGSocket input_sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
            input_sock.dial(opts.inputvalidator.sock_addr);
            input_sock.send("End!"); // Send arbitrary data to the inputvalidator so releases the socket and checks its mailbox
        })();
        log("Supervisor stopping services");
        waitforChildren(Ctrl.END);
        log("All services stopped");
    }
}
