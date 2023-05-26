module tagion.testbench.dart_service;

import tagion.tools.Basic;
import tagion.behaviour.Behaviour;
import tagion.testbench.services;

mixin Main!(_main);

int _main(string[] args) {
    auto actor_taskfailure_feature = automation!(actor_taskfailure)();
    auto actor_taskfailure_context = actor_taskfailure_feature.run();

    return 0;
}
