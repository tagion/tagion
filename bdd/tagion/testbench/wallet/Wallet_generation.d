module tagion.testbench.wallet.Wallet_generation;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;

import std.file : readText, exists, mkdirRecurse, rmdir;
import std.array : array;
import std.string : splitLines;
import std.stdio;
import std.format : format;
import std.process;
import tagion.behaviour.BehaviourResult;
import std.path;
import std.range;
import tagion.testbench.Environment;

enum feature = Feature(
            "Generate wallets.",
            ["",
            "",
            "",
            ""]);

alias FeatureContext = Tuple!(
        SevenWalletsWillBeGenerated, "SevenWalletsWillBeGenerated",
        FeatureGroup*, "result"
);


@safe @Scenario("Seven wallets will be generated.", [])
class SevenWalletsWillBeGenerated {
    string[] stdin_wallets;
    string[] pin_array;
    string[] wallets;
    string[] wallet_paths;

    enum number_of_wallets = 7;

    // immutable tagionwallet = "/home/imrying/bin/tagionwallet";

    string[number_of_wallets] wallet_names = ["zero", "first", "second", "third", "fourth", "fifth", "sixth"];


    @Given("i have 7 pincodes and questions")
    Document questions() {

        stdin_wallets = new string[number_of_wallets];
        foreach (i, ref wallet; stdin_wallets) {
            const file = env.fund.buildPath(wallet_names[i], "wallet.stdin");
            writefln("file_path = %s", file);
            // const file = format("/home/imrying/work/tagion/fundamental/%s/wallet.stdin", wallet_names[i]);
            wallet = file.readText;
        }
        
        //writeln("%s", stdin_wallets);
        return result_ok;
    }

    @Given("i create wallets.")
    Document createWallets() {
        //check(tagionwallet.exists, format("Tagionwallet does not exist: %s", tagionwallet));

        foreach (i, stdin_wallet; stdin_wallets) {
            // format("/tmp/wallet_%s", i)
            const wallet = env.bdd_log.buildPath(format("tagionwallet_%s.json", i));
            const wallet_path = env.bdd_log.buildPath(format("wallet_%s", i));

            immutable wallet_path_array = [
                tools.tagionwallet, 
                "-O", 
                "--path", 
                wallet_path, 
                wallet
                ];

            writefln("wallet_path_array: %s", wallet_path_array);
            immutable test_array = [
                tools.tagionwallet, 
                wallet
                ];
            
            writefln("test_array: %s", test_array);

            execute(wallet_path_array);

            auto pipes = pipeProcess(test_array);
            scope (exit) {
                wait(pipes.pid); 
            }
            (() @trusted {
                pipes.stdin.writeln(stdin_wallet);     
                pipes.stdin.flush();
                foreach (s; pipes.stdout.byLine) {
                    writeln(s);
                } 
            })();
            wallets ~= wallet;
            wallet_paths ~= wallet_path;
        }
        
        return result_ok;
    }

    @When("the wallets are created save the pin.")
    Document pin() {
        pin_array = ["01234", "1234", "23456", "34567", "45678", "56789", "67890"];

        return result_ok;
    }

    @Then("check if the wallet can be activated with the pincode.")
    Document pincode() @trusted {
        foreach (i, pin; pin_array)
        {
            immutable wallet_command = [tools.tagionwallet, "-x", pin, wallets[i]]; // @suppress(dscanner.style.long_line)
            auto pipes = pipeProcess(wallet_command, Redirect.all, null, Config.detached);

            check(pipes.stderr.byLine.empty, "Pincode not valid on wallet");

        }
        return result_ok;
    }

}
