module tagion.testbench.wallet.Wallet_generation;
// Default import list for bdd
import tagion.behaviour.Behaviour;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourException;
import tagion.hibon.Document;
import std.file : readText, exists;
import std.array : array;
import std.string : splitLines;
import std.stdio;
import std.format : format;
import std.process;


// import std.process.execute;

enum feature = Feature("Generate wallets.", ["", "", "", ""]);

@safe @Scenario("Seven wallets will be generated.", [])
class SevenWalletsWillBeGenerated {
    string[][] stdin_wallets;
    enum number_of_wallets = 7;
    string[number_of_wallets] file_array;
    string[number_of_wallets] wallet_names = ["zero", "first", "second", "third", "fourth", "fifth", "sixth"];

    @Given("i have 7 pincodes and questions")
    Document questions() {
        foreach (i, ref file; file_array) {
            file = format("/home/imrying/work/tagion/fundamental/%s/wallet.stdin", wallet_names[i]);
        }
        
        stdin_wallets = new string[][number_of_wallets];
        foreach (i, ref wallet; stdin_wallets) {
            wallet = file_array[i].readText.splitLines;

        }
        
        writeln("%s", stdin_wallets);

        check(true, "Check for 'questions' not implemented");
        return Document();
    }

    @Given("i create wallets.")
    Document wallets() {
        immutable tagionwallet = "/home/imrying/bin/tagionwallet";
        check(tagionwallet.exists, format("Tagionwallet does not exist: %s", tagionwallet));
        foreach (i, stdin_wallet; stdin_wallets) {
            immutable wallet_path = format("/tmp/wallet_%s", wallet_names[i]);
            auto pipes = pipeProcess([tagionwallet, "--path", wallet_path], Redirect.stdout | Redirect.stdin | Redirect.stderr);
            scope(exit) wait(pipes.pid);
           
            foreach (line; stdin_wallet)
            {
                pipes.stdin.writeln(line);                
            }


            // pipes.stderr.writeln;
            // pipes.stdout.writeln;
            writefln("Wallet%s finished", i);
            //pipes.stdin.close();


            // empty
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
