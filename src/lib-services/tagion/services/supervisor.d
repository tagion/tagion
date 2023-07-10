/// Main node supervisor service for managing and starting other tagion services
module tagion.services.supervisor;

import std.path;
import std.file;
import std.stdio;
import std.socket;

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

            spawn!DARTService(dart_task_name, dart_filename, cast(immutable) net);
            spawn!ContractService(contract_task_name);

            import concurrency = tagion.utils.pretend_safe_concurrency;

            concurrency.spawn(&inputvalidator, contract_task_name);

            const services = [dart_task_name, contract_task_name];
            waitfor(services, Ctrl.ALIVE);
            run(task_name, failHandler);

            foreach (service; services) {
                locate(service).send(Sig.STOP);
            }
            writeln("Supervisor stopping services");
            waitfor(services, Ctrl.END);
            writeln("All services stopped");

            end(task_name);
        }

        catch (Exception e) {
            fail(task_name, e);
        }
    }
}
