module tagion.testbench.wallet.Wallet_generation;
// Default import list for bdd
import tagion.behaviour.Behaviour;
import tagion.behaviour.BehaviourFeature;
import tagion.behaviour.BehaviourException;
import tagion.hibon.Document;
import std.file : readText;
import std.array : array;
import std.string : splitLines;
import std.stdio;

enum feature = Feature("Generate wallets.", ["", "", "", ""]);

@safe @Scenario("Seven wallets will be generated.", [])
class SevenWalletsWillBeGenerated {
    string[][] stdin_wallets;
    enum number_of_wallets = 7;
    @Given("i have 7 pincodes and questions")
    Document questions() {
        immutable file_name = "/home/imrying/work/tagion/fundamental/zero/wallet.stdin";
        stdin_wallets = new string[][number_of_wallets];
        foreach (ref wallet; stdin_wallets) {
            pragma(msg, typeof(file_name.readText.splitLines));
            wallet = file_name.readText.splitLines;

        }
        writeln("%s", stdin_wallets);

        check(false, "Check for 'questions' not implemented");
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
