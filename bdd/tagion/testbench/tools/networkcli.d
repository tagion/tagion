module tagion.testbench.tools.networkcli;
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

    immutable this(
        const string path,
    ) {
        this.path = path;
    }

    /* immutable ~this() { */
    /*     this.stopNode(); */
    /* } */

    immutable startNode() {
    }

    immutable stopNode() {
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

struct Balance
{
    bool returnCode;
    double total;
    double available;
    double locked;
}

Balance getBalance(string wallet_path) @trusted
{

    string[] result;

    immutable wallet_command = [
                tools.tagionwallet,
                "-x",
                "1111",
                "--port",
                "10801",
                "--update",
                "--amount",
            ];

            auto wallet_pipe = pipeProcess(wallet_command, Redirect.all, null, Config
                .detached, wallet_path);
            

            // writefln("%s", wallet_pipe.stdout.byLine);
            auto lines = wallet_pipe.stdout.byLine;
            foreach(line; lines) {
                result ~= line.to!string;
    }

    writefln("%s", result);
    // Parse the "Wallet returnCode" field
    bool returnCode;
    if (result[0].startsWith("Wallet updated true"))
    {
        returnCode = true;
    }
    else
    {
        return Balance(false, 0, 0, 0);
    }

    // Parse the "Total" field
    double total = extractDouble(result[1]);
    writefln("total %s", total);
    // Parse the "Available" field
    double available = extractDouble(result[2]);

    // Parse the "Locked" field
    double locked = extractDouble(result[3]);

    return Balance(returnCode, total, available, locked);
}

import std.regex;

double extractDouble(string str)
{
    auto m = match(str, r"\d+(\.\d+)?");
    return to!double(m.hit);
}



