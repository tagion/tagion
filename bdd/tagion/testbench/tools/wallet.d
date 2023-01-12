module tagion.testbench.tools.wallet;

import tagion.testbench.tools.Environment;
import tagion.behaviour;
import tagion.testbench.tools.FileName;

import std.process;
import std.string : splitLines;
import std.algorithm.searching : startsWith;
import std.conv : to;
import std.stdio;
import std.regex;
import std.path;
import std.format;

/// Interface to tagionwallet cli
immutable struct TagionWallet
{
    string path;
    string pin;
    string questions;
    string answers;

    immutable this(
        const string path,
        string pin = "1111",
        string questions = "1,2,3,4",
        string answers = "1,2,3,4",
    )
    {
        this.path = path;
        this.pin = pin;
        this.questions = questions;
        this.answers = answers;
    }

    /// Start process at wallet path
    private immutable executeAt(string[] args)
    {
        return execute(args, null, Config.none, 18446744073709551615LU, this.path);
    }

    string createInvoice(string label, double amount)
    {
        const invoice_path = buildPath(this.path, format("%s-%s", generateFileName(10), "invoice.hibon"));

        this.executeAt([
            tools.tagionwallet,
            "--create-invoice",
            format("GENESIS:%s", amount),
            "--invoice",
            invoice_path,
            "-x",
            pin,
        ]);
        return invoice_path;
    }

    immutable payInvoice(string invoice_path, uint port = 10801)
    {
        return this.executeAt([
            tools.tagionwallet,
            "-x",
            pin,
            "--pay",
            invoice_path,
            "--port",
            port.to!string,
            "--send",
        ]);
    }


    immutable generateWallet()
    {
        return this.executeAt([
            tools.tagionwallet,
            "--generate-wallet",
            "-x",
            pin,
            "--questions",
            questions,
            "--answers",
            answers,
        ]);
    }

    immutable unlock(uint port = 10801)
    {
        return this.executeAt([
                tools.tagionwallet,
                "-x",
                pin,
                "--port",
                port.to!string,
                "--unlock",
        ]);
    }

    immutable update(uint port = 10801)
    {
        return this.executeAt([
            tools.tagionwallet,
            "-x",
            pin,
            "--port",
            port.to!string,
            "--update",
            "--amount",
        ]);
    }

    Balance getBalance(uint port = 10801) @trusted
    {
        immutable result = executeAt([
            tools.tagionwallet,
            "-x",
            "1111",
            "--port",
            port.to!string,
            "--update",
            "--amount",
        ]);

        immutable resultLines = result.output.splitLines;

        writefln("%s", result);
        // Parse the "Wallet returnCode" field
        if (resultLines[0].startsWith("Wallet updated true"))
        {
            // Parse the "Total" field
            double total = extractDouble(resultLines[1]);
            // Parse the "Available" field
            double available = extractDouble(resultLines[2]);
            // Parse the "Locked" field
            double locked = extractDouble(resultLines[3]);
            return Balance(true, total, available, locked);
        }
        else
        {
            return Balance(false, 0, 0, 0);
        }
    }
}

/// Takes a string and returns the first . delimited number as a double
private double extractDouble(string str)
{
    auto m = match(str, r"\d+(\.\d+)?");
    return to!double(m.hit);
}

struct Balance
{
    bool returnCode;
    double total;
    double available;
    double locked;
}
