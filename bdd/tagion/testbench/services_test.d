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

int _main(string[] _) {
    automation!inputvalidator.run;

    version (contract_test) {

        immutable SecureNet net = (() @trusted => cast(immutable) new StdSecureNet())();

        enum contract_name = __MODULE__ ~ "_contract";
        enum contract_rejected = __MODULE__ ~ "_contract_reject";
        enum contract_success = __MODULE__ ~ "_contract_success"; // 'Collector'
        register(contract_rejected, thisTid);
        register(contract_success, thisTid);

        const opts = ContractOptions(
                true,
                contract_rejected,
        );
        auto contract_handle = spawn!ContractService(contract_name, opts, contract_success, net);

        auto contract_feature = automation!(contract);
        contract_feature.TheDocumentIsNotAHiRPC(contract_handle, contract_success, contract_rejected);
        contract_feature.CorrectHiRPCFormatAndPermission(contract_handle, contract_success, contract_rejected);
        contract_feature.CorrectHiRPCWithPermissionDenied(contract_handle, contract_success, contract_rejected);
        contract_feature.run;

        waitforChildren(Ctrl.END);
    }

    return 0;
}
