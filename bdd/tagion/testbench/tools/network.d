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

immutable struct Node {
    immutable string path;
    Pid pid;
    uint port;

    immutable this(
        const string path,
    ) {
        this.path = path;
    }

    /* immutable ~this() { */
    /*     this.stopNode(); */
    /* } */

    immutable startNode() {
        assert(0, "not implemented");
    }

    immutable stopNode() {
        assert(0, "not implemented");
    }
}

bool waitUntilInGraph(int lockThreadTime, int sleepThreadTime, string port) @trusted
{
    HealthData json_result;

    auto end = Clock.currTime() + dur!"seconds"(lockThreadTime);
    while (Clock.currTime() < end)
    {

        json_result = healthCheck(port);

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

HealthData healthCheck(string port) @trusted
{
    immutable node_command = [
        tools.tagionwallet,
        "--port",
        port,
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

int getEpoch(string port) @trusted {
    HealthData json_result = healthCheck(port);
    if (json_result.returnCode == false) {
        throw new Exception("Healthcheck failed");
    }
    writefln("%s", json_result);
    return json_result.result["$msg"]["result"]["$epoch_number"][1].get!int;

}
