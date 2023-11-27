module tagion.testbench.tools.Environment;

import std.algorithm.iteration : map;
import std.array;
import std.ascii : toUpper;
import std.conv;
import std.exception;
import std.format;
import std.path;
import std.process;
import std.stdio;
import std.traits;
import std.file : getcwd;
import tagion.basic.Types : DOT, FileExtension;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourReporter;
import tagion.hibon.HiBONFile : fwrite;

void error(Args...)(string fmt, Args args) nothrow @trusted {
    assumeWontThrow(stderr.writefln(fmt, args));
}

@safe
synchronized
class Reporter : BehaviourReporter {
    static string alternative(scope const(FeatureGroup*) feature_group) nothrow {

        if (feature_group.alternative.length) {
            try {
                return "_" ~ feature_group.alternative
                    .split
                    .join("_");
            }
            catch (Exception e) {
                // Ignore
                error("%s", e);
            }
        }
        return null;
    }

    const(Exception) before(scope const(FeatureGroup*) feature_group) nothrow {
        Exception result;
        try {
            immutable report_file_name = buildPath(env.bdd_results,
                    feature_group.info.name ~ alternative(feature_group))
                ~ FileExtension.hibon;
            report_file_name.fwrite(*feature_group);
        }
        catch (Exception e) {
            result = e;
        }
        return result;
    }

    const(Exception) after(scope const(FeatureGroup*) feature_group) nothrow {
        return before(feature_group);
    }
}

enum Stage {
    commit,
    acceptance,
    performance,
}

@safe
struct Environment {
    enum platform = "x86_64-linux";
    string dbin() const {
        return environment.get("DBIN", buildPath(reporoot, "build", platform, "bin"));
    }

    string dlog() const {
        return environment.get("DLOG", buildPath(reporoot, "logs", platform));
    }

    string bdd() const {
        return environment.get("BDD", buildPath(reporoot, "bdd"));
    }

    string bdd_log() const {
        return environment.get("BDD_LOG", buildPath(dlog, "bdd", test_stage));
    }

    string bdd_results() const {
        return environment.get("BDD_RESULTS", buildPath(bdd_log, "results"));
    }

    string reporoot() const {
        return environment.get("REPOROOT", getcwd);
    }
    // string fund;
    string test_stage() const {
        return environment.get("TEST_STAGE", "commit");
    }

    string seed() const {
        return environment.get("SEED", "predictable");
    }

    const(uint) getSeed() const {
        import std.bitmanip : binread = read;
        import tagion.utils.Miscellaneous;

        auto buf = decode(seed).dup;
        return buf.binread!uint;
    }

    Stage stage() const {
        switch (test_stage) {
            static foreach (E; EnumMembers!Stage) {
        case E.stringof:
                return E;
            }
        default:
            //empty
        }

        switch (test_stage.to!uint) {
            static foreach (i; 0 .. EnumMembers!Stage.length) {
        case i:
                return cast(Stage) i;
            }
        default:
            //empty
        }

        assert(0, format("variable is not legal %s", test_stage));
    }
}

immutable Environment env;

import std.stdio;

shared static this() {
    reporter = new Reporter;
}
