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
        

    this(Options opts, StdSecureWallet[] wallets, string dart_interface_sock_addr, string inputvalidator_sock_addr) {
        this.opts = opts;
        this.wallets = wallets;
        this.dart_interface_sock_addr = dart_interface_sock_addr;
        this.inputvalidator_sock_addr = inputvalidator_sock_addr;
        
    }

    @Given("i have a dart database with already existing bills linked to wallet1.")
    Document wallet1() @trusted {
        // create the hirpc request for checking if the bills are already in the system.

        foreach(ref wallet; wallets) {
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
            while(1) {
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
            while(1) {

                rc = s.send!(immutable(ubyte[]))(dartcheckread.toDoc.serialize);
                check(rc == 0, "NNG error");
                Document received_doc = s.receive!(immutable(ubyte[]))();
                check(s.errno == 0, "Error in response");

                writefln("RECEIVED RESPONSE: %s", received_doc.toPretty);
                auto received = hirpc.receive(received_doc);
                check(wallet.setResponse(received), "wallet not updated succesfully");
                check(wallet.calcTotal(wallet.account.bills) > 0.TGN, "did not receive money");
                break;
            }
            

        }
        
        return result_ok;
    }


    @Given("i make a payment request from wallet2.")
    Document wallet2() @trusted {
        auto wallet1 = wallets[1];
        auto wallet2 = wallets[2];
        auto payment_request = wallet2.requestBill(100.TGN);


        SignedContract signed_contract;
        check(wallet1.createPayment([payment_request], signed_contract), "Error creating wallet");
        check(signed_contract !is SignedContract.init, "contract not updated");


        const message = wallet1.net.calcHash(signed_contract);
        const contract_net = wallet1.net.derive(message);

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
        Thread.sleep(20.seconds);


        return result_ok;
    }

    @When("wallet1 pays contract to wallet2 and sends it to the network.")
    Document network() {
        return Document();
    }

    @Then("wallet2 should receive the payment.")
    Document payment() {
        return Document();
    }

}
