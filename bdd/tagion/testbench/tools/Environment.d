module tagion.testbench.tools.Environment;

import std.process;
import std.ascii : toUpper;
import std.algorithm.iteration : map;
import std.array;
import std.path;
import std.exception;
import std.traits;
import std.conv;
import std.format;
import tagion.basic.Types : FileExtension, DOT;

import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourReporter;
import tagion.hibon.HiBONRecord : fwrite;

import std.stdio;

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

struct Environment {
    string dbin;
    string dlog;
    string bdd;
    string bdd_log;
    string bdd_results;
    string reporoot;
    string fund;
    string test_stage;
    string seed;

    const(uint) getSeed() const pure {
        import tagion.utils.Miscellaneous;
        import std.bitmanip : binread = read;

        auto buf = decode(seed).dup;
        return buf.binread!uint;
    }

    Stage stage() const pure {
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

struct Tools {
    string tagionwave;
    string tagionwallet;
    string hibonutil;
    string dartutil;
    string tagionboot;
    string blockutil;
    string neuewelle;
}

immutable Tools tools;

import std.stdio;

shared static this() {
    Environment temp;
    uint errors;
    static foreach (name; FieldNameTuple!Environment) {
        {
            enum NAME = name.map!(a => cast(char) a.toUpper).array;
            try {
                __traits(getMember, temp, name) = environment[NAME];
            }
            catch (Exception e) {
                stderr.writeln(e.msg);
                errors++;
            }
        }
    }
    env = temp;
    Tools temp_tools;

    static foreach (name; [__traits(allMembers, Tools)]) {
        __traits(getMember, temp_tools, name) = env.dbin.buildPath(name);
    }
    tools = temp_tools;
    assert(errors is 0, "Environment is not setup correctly");

    reporter = new Reporter;
}
