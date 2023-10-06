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

            const fingerprints = [wallet.account.bills, wallet.account.requested.values]
                .joiner
                .map!(bill => wallet.net.dartIndex(bill))
                .array;
            writeln(fingerprints);
            const hirpc = HiRPC(wallet.net);
            auto dartcheckread = dartCheckRead(fingerprints, hirpc);
            writeln("going to send dartcheckread ");

            NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
            s.recvtimeout = 1000.msecs;
            int rc;
            while (1) {
                writefln("REQ %s to dial...", dartcheckread.toPretty);
                rc = s.dial(dart_interface_sock_addr);
                if (rc == 0) {
                    break;
                }

                if (rc == nng_errno.NNG_ECONNREFUSED) {
                    nng_sleep(100.msecs);
                }
                check(rc == 0, "NNG error");
            }
            while (1) {

                rc = s.send!(immutable(ubyte[]))(dartcheckread.toDoc.serialize);
                check(rc == 0, "NNG error");
                Document received_doc = s.receive!(immutable(ubyte[]))();
                check(s.errno == 0, "Error in response");

                // writefln("RECEIVED RESPONSE: %s", received_doc.toPretty);
                auto received = hirpc.receive(received_doc);
                check(wallet.setResponseCheckRead(received), "wallet not updated succesfully");
                check(wallet.calcTotal(wallet.account.bills) > 0.TGN, "did not receive money");
                check(wallet.calcTotal(wallet.account.bills) == start_amount, "money not correct");
                break;
            }

        }

        return result_ok;
    }

    @Given("i make a payment request from wallet2.")
    Document _wallet2() @trusted {
        wallet1 = wallets[1];
        wallet2 = wallets[2];
        amount = 1500.TGN;
        auto payment_request = wallet2.requestBill(amount);

        SignedContract signed_contract;
        check(wallet1.createPayment([payment_request], signed_contract, fee).value, "Error creating wallet");
        check(signed_contract !is SignedContract.init, "contract not updated");
        import tagion.script.execute;

        pragma(msg, "fixme(cbr): use the execute calculation");
        writefln("FEE: %s", fee);

        auto wallet1_hirpc = HiRPC(wallet1.net);
        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);

        int rc;
        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUSH);
        s.sendtimeout = 1000.msecs;
        s.sendbuf = 4096;
        rc = s.dial(inputvalidator_sock_addr);
        check(rc == 0, format("Failed to dial %s", nng_errstr(rc)));

        rc = s.send(hirpc_submit.toDoc.serialize);
        check(rc == 0, format("Failed to send %s", nng_errstr(rc)));

        return result_ok;
    }

    @When("wallet1 pays contract to wallet2 and sends it to the network.")
    Document network() @trusted {
        writefln("GOING TO SLEEP 30");
        Thread.sleep(30.seconds);

        writeln("WALLET 1 request");
        const fingerprints = [wallet1.account.bills, wallet1.account.requested.values]
            .joiner
            .map!(bill => wallet1.net.dartIndex(bill))
            .array;
        writeln(fingerprints);
        const hirpc = HiRPC(wallet1.net);
        auto dartcheckread = dartCheckRead(fingerprints, hirpc);
        writeln("going to send dartcheckread ");

        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        s.recvtimeout = 1000.msecs;
        int rc;
        while (1) {
            writefln("REQ %s to dial...", dartcheckread.toPretty);
            rc = s.dial(dart_interface_sock_addr);
            if (rc == 0) {
                break;
            }

            if (rc == nng_errno.NNG_ECONNREFUSED) {
                nng_sleep(100.msecs);
            }
            check(rc == 0, "NNG error");
        }
        while (1) {
            rc = s.send!(immutable(ubyte[]))(dartcheckread.toDoc.serialize);
            check(rc == 0, "NNG error");
            Document received_doc = s.receive!(immutable(ubyte[]))();
            writefln("RECEIVED RESPONSE: %s", received_doc.toPretty);
            check(s.errno == 0, format("Error in response [%03d] %s", received_doc.length, received_doc.toPretty));
            auto received = hirpc.receive(received_doc);
            check(wallet1.setResponseCheckRead(received), "wallet1 not updated succesfully");

            auto wallet1_amount = wallet1.calcTotal(wallet1.account.bills);
            check(wallet1_amount < start_amount, format("no money withdrawn had %s", wallet1_amount));

            auto wallet1_expected = start_amount - amount - fee;
            writefln("Wallet 1 total %s", wallet1_amount);
            check(wallet1_amount == wallet1_expected, format("Wallet1 amount not correct had: %s expected: %s", wallet1_amount, wallet1_expected));
            break;
        }
        return result_ok;

    }

    @Then("wallet2 should receive the payment.")
    Document payment() @trusted {
        const fingerprints = [wallet2.account.bills, wallet2.account.requested.values]
            .joiner
            .map!(bill => wallet2.net.dartIndex(bill))
            .array;
        writeln(fingerprints);
        const hirpc = HiRPC(wallet2.net);
        auto dartcheckread = dartCheckRead(fingerprints, hirpc);
        writeln("going to send dartcheckread ");

        NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_REQ);
        s.recvtimeout = 1000.msecs;
        int rc;
        while (1) {
            writefln("REQ %s to dial...", dartcheckread.toPretty);
            rc = s.dial(dart_interface_sock_addr);
            if (rc == 0) {
                break;
            }

            if (rc == nng_errno.NNG_ECONNREFUSED) {
                nng_sleep(100.msecs);
            }
            check(rc == 0, "NNG error");
        }
        while (1) {
            rc = s.send!(immutable(ubyte[]))(dartcheckread.toDoc.serialize);
            check(rc == 0, "NNG error");
            Document received_doc = s.receive!(immutable(ubyte[]))();
            writefln("WALLET2 received: %s", received_doc.toPretty);
            check(s.errno == 0, format("Error in response [%03d] %s", received_doc.length, received_doc.toPretty));

            writefln("RECEIVED RESPONSE: %s", received_doc.toPretty);
            auto received = hirpc.receive(received_doc);
            check(wallet2.setResponseCheckRead(received), "wallet2 not updated succesfully");
            check(wallet2.calcTotal(wallet2.account.bills) > 0.TGN, "did not receive money");
            check(wallet2.calcTotal(wallet2.account.bills) == start_amount + amount, "did not receive correct amount of tagion");
            writefln("Wallet 2 total %s", wallet2.calcTotal(wallet2.account.bills));
            break;
        }
        return result_ok;
    }

}
