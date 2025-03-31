module tagion.testbench.nng.nng_testsuite;
// Default import list for bdd
import std.algorithm;
import std.range;
import std.array;
import std.file : exists, fread = read, readText, fwrite = write;
import std.format;
import std.path;
import std.process;
import std.stdio;
import std.json;
import std.typecons : Tuple;
import std.exception;
import std.datetime.systime;
import std.process: environment;
import std.concurrency;
import tagion.basic.Types : FileExtension;
import tagion.behaviour;
import tagion.behaviour : check;
import tagion.behaviour.Behaviour;
import tagion.behaviour.BehaviourException : check;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;
import tagion.tools.Basic;

import core.thread;
import nngd;
import nngd.nngtests.suite;

enum feature = Feature(
            "Test of the NNG wrapper.",
            ["This Feature test of NNG sockets and services.",
            "NNG source: https://github.com/nanomsg/nng"]);

alias FeatureContext = Tuple!(
        MultithreadedNNGTestSuiteWrapper, "MultithreadedNNGTestSuiteWrapper",
        FeatureGroup*, "result"
);

static string testroot;

@safe @Scenario("NNG embedded multithread testsuite.",
        [])
class MultithreadedNNGTestSuiteWrapper {
    
    bool debuglog;
    NNGTestSuite test;

    this(bool idebug = false) {
        this.debuglog = idebug;
    }

    @Given("Multithreaded Test Suite instantince.")
    Document create() @trusted {
        auto log = stderr;
        this.test = new NNGTestSuite(&log, this.debuglog ? nngtestflag.DEBUG : 0);
        return result_ok;
    }
    
    @When("wait until the Multithreaded Test Suite work over tests.")
    Document runtest() @trusted {
        auto rc = this.test.run();
        return result_ok;
    }

    @Then("check that teste has passed without errors.")
    Document errors() @trusted {
        auto e = this.test.errors;
        check( e is null , e );
        return result_ok;
    }

}
