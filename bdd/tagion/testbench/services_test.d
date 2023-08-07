module tagion.testbench.services_test;

import tagion.behaviour.Behaviour;
import tagion.testbench.services;

import tagion.tools.Basic;

import tagion.actor;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.services.contract;
import tagion.utils.pretend_safe_concurrency;

mixin Main!(_main, "services");

version = contract_test;

int _main(string[] args) {
    automation!inputvalidator.run;

    version (contract_test) {

        immutable SecureNet net = (() @trusted => cast(immutable) new StdSecureNet())();

        enum contract_name = __MODULE__ ~ "_contract";
        enum contract_rejected = __MODULE__ ~ "_contract_reject";
        enum contract_success = __MODULE__ ~ "_contract_success"; // 'Collector'
        register(contract_rejected, thisTid);
        register(contract_success, thisTid);
        scope (exit) {
            unregister(contract_rejected);
            unregister(contract_success);
        }

        const opts = ContractOptions(
                true,
                contract_rejected,
        );
        auto contract_handle = spawn!ContractService(contract_name, opts, contract_success, net);

        auto contract_feature = automation!(contract);
        contract_feature.TheDocumentIsNotAHiRPC(contract_handle, contract_success, contract_rejected);
        contract_feature.CorrectHiRPCFormatAndPermission(contract_handle, contract_success, contract_rejected);
        contract_feature.CorrectHiRPCWithPermissionDenied(contract_handle, contract_success, contract_rejected);

        contract_handle.send(Sig.STOP);
        // check(waitforChildren(Ctrl.END), "ContractService never ended");
    }

    return 0;
}
