module tagion.testbench.inputvalidator;

import tagion.behaviour.Behaviour;
import tagion.testbench.services;

import tagion.tools.Basic;

mixin Main!(_main);

int _main(string[] _) {
    auto inputvalidator_feature = automation!inputvalidator;
    inputvalidator_feature.SendADocumentToTheSocket();
    inputvalidator_feature.run;

    // automation!inputvalidator.run;

    return 0;
}
