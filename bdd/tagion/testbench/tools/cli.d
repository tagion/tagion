module tagion.testbench.tools.cli;

import tagion.testbench.tools.Environment;
import tagion.behaviour;
import std.process;

private auto executeAtPath(string[] args, string path) {
    //  Using default paramaters from  execute;
    return execute(args, null, Config.none, 18446744073709551615LU, path);
}

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

    immutable generateWallet() {
        return executeAtPath([
            tools.tagionwallet,
            "--generate-wallet",
            "-x", 
            pin,
            "--questions",
            questions,
            "--answers",
            answers,
        ], 
            this.path
        );
    }

    immutable unlock() {
        return executeAtPath([
            tools.tagionwallet,
            "-x", 
            pin,
        ], 
            this.path,
        );
    }

    immutable update(string port = "10801") {
        return executeAtPath([
            "-x",
            pin,
            "--port",
            port,
            "--update",
            "--amount",
        ],
            this.path
        );
    }
}
