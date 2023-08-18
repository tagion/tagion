module tagion.testbench.epoch_creator;

import tagion.behaviour.Behaviour;
import tagion.testbench.services;

import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] _) {
    auto epoch_creator_feature = automation!epoch_creator;
    epoch_creator_feature.SendPayloadAndCreateEpoch();
    epoch_creator_feature.run;

    return 0;
}
