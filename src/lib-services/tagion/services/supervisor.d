/// Main node supervisor service for managing and starting other tagion services
module tagion.services.supervisor;

import std.path;
import std.file;
import std.stdio;

import tagion.actor;
import tagion.services.DART;
import tagion.services.contract;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.dart.DARTFile;
import tagion.dart.DARTBasic : DARTIndex;
import tagion.basic.Types : FileExtension;

struct Supervisor {
    enum dart_task_name = "dart";
    enum contract_task_name = "contract";

    static void task(string task_name) nothrow {
        try {
            SecureNet net = new StdSecureNet();
            net.generateKeyPair("aparatus");
            const dart_filename = buildPath(".", "dart".setExtension(FileExtension.dart));

            if (!dart_filename.exists) {
                DARTFile.create(dart_filename, net);
            }

            const contract_service_handle =
                spawn!ContractService(contract_task_name);
            const dart_service_handle =
                spawn!DARTService(dart_task_name, dart_filename, cast(immutable) net);

            waitfor([dart_task_name, contract_task_name], Ctrl.ALIVE);
            run(task_name);

            end(task_name);
        }

        catch (Exception e) {
            fail(task_name, e);
        }
    }
}
