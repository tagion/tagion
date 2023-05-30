module tagion.testbench.tools.network;

import tagion.testbench.tools.Environment;

import std.process;
import core.exception;
import std.json;
import std.array;
import core.thread;
import std.datetime;
import std.stdio;
import std.conv;
import std.algorithm;
import std.range;
import std.format;
import std.path;
import std.file;

bool waitUntilInGraph(int lockThreadTime, int sleepThreadTime, uint port) @trusted
{
    HealthData json_result;

    auto end = Clock.currTime() + dur!"seconds"(lockThreadTime);
    while (Clock.currTime() < end)
    {

        json_result = healthCheck(port);
        writefln("%s", json_result);

        if (!json_result.returnCode)
        {
            continue;
        }
        else
        {
            if (json_result.result["$msg"]["result"]["$in_graph"].to!string == "true")
            {
                return true;
            }
            Thread.sleep(sleepThreadTime.seconds);
        }
    }
    return false;
}



HealthData healthCheck(uint port) @trusted
{
    immutable node_command = [
        tools.tagionwallet,
        "--port",
        port.to!string,
        "--health",
    ];
    auto node_pipe = pipeProcess(node_command, Redirect.all, null, Config
            .detached);

    const stdout = node_pipe.stdout.byLine.array;
    try
    {
        JSONValue json_result = parseJSON(stdout.array[3]);
        writefln("%s", json_result);

        return HealthData(true, json_result);
    }
    catch (ArrayIndexError e)
    {
        writefln("%s", stdout.array);
        return HealthData(false, parseJSON(""));
    }

}

struct HealthData
{
    bool returnCode; // if the connections does not fail
    JSONValue result;
}

bool waitUntilLog(int lockThreadTime, int sleepThreadTime, string pattern, string node_log_path) @trusted
{
    auto end = Clock.currTime() + dur!"seconds"(lockThreadTime);
    while (Clock.currTime() < end)
    {
        immutable grep_command = [
            "grep",
            pattern,
            node_log_path,
            "|",
            "tail",
            "-1",
        ];
        auto node_pipe = pipeProcess(grep_command, Redirect.all, null, Config
                .detached);
        auto result = node_pipe.stdout.byLine;
        if (!result.empty)
        {
            return true;
        }
        Thread.sleep(sleepThreadTime.seconds);
    }

    return false;
}

string getBullseye(string dart_path) @trusted
{
    immutable bullseye_command = [
        tools.dartutil,
        "--dartfilename",
        dart_path,
        "--eye",
    ];
    auto bullseye_pipe = pipeProcess(bullseye_command, Redirect.all, null, Config
            .detached);
    return bullseye_pipe.stdout.byLine.front.to!string;

}

bool checkBullseyes(string[] bullseyes)
{
    const bullseye = bullseyes[0];
    foreach (eye; bullseyes)
    {
        if (bullseye != eye)
        {
            return false;
        }
    }
    return true;
}

int getEpoch(uint port) @trusted
{
    HealthData json_result = healthCheck(port);
    if (json_result.returnCode == false)
    {
        throw new Exception("Healthcheck failed");
    }
    writefln("%s", json_result);
    return json_result.result["$msg"]["result"]["$epoch_number"][1].get!int;

}

class Node
{
    Pid pid;
    immutable string boot_path;
    immutable string dart_path;
    immutable string logger_file;
    immutable uint node_number;
    immutable uint nodes;
    immutable uint port;
    immutable uint transaction_port;
    immutable bool dart_init;
    immutable bool dart_synchronize;
    immutable uint mode;
    immutable string module_path;
    immutable bool monitor;

    this(
        string module_path,
        uint node_number,
        uint nodes,
        uint port,
        uint transaction_port,
        uint mode,
        bool master = false,
        bool monitor = false,
    )
    {
        this.mode = mode;
        this.module_path = module_path;
        this.monitor = monitor;

        if (mode == 1) {
            this.node_number = node_number;
            this.nodes = nodes;
            this.boot_path = buildPath(module_path, "boot.hibon");
            this.port = port;
            this.transaction_port = transaction_port;

            if (master) {
                this.dart_path = buildPath(module_path, "dart.drt");
                this.logger_file = buildPath(module_path, "node-master.log");
                this.dart_init = false;
                this.dart_synchronize = false;
            }
            else {
                this.dart_path = buildPath(module_path, format("dart-%s.drt", node_number));
                this.logger_file = buildPath(module_path, format("node-%s.log", node_number));
                this.dart_init = true;
                this.dart_synchronize = true;
            }
        } else {
            this.node_number = node_number;
            this.nodes = nodes;
            this.boot_path = buildPath(module_path, "boot.hibon");
            this.port = port;
            this.transaction_port = transaction_port;
            this.logger_file = module_path.buildPath("tinynet.log");
            this.dart_init = false;
            this.dart_synchronize = false;
            if (master) {
                this.dart_path = module_path.buildPath("network", "data", "dart.drt");
            } else {
                this.dart_path = module_path.buildPath("network", "data", format("dart%s.drt", node_number));
                
                if (!this.dart_synchronize) {
                   copy(module_path.buildPath("network", "data", "dart.drt"), this.dart_path);
                }
            }

        }
    }

    void start() {
        auto f = File("/dev/null", "w");

        if (mode == 1) {
            string[] node_command = 
            [
                tools.tagionwave,
                "--net-mode=local",
                format("--boot=%s", boot_path),
                format("--dart-init=%s", dart_init.to!string),
                format("--dart-synchronize=%s", dart_synchronize.to!string),
                format("--dart-path=%s", dart_path),
                format("--port=%s", port + node_number),
                format("--transaction-port=%s", transaction_port + node_number),
                format("--logger-filename=%s", logger_file),
                "-N", nodes.to!string,
            ];
            if (monitor) {
                node_command ~= "--monitor";
            }
            writefln("%s", node_command);
            this.pid = spawnProcess(node_command, std.stdio.stdin, f, f);
        } else {
            string[] node_command = 
            [
                tools.tagionwave,
                "-N", nodes.to!string, 
                "--dart-filename", dart_path, 
                "-t", "200", 
                format("--dart-init=%s", dart_init.to!string), 
                format("--logger-filename=%s", logger_file),
                format("--transaction-port=%s", transaction_port),
                format("--dart-synchronize=%s", dart_synchronize.to!string),
            ];
            if (monitor) {
                node_command ~= "--monitor";
            }
            writefln("%s", node_command);
            this.pid = spawnProcess(node_command, std.stdio.stdin, f, f, null, Config.none, module_path.buildPath("network", "data"));
        }

    }
}
