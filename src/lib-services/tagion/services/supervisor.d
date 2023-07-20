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
import tagion.services.contract;

class WaveNet : StdSecureNet {
    this(in string passphrase) {
        super();
        generateKeyPair(passphrase);
    }
}

@safe
struct Supervisor {
    enum dart_task_name = "dart";
    enum contract_task_name = "contract";
    enum input_task_name = "inputvalidator";

    auto failHandler = (TaskFailure tf) { log("Supervisor caught exception: \n%s", tf); };

    void task(immutable(Options) opts) {
        immutable SecureNet net = (() @trusted => cast(immutable) new WaveNet("aparatus")) ();

        const dart_filename = opts.dart.dart_filename;

        if (!dart_filename.exists) {
            DARTFile.create(dart_filename, net);
        }
        auto dart_handle = spawn!DARTService(dart_task_name, opts.dart, net);
        auto contract_handle = spawn!ContractService(contract_task_name, "___collector", net);
        auto inputvalidator_handle = spawn!InputValidatorService(input_task_name, opts.inputvalidator, contract_task_name);
        auto services = tuple(dart_handle, contract_handle, inputvalidator_handle);
        waitforChildren(Ctrl.ALIVE);
        run(failHandler);

        foreach (service; services) {
            if (service.state is Ctrl.ALIVE) {
                service.send(Sig.STOP);
            }
        }
        log("Supervisor stopping services");
        waitforChildren(Ctrl.END);
        log("All services stopped");
    }
}
