module nngd.nngtests.test00;

import std.stdio;

import nngd;

const _testclass = "nngd.nngtests.nng_test00_template";


class nng_test00_template : NNGTest {
    
    this(Args...)(auto ref Args args) { super(args); }    

    override string[] run(){
        log("NNG test template");
        return [];
    }
    

}




