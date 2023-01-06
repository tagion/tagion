module tagion.testbench.tools.cli;

import tagion.testbench.tools.Environment;
import tagion.behaviour;
import std.process;

/// Interface to tagionwallet cli
immutable struct TagionWallet {
    string path;
    string pin;
    string questions;
    string answers;

    immutable this(
        const string path,
        string pin = "1111",
        string questions = "1,2,3,4",
        string answers = "1,2,3,4",
    ) {
        this.path = path;
        this.pin = pin;
        this.questions = questions;
        this.answers = answers;
    }

    /// Start process at wallet path
    private immutable executeAt(string[] args) {
        return execute(args, null, Config.none, 18446744073709551615LU, this.path);
    }

    immutable generateWallet() {
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

    immutable unlock() {
        return this.executeAt([
            tools.tagionwallet,
            "-x", 
            pin,
        ]);
    }

    immutable update(string port = "10801") {
        return this.executeAt([
            tools.tagionwallet,
            "-x",
            pin,
            "--port",
            port,
            "--update",
            "--amount",
        ]);
    }

    immutable getBalance() {
        assert(0, "getBalance not implemented");
    }
}
