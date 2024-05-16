module tagion.testbench.testtools.helper_functions;

import std.process;
import std.array;
import std.format;
import std.file;
import std.algorithm.comparison : equal;
import std.stdio;
import std.path : buildPath;
import std.algorithm : map;

import tagion.testbench.tools.Environment;
import tagion.behaviour.BehaviourException : check;
import tagion.hibon.HiBON : HiBON;
import tagion.hibon.Document : Document;

enum ToolName {
    dartutil = "dartutil",
    hibonutil = "hibonutil",
    hirep = "hirep",
    geldbeutel = "geldbeutel",
}

@safe
string tagionTool() {
    return buildPath(env.dbin, "tagion");
}

@safe
string executeTool(ToolName tool, string[] args) {
    auto result = execute([tagionTool, tool] ~ args);
    check(result.status == 0, format("Shell process executed with exit code %d (%s)", result.status, result
            .output));

    return result.output;
}

@safe
void executeSpawnShell(string command, string input_file, string output_file) {
    auto p = spawnShell(command, File(input_file, "rb"), File(output_file, "wb"));
    auto exit_code = wait(p);

    check(exit_code == 0, format("Process executed with exit code %d", exit_code));
}

@trusted
bool filesEqual(string file1, string file2) {
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

@safe
bool fileEmpty(string file_path) {
    check(file_path.exists, "File not exists");

    auto f = File(file_path, "r");
    return f.size == 0;
}

@safe
void writeHiBONs(string file_path, HiBON[] hibons) {
    std.file.write(file_path, hibons.map!(hibon => Document(hibon).serialize).join);

    assert(file_path.exists, "hibon file not exists");
}
