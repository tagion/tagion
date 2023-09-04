/// Main node supervisor service for managing and starting other tagion services
module tagion.services.supervisor;

import std.path;
import std.file;
import std.stdio;
import std.socket;
import std.typecons;

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

@safe
class WaveNet : StdSecureNet {
    this(in string passphrase) {
        super();
        generateKeyPair(passphrase);
    }
}

@safe
struct Supervisor {
    enum dart_task_name = "dart";
    enum hirpc_verifier_task_name = "hirpc_verifier";
    enum input_task_name = "inputvalidator";

    auto failHandler = (TaskFailure tf) { log("Supervisor caught exception: \n%s", tf); };

    void task(immutable(Options) opts) {
        immutable SecureNet net = (() @trusted => cast(immutable) new WaveNet("aparatus"))();

        const dart_filename = opts.dart.dart_filename;

        if (!dart_filename.exists) {
            DARTFile.create(dart_filename, net);
        }
        auto dart_handle = spawn!DARTService(dart_task_name, opts.dart, net);
        auto hirpc_verifier_handle = spawn!HiRPCVerifierService(hirpc_verifier_task_name, opts.hirpc_verifier, "__tmp_collector", net);
        auto inputvalidator_handle = spawn!InputValidatorService(input_task_name, opts.inputvalidator, hirpc_verifier_task_name);
        auto services = tuple(dart_handle, hirpc_verifier_handle, inputvalidator_handle);

        if (!waitforChildren(Ctrl.ALIVE)) {
            log.error("Not all children became Alive");
        }
        run(failHandler);

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
