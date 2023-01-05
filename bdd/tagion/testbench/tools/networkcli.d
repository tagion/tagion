module tagion.testbench.tools.networkcli;
import tagion.testbench.tools.Environment;

import std.process;
import std.array;
import core.exception;
import std.json;
import core.thread;
import std.datetime;
import std.stdio;
import std.conv;

immutable struct Node {
    immutable string path;
    Pid pid;

    immutable this(
        const string path,
    ) {
        this.path = path;
    }

    /* immutable ~this() { */
    /*     this.stopNode(); */
    /* } */

    imutable startNode() {
    }

    imutable stopNode() {
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
