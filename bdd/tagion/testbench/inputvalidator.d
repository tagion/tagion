module tagion.testbench.inputvalidator;

import tagion.behaviour.Behaviour;
import tagion.testbench.services;

import tagion.tools.Basic;

import tagion.actor;
import tagion.services.inputvalidator;
import std.concurrency;
import std.exception;

mixin Main!(_main);

int _main(string[] _) {

    enum sock_path = "abstract://" ~ __MODULE__;

    enum input_test = "input_tester_task";
    register(input_test, thisTid);

    immutable opts = InputValidatorOptions(sock_path);
    auto input_handle = spawn!InputValidatorService("input_validator_task", opts, input_test);
    enforce(waitforChildren(Ctrl.ALIVE), "The inputvalidator did not start");

    auto inputvalidator_feature = automation!inputvalidator;
    inputvalidator_feature.SendADocumentToTheSocket(sock_path);
    inputvalidator_feature.SendNoneHiRPC(sock_path);
    inputvalidator_feature.SendPartialHiBON(sock_path);
    inputvalidator_feature.run;

    // automation!inputvalidator.run;

    input_handle.send(Sig.STOP);
    import core.time;

    import nngd;

    auto sock = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
    int rc = sock.dial(sock_path);
    enforce(rc == 0, format("Failed to dial %s", nng_errstr(rc)));
    sock.send("end");

    enforce(waitforChildren(Ctrl.END), "The inputvalidator did not stop");

    return 0;
}
