module tagion.testbench.wallet.Wallet_generation;
// Default import list for bdd
import tagion.behaviour.Behaviour;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourException;
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
    enum number_of_wallets = 7;
    immutable tagionwallet = "/home/imrying/bin/tagionwallet";

    string[number_of_wallets] wallet_names = ["zero", "first", "second", "third", "fourth", "fifth", "sixth"];

    @Given("i have 7 pincodes and questions")
    Document questions() {

        
        stdin_wallets = new string[number_of_wallets];
        foreach (i, ref wallet; stdin_wallets) {
            const file = format("/home/imrying/work/tagion/fundamental/%s/wallet.stdin", wallet_names[i]);
            wallet = file.readText;
        }
        
        writeln("%s", stdin_wallets);
        return result_ok;
    }

    @Given("i create wallets.")
    Document wallets() {
        //check(tagionwallet.exists, format("Tagionwallet does not exist: %s", tagionwallet));

        foreach (i, stdin_wallet; stdin_wallets) {
            immutable wallet_path_array = [tagionwallet, "-O", "--path", format("/tmp/wallet_%s", i), format("tagionwallet_%s.json", i)];
            immutable test_array = [tagionwallet, format("tagionwallet_%s.json", i)];

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

        }
        
        return result_ok;
    }

    @When("the wallets are created save the pin.")
    Document pin() {
        pin_array = ["01234", "1234", "23456", "34567", "45678", "56789", "67890"];

        return result_ok;
    }

    @Then("check if the wallet can be activated with the pincode.")
    Document pincode() {
        foreach (i, pin; pin_array)
        {
            immutable wallet_command = [tagionwallet, "-x", pin, "--amount", format("tagionwallet_%s.json", i)];
            auto pipes = pipeProcess(wallet_command, Redirect.all, null, Config.detached);
          
            (() @trusted {
                check(!pipes.stderr.byLine.empty, "Pincode not valid on wallet");
            })();
        }
        return result_ok;
    }

}
