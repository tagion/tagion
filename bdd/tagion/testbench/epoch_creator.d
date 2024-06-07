module tagion.testbench.epoch_creator;

import tagion.behaviour.Behaviour;
import tagion.services.epoch_creator;
import tagion.testbench.services;
import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] args) {
    auto epoch_creator_options = EpochCreatorOptions(100, 5);

    auto epoch_creator_feature = automation!epoch_creator;
    epoch_creator_feature.SendPayloadAndCreateEpoch(epoch_creator_options, 5);
    epoch_creator_feature.run;

    return 0;
}
