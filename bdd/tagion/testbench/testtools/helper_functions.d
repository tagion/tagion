module tagion.testbench.testtools.helper_functions;

import std.process;
import std.array;
import std.format;
import std.file;
import std.algorithm.comparison : equal;
import std.stdio;

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
string execute_pipe_shell(string command) {
    writeln("args: ", command);

    auto pipes = pipeShell(command, Redirect.stdout | Redirect.stderr);
    auto exit_code = wait(pipes.pid);

    string getErrors() @trusted {
        string[] errors;
        foreach (line; pipes.stderr.byLine)
            errors ~= line.idup;

        return errors.join("; ");
    }

    check(exit_code == 0, format("Shell process executed with exit code %d (%s)", exit_code, getErrors));

    string getOutput() @trusted {
        string[] output;
        foreach (line; pipes.stdout.byLine)
            output ~= line.idup;

        return output.join("\n");
    }

    return getOutput;
}

@trusted
void execute_pipe_process(string command, string input_path = "", string output_path = "") {
    import std.process;
    import std.stdio;
    import std.file;

    auto input_data = read(input_path);

    string[] args = command.split;
    writeln("args: ", args.join(" "));

    auto pipes = pipeProcess(args, Redirect.stdin | Redirect.stdout | Redirect.stderr);

    pipes.stdin.write(input_data);
    pipes.stdin.flush();
    pipes.stdin.close();

    auto exit_code = wait(pipes.pid);

    string getErrors() @trusted {
        string[] errors;
        foreach (line; pipes.stderr.byLine)
            errors ~= line.idup;

        return errors.join("; ");
    }

    check(exit_code == 0, format("Process executed with exit code %d (%s)", exit_code, getErrors));

    void stdoutToFile() {
        auto file = File(output_path, "wb");
        writeln("Open file: ", output_path);

        ubyte[] buffer = new ubyte[4096];
        ubyte[] read_data;

        while (!(read_data = pipes.stdout.rawRead(buffer[])).empty) {
            writeln("Write to file: ", read_data);
            file.rawWrite(read_data);
        }

        file.close();
    }

    if (!output_path.empty)
        stdoutToFile;
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
