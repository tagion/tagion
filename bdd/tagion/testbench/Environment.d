module tagion.testbench.Environment;

import std.process;
import std.ascii : toUpper;
import std.algorithm.iteration : map;
import std.array;

struct Environment {
    string dbin;
    string dlog;
    string bdd;
    string testbench;
    string bdd_log;
    string report;
}

immutable Environment env;

import std.stdio;

shared static this() {
    Environment temp;
    uint errors;
    static foreach(name;[__traits(allMembers, Environment)]) {{
        pragma(msg, "name =", name);
        enum NAME = name.map!(a => cast(char)a.toUpper).array;
        try {
    pragma(msg, "NAME =", NAME);
               __traits(getMember, temp, name) = environment[NAME];
        }
            catch (Exception e) {
            stderr.writeln(e.msg);
            errors++;
        }
    }}
    env = temp;
    assert(errors is 0, "Environment is not setup correctly");
}





