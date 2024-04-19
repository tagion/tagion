module tagion.testbench.testtools.helper_functions;

import std.process;
import std.array;
import std.format;
import std.file;
import std.algorithm.comparison : equal;

import tagion.testbench.tools.Environment;
import tagion.behaviour.BehaviourException : check;

enum ToolName {
    dartutil = "dartutil",
    hibonutil = "hibonutil",
    hirep = "hirep",
    geldbeutel = "geldbeutel",
}

@safe
string tagionTool() {
    return env.dbin ~ "/tagion";
}

@safe
string execute_tool(ToolName tool, string[] args) {
    auto result = execute([tagionTool, tool] ~ args);
    check(result.status == 0, format("Shell process executed with exit code %d (%s)", result.status, result
            .output));

    return result.output;
}

@safe
void execute_pipe_shell(string command) {
    auto pipes = pipeShell(command, Redirect.stdout | Redirect.stderr);
    auto exit_code = wait(pipes.pid);

    string getErrors() @trusted {
        string[] errors;
        foreach (line; pipes.stderr.byLine)
            errors ~= line.idup;

        return errors.join("; ");
    }

    check(exit_code == 0, format("Shell process executed with exit code %d (%s)", exit_code, getErrors));
}

@trusted
bool compare_files(string file1, string file2) {
    try {
        ubyte[] file1_content = cast(ubyte[]) std.file.read(file1);
        ubyte[] file2_content = cast(ubyte[]) std.file.read(file2);

        return equal(file1_content, file2_content);
    }
    catch (Exception e) {
        check(false, format("An error during comparing files: %s", e.msg));
        return false;
    }
}
