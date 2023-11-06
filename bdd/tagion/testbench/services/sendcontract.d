module tagion.testbench.services.sendcontract;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;
import tagion.services.options;

import tagion.script.TagionCurrency;
import tagion.wallet.SecureWallet : SecureWallet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.communication.HiRPC;
import tagion.dart.DARTcrud;
import tagion.dart.DARTBasic;
import nngd;
import tagion.hibon.HiBONJSON;
import tagion.hibon.Document;
import tagion.script.common;
import tagion.script.execute;
import tagion.tools.wallet.WalletInterface;
import tagion.hibon.HiBONRecord;
import tagion.testbench.services.helper_functions;

import std.algorithm;
import std.array;
import core.time;
import core.thread;
import std.stdio;
import std.format;

alias StdSecureWallet = SecureWallet!StdSecureNet;
enum feature = Feature(
            "send a contract to the network.",
            []);

alias FeatureContext = Tuple!(
        SendASingleTransactionFromAWalletToAnotherWallet, "SendASingleTransactionFromAWalletToAnotherWallet",
        FeatureGroup*, "result"
);

@safe @Scenario("send a single transaction from a wallet to another wallet.",
        [])
class SendASingleTransactionFromAWalletToAnotherWallet {

    Options opts;
    StdSecureWallet[] wallets;
    string dart_interface_sock_addr;
    string inputvalidator_sock_addr;
    TagionCurrency fee;
    TagionCurrency amount;
    TagionCurrency start_amount;

    StdSecureWallet wallet1;
    StdSecureWallet wallet2;

    this(Options opts, StdSecureWallet[] wallets, string dart_interface_sock_addr, string inputvalidator_sock_addr, TagionCurrency start_amount) {
        this.opts = opts;
        this.wallets = wallets;
        this.dart_interface_sock_addr = dart_interface_sock_addr;
        this.start_amount = start_amount;
        this.inputvalidator_sock_addr = inputvalidator_sock_addr;

    }

    @Given("i have a dart database with already existing bills linked to wallet1.")
    Document _wallet1() @trusted {
        // create the hirpc request for checking if the bills are already in the system.

        foreach (ref wallet; wallets) {
            check(wallet.isLoggedin, "the wallet must be logged in!!!");
            const hirpc = HiRPC(wallet.net);
            auto amount = getWalletUpdateAmount(wallet, dart_interface_sock_addr, hirpc);
            check(wallet.calcTotal(wallet.account.bills) > 0.TGN, "did not receive money");
            check(wallet.calcTotal(wallet.account.bills) == start_amount, "money not correct");
        }

        return result_ok;
    }

    @Given("i make a payment request from wallet2.")
    Document _wallet2() @trusted {
        wallet1 = wallets[1];
        wallet2 = wallets[2];
        amount = 1500.TGN;
        auto payment_request = wallet2.requestBill(amount);

        
        import tagion.hibon.HiBONtoText;
        
        wallet1.account.bills
            .each!(b => writefln("WALLET1 %s %s", wallet1.net.calcHash(b).encodeBase64, b.toPretty));
        SignedContract signed_contract;
        check(wallet1.createPayment([payment_request], signed_contract, fee).value, "Error creating wallet payment");
        check(signed_contract !is SignedContract.init, "contract not updated");
        check(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length, "signed contract inputs invalid");
        
        writefln("WALLET1 created contract: %s", signed_contract.toPretty);

        auto wallet1_hirpc = HiRPC(wallet1.net);
        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);

        auto result = sendSubmitHiRPC(inputvalidator_sock_addr, hirpc_submit, wallet1.net);
        writefln("SUBMIT hirpc result: %s", result.toDoc.toPretty);

        return result_ok;
    }

    @When("wallet1 pays contract to wallet2 and sends it to the network.")
    Document network() @trusted {
        writefln("GOING TO SLEEP 30");
        Thread.sleep(30.seconds);

        writeln("WALLET 1 request");

        const hirpc = HiRPC(wallet1.net);
        auto wallet1_amount = getWalletUpdateAmount(wallet1, dart_interface_sock_addr, hirpc);
        check(wallet1_amount < start_amount, format("no money withdrawn had %s", wallet1_amount));

        auto wallet1_expected = start_amount - amount - fee;
        writefln("Wallet 1 total %s", wallet1_amount);
        check(wallet1_amount == wallet1_expected, format("Wallet1 amount not correct had: %s expected: %s", wallet1_amount, wallet1_expected));
        return result_ok;

    }

    @Then("wallet2 should receive the payment.")
    Document payment() @trusted {
        const hirpc = HiRPC(wallet2.net);
        auto wallet2_amount = getWalletUpdateAmount(wallet2, dart_interface_sock_addr, hirpc);
        check(wallet2_amount > 0.TGN, "did not receive money");
        check(wallet2_amount == start_amount + amount, "did not receive correct amount of tagion");
        writefln("Wallet 2 total %s", wallet2.calcTotal(wallet2.account.bills));
        return result_ok;
    }

}
