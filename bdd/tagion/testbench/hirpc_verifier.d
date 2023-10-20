module tagion.testbench.hirpc_verifier;

import tagion.behaviour.Behaviour;
import tagion.testbench.services;

import tagion.tools.Basic;

import tagion.actor;
import tagion.crypto.SecureNet;
import tagion.crypto.SecureInterfaceNet;
import tagion.services.hirpc_verifier;
import tagion.utils.pretend_safe_concurrency;
import tagion.services.options : TaskNames;

mixin Main!(_main);

int _main(string[] _) {
    immutable SecureNet net = (() @trusted => cast(immutable) new StdSecureNet())();

    enum hirpc_verifier_name = __MODULE__ ~ "_hirpc_verifier";
    enum hirpc_verifier_rejected = __MODULE__ ~ "_hirpc_verifier_reject";
    enum hirpc_verifier_success = __MODULE__ ~ "_hirpc_verifier_success"; // 'Collector'
    register(hirpc_verifier_rejected, thisTid);
    register(hirpc_verifier_success, thisTid);

    const opts = HiRPCVerifierOptions(
            true,
            hirpc_verifier_rejected,
    );
    TaskNames _task_names;
    _task_names.collector = hirpc_verifier_success;

    auto hirpc_verifier_handle = spawn!HiRPCVerifierService(hirpc_verifier_name, opts, cast(immutable) _task_names);

    auto hirpc_verifier_feature = automation!(hirpc_verifier);
    hirpc_verifier_feature.TheDocumentIsNotAHiRPC(hirpc_verifier_handle, hirpc_verifier_success, hirpc_verifier_rejected);
    hirpc_verifier_feature.CorrectHiRPCFormatAndPermission(hirpc_verifier_handle, hirpc_verifier_success, hirpc_verifier_rejected);
    hirpc_verifier_feature.CorrectHiRPCWithPermissionDenied(hirpc_verifier_handle, hirpc_verifier_success, hirpc_verifier_rejected);
    hirpc_verifier_feature.run;

    waitforChildren(Ctrl.END);

    return 0;
}
