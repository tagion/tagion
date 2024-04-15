module tagion.testbench.testtools.helper_functions;

import std.process;
import std.format;

import tagion.testbench.tools.Environment;
import tagion.behaviour.BehaviourException : check;

@safe
string execute_tool(const(string) tool_name, string[] args) {
    auto executable_tagion = env.dbin ~ "/tagion";

    auto result = execute([executable_tagion, tool_name] ~ args);
    check(result.status == 0, format("Execution failed. Error: %s", result.output));

    return result.output;
}
