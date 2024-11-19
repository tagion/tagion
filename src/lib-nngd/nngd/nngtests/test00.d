module nngd.nngtests.test00;

import std.stdio;

import nngd;

version (unittest) {
}
else {
    pragma(msg, "This breakes the unittest so it's disabled");

    const _testclass = "nngd.nngtests.nng_test00_template";

    @trusted class nng_test00_template : NNGTest {

        this(Args...)(auto ref Args args) {
            super(args);
        }

        override string[] run() {
            log("NNG test template");
            log(_testclass ~ ": Bye!");
            return [];
        }

    }
}
