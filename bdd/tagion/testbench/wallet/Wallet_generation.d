module tagion.testbench.wallet.Wallet_generation;
// Default import list for bdd
import tagion.behaviour.Behaviour;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourException;
import tagion.hibon.Document;
import std.file : readText, exists, mkdirRecurse, rmdir;
import std.array : array;
import std.string : splitLines;
import std.stdio;
import std.format : format;
import std.process;
import tagion.behaviour.BehaviourResult;
import std.path;



// import std.process.execute;

enum feature = Feature("Generate wallets.", ["", "", "", ""]);

@safe @Scenario("Seven wallets will be generated.", [])
class SevenWalletsWillBeGenerated {
    string[] stdin_wallets;
    enum number_of_wallets = 7;

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
        immutable tagionwallet = "/home/imrying/bin/tagionwallet";
        //check(tagionwallet.exists, format("Tagionwallet does not exist: %s", tagionwallet));

        foreach (i, stdin_wallet; stdin_wallets[0..1]) {
            stdin_wallet = "/home/imrying/work/tagion/fundamental/zero/wallet.stdin".readText;
            immutable wallet_path_array = [tagionwallet, "-O", "--path", "/tmp/wallet0", "tagionwallet0.json"];
            immutable test_array = [tagionwallet, "tagionwallet0.json"];
            // rmdir(wallet_path);
            // mkdirRecurse(wallet_path);

            writeln("TEST 1");

            execute(wallet_path_array);

            auto pipes = pipeProcess(test_array);
            writeln("TEST 2");

            scope (exit) {
                writeln("TEST in wait");

                wait(pipes.pid); 
            }

            writeln("after waitt");


            (() @trusted {
                writeln("TEST 23");

                pipes.stdin.writeln(stdin_wallet);     
                pipes.stdin.flush();
                foreach (s; pipes.stdout.byLine) {
                    writeln(s);
                    writeln("TEST in trusted");

                }
                
            })();
            


            // // foreach (s; pipes.stdout.byLine) {
            // //     writeln(s);

            // writefln("Wallet%s finished", i);
            // //pipes.stdin.close();


            // // empty
        }
        

        check(false, "Check for 'wallets' not implemented");
        return Document();
    }

    @When("each wallet is created.")
    Document created() {

        check(false, "Check for 'created' not implemented");
        return Document();
    }

    @Then("check if the wallet can be activated with the pincode.")
    Document pincode() {
        check(false, "Check for 'pincode' not implemented");
        return Document();
    }

}
