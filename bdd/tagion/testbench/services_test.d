module tagion.testbench.services_test;

import tagion.behaviour.Behaviour;
import tagion.testbench.services;

import tagion.tools.Basic;

mixin Main!(_main, "services");

int _main(string[] args) {
    automation!inputvalidator.run;
    automation!contract.run;

    return 0;
}
