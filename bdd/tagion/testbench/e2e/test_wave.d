// tagionwave/neuewelle wrapper for testbench
module tagion.testbench.e2e.test_wave;

import neuewelle = tagion.tools.neuewelle;
import tagion.tools.Basic;

mixin Main!_main;

int _main(string[] args) {
    return neuewelle._main(args);
}
