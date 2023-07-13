/// Main node supervisor service for managing and starting other tagion services
module tagion.services.supervisor;

import std.path;
import std.file;
import std.stdio;
import std.socket;
import std.typecons;

import tagion.actor;
import tagion.actor.exceptions;
import tagion.basic.Types : FileExtension;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.dart.DARTFile;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.utils.JSONCommon;
import tagion.utils.pretend_safe_concurrency : locate, send;
import tagion.services.DART;
import tagion.services.inputvalidator;
import tagion.services.contract;

struct SupervisorOptions {
    string dart_filename = buildPath(".", "dart".setExtension(FileExtension.dart));
    string contract_addr = contract_sock_path;
    mixin JSONCommon;
}

struct Supervisor {
    enum dart_task_name = "dart";
    enum contract_task_name = "contract";
    enum input_task_name = "inputvalidator";

static:
    SupervisorOptions opts;
    auto failHandler = (TaskFailure tf) { writefln("Supervisor caught exception: \n%s", tf); };

    void task(string task_name) nothrow {
        try {
            scope (exit) {
                end();
            }

            SecureNet net = new StdSecureNet();
            net.generateKeyPair("aparatus"); // Key
            const dart_filename = opts.dart_filename;

            if (!dart_filename.exists) {
                DARTFile.create(dart_filename, net);
            }
            auto dart_handle = spawn!DARTService(dart_task_name, dart_filename, cast(immutable) net);
            auto contract_handle = spawn!ContractService(contract_task_name);
            auto inputvalidator_handle = spawn!InputValidatorService(input_task_name, contract_task_name, opts
                    .contract_addr);
            auto services = tuple(dart_handle, contract_handle, inputvalidator_handle);
            waitforChildren(Ctrl.ALIVE);

            run(task_name, failHandler);

            foreach (service; services) {
                service.send(Sig.STOP);
            }
            writeln("Supervisor stopping services");
            waitforChildren(Ctrl.END);
            writeln("All services stopped");
        }

        catch (Exception e) {
            fail(e);
        }
    }
}
