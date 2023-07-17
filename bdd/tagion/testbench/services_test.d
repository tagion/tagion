module tagion.testbench.services_test;

import tagion.behaviour.Behaviour;
import tagion.testbench.services;

import tagion.tools.Basic;

mixin Main!(_main, "services");

int _main(string[] args) {
    auto inputvalidator_feature = automation!(input_service)();
    auto result = inputvalidator_feature.run;

    return 0;
}
