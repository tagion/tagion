module tagion.testbench.tools.Environment;

import std.process;
import std.ascii : toUpper;
import std.algorithm.iteration : map;
import std.array;
import std.path;

import tagion.basic.Types : FileExtension, DOT;

import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourReporter;
import tagion.hibon.HiBONRecord : fwrite;

import std.stdio;

@safe
synchronized
class Reporter : BehaviourReporter {
    const(Exception) before(scope const(FeatureGroup*) feature_group) nothrow {
        Exception result;
        try {
            immutable report_file_name = buildPath(env.bdd_results, feature_group.info.name)
                ~ DOT ~ FileExtension.hibon;
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

struct Environment {
    string dbin;
    string dlog;
    string bdd;
    string bdd_log;
    string bdd_results;
    string reporoot;
    string fund;
}

immutable Environment env;

struct Tools {
    string tagionwave;
    string tagionwallet;
    string hibonutil;
    string dartutil;
    string tagionboot;
}

immutable Tools tools;

import std.stdio;

shared static this() {
    Environment temp;
    uint errors;
    static foreach (name; [__traits(allMembers, Environment)]) {
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
