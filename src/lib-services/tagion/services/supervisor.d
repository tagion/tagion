/// Main node supervisor service for managing and starting other tagion services
module tagion.services.supervisor;

import std.path;
import std.file;
import std.stdio;
import std.socket;
import std.typecons;

import tagion.actor;
import tagion.actor.exceptions;
import tagion.utils.pretend_safe_concurrency : locate, send;
import tagion.services.DART;
import tagion.services.inputvalidator;
import tagion.services.contract;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.dart.DARTFile;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.basic.Types : FileExtension;

struct Supervisor {
static:
    enum dart_task_name = "dart";
    enum contract_task_name = "contract";

    auto failHandler = (TaskFailure tf) { writefln("Supervisor caught exception: \n%s", tf); };

    static void task(string task_name) nothrow {
        try {
            SecureNet net = new StdSecureNet();
            net.generateKeyPair("aparatus"); // Key
            const dart_filename = buildPath(".", "dart".setExtension(FileExtension.dart));

            if (!dart_filename.exists) {
                DARTFile.create(dart_filename, net);
            }
            auto dart_handle = spawn!DARTService(dart_task_name, dart_filename, cast(immutable) net);
            auto contract_handle = spawn!ContractService(contract_task_name);
            auto inputvalidator_handle = spawn!InputValidatorService("inputvalidator", contract_task_name, contract_sock_path);

            auto services = tuple(dart_handle, contract_handle, inputvalidator_handle);
            waitfor(Ctrl.ALIVE, services.expand);
            run(task_name, failHandler);

            foreach (service; services) {
                service.send(Sig.STOP);
            }
            writeln("Supervisor stopping services");
            waitfor(Ctrl.END, services.expand);
            writeln("All services stopped");

            scope (exit)
                end(task_name);
        }

        catch (Exception e) {
            fail(task_name, e);
        }
    }
}
