module tagion.testbench.services.trt_contract;

import core.thread;
import std.typecons : Tuple;
import std.algorithm.iteration;
import std.range;
import std.stdio;
import std.format;

import tagion.behaviour;
import tagion.hibon.Document;
import tagion.testbench.tools.Environment;
import tagion.services.options;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.script.TagionCurrency;
import tagion.wallet.SecureWallet : SecureWallet;
import tagion.script.common;
import tagion.communication.HiRPC;
import tagion.wallet.request;
import tagion.testbench.services.helper_functions;
import tagion.crypto.SecureNet;
import tagion.dart.DARTBasic : dartIndex, dartKey;
import std.digest : toHexString;
import tagion.basic.Types : encodeBase64;
import tagion.dart.DART;
import tagion.script.standardnames;
import tagion.hibon.HiBON;
import tagion.Keywords;
import tagion.trt.TRT;
import tagion.dart.Recorder;
import tagion.hibon.HiBONRecord : isRecord;
import tagion.script.execute : ContractExecution;
import tagion.script.Currency : totalAmount;

alias StdSecureWallet = SecureWallet!StdSecureNet;
enum CONTRACT_TIMEOUT = 40;

enum feature = Feature(
        "TRT contract scenarios",
        []);

alias FeatureContext = Tuple!(
    ProperContract, "ProperContract",
    InvalidContract, "InvalidContract",
    FeatureGroup*, "result"
);

@safe @Scenario("Proper contract",
    [])
class ProperContract {
    Options opts1;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;

    SignedContract signed_contract;
    TagionCurrency fee;
    TagionCurrency amount = 1000.TGN;
    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    auto net = new StdHashNet;

    this(Options opts1, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;

        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
    }

    @Given("a network")
    Document network() {
        return result_ok;
    }

    @Given("a correctly signed contract")
    Document contract() {
        auto payment_request = wallet2.requestBill(amount);
        check(wallet1.createPayment([payment_request], signed_contract, fee)
                .value, "Error creating payment");
        check(signed_contract.contract.inputs.uniq.array.length == signed_contract.contract.inputs.length, "signed contract inputs invalid");

        writeln("Contract hash: ", net.dartIndex(signed_contract.contract.toDoc).encodeBase64);

        return result_ok;
    }

    @When("the contract is sent to the network")
    Document theNetwork() {
        auto hirpc_submit = wallet1_hirpc.submit(signed_contract);
        sendHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit, wallet1_hirpc);

        return result_ok;
    }

    @When("the contract goes through")
    Document goesThrough() {
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();

        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.dart_interface.sock_addr, wallet1_hirpc);
        check(wallet1_amount == start_amount1 - amount - fee, "did not send money");

        auto wallet2_amount = getWalletUpdateAmount(wallet2, opts1.dart_interface.sock_addr, wallet2_hirpc);
        check(wallet2_amount == start_amount2 + amount, "did not receive money");

        return result_ok;
    }

    @Then("the contract should be saved in the TRT")
    Document tRT() {
        auto dart_key = net.dartKey(StdNames.contract, net.dartIndex(
                signed_contract.contract.toDoc));

        auto params = new HiBON;
        auto params_dart_indices = new HiBON;
        params_dart_indices = [dart_key];
        params[DART.Params.dart_indices] = params_dart_indices;
        auto sender = wallet1_hirpc.action("trt." ~ DART.Queries.dartRead, params);

        auto receiver = sendHiRPC(opts1.dart_interface.sock_addr, sender, wallet1_hirpc);

        auto recorder_doc = receiver.message[Keywords.result].get!Document;
        RecordFactory record_factory = RecordFactory(net);

        const recorder = record_factory.recorder(recorder_doc);
        auto result_archives = recorder[].map!(a => a.filed)
            .filter!(doc => doc.isRecord!TRTContractArchive)
            .map!(doc => TRTContractArchive(doc))
            .array;

        check(!result_archives.empty, "No contract recorded in TRT");
        check(result_archives[0].contract == signed_contract.contract.toDoc, "Received contract doesn't match expected");

        return result_ok;
    }

}

@safe @Scenario("Invalid contract",
    [])
class InvalidContract {
    Options opts1;
    StdSecureWallet wallet1;
    StdSecureWallet wallet2;

    SignedContract signed_contract1;
    SignedContract signed_contract2;
    TagionCurrency fee;
    TagionCurrency amount = 1000.TGN;
    HiRPC wallet1_hirpc;
    HiRPC wallet2_hirpc;
    TagionCurrency start_amount1;
    TagionCurrency start_amount2;

    auto net = new StdHashNet;

    this(Options opts1, ref StdSecureWallet wallet1, ref StdSecureWallet wallet2) {
        this.wallet1 = wallet1;
        this.wallet2 = wallet2;
        this.opts1 = opts1;

        wallet1_hirpc = HiRPC(wallet1.net);
        wallet2_hirpc = HiRPC(wallet2.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        start_amount2 = wallet2.calcTotal(wallet2.account.bills);
    }

    @Given("a network")
    Document aNetwork() {
        return result_ok;
    }

    @Given("one correctly signed contract")
    Document signedContract() {
        auto payment_request = wallet2.requestBill(amount);
        check(wallet1.createPayment([payment_request], signed_contract1, fee)
                .value, "Error creating payment");
        check(signed_contract1.contract.inputs.uniq.array.length == signed_contract1.contract.inputs.length, "signed contract inputs invalid");

        writeln("Contract hash: ", net.dartIndex(signed_contract1.contract.toDoc).encodeBase64);

        return result_ok;
    }

    @Given("another malformed contract correctly signed with two inputs which are the same")
    Document theSame() {
        auto payment_request = wallet2.requestBill(amount);

        auto wallet1_bill = wallet1.account.bills[0];
        auto wallet2_bill = wallet1.account.bills[1];
        check(wallet1_bill.value == 1000.TGN, "should be 1000 tgn");
        check(wallet2_bill.value == 1000.TGN, "should be 1000 tgn");

        PayScript pay_script;
        pay_script.outputs = [payment_request];

        TagionBill[] collected_bills = [
            wallet1_bill, wallet1_bill, wallet2_bill
        ];
        const fees = ContractExecution.billFees(collected_bills.map!(b => b.toDoc), pay_script.outputs.map!(
                b => b.toDoc), 100);

        const total_collected_amount = collected_bills
            .map!(bill => bill.value)
            .totalAmount;

        const amount_remainder = total_collected_amount - amount - fees;
        const nets = wallet1.collectNets(collected_bills);
        const bill_remain = wallet1.requestBill(amount_remainder);
        pay_script.outputs ~= bill_remain;
        wallet1.lock_bills(collected_bills);

        check(nets.length == collected_bills.length, format("number of bills does not match number of signatures nets %s, collected_bills %s", nets
                .length, collected_bills.length));

        signed_contract2 = sign(
            nets,
            collected_bills.map!(bill => bill.toDoc)
                .array,
                null,
                pay_script.toDoc
        );

        check(signed_contract2.contract.inputs.length == 3, "should contain two inputs");
        check(signed_contract2.contract.inputs.uniq.array.length == 2, "should be malformed and contain two identical and one different bill");

        return result_ok;
    }

    @When("contracts are sent to the network")
    Document theNetwork() {
        auto hirpc_submit1 = wallet1_hirpc.submit(signed_contract1);
        sendHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit1, wallet1_hirpc);

        auto hirpc_submit2 = wallet1_hirpc.submit(signed_contract2);
        sendHiRPC(opts1.inputvalidator.sock_addr, hirpc_submit2, wallet1_hirpc);

        return result_ok;
    }

    @Then("one contract goes through and another should be rejected")
    Document beRejected() {
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();

        const expected1 = start_amount1 - amount - fee;
        auto wallet1_amount = getWalletUpdateAmount(wallet1, opts1.dart_interface.sock_addr, wallet1_hirpc);
        check(wallet1_amount == expected1, format("Did not send money. Should have %s had %s", expected1, wallet1_amount));

        const expected2 = start_amount2 + amount;
        auto wallet2_amount = getWalletUpdateAmount(wallet2, opts1.dart_interface.sock_addr, wallet2_hirpc);
        check(wallet2_amount == expected2, format("Did not send money. Should have %s had %s", expected2, wallet2_amount));

        return result_ok;
    }

    @Then("one contract should be stored in TRT and another should not")
    Document shouldNot() {
        auto dart_key1 = net.dartKey(StdNames.contract, net.dartIndex(
                signed_contract1.contract.toDoc));

        auto dart_key2 = net.dartKey(StdNames.contract, net.dartIndex(
                signed_contract2.contract.toDoc));

        auto params = new HiBON;
        auto params_dart_indices = new HiBON;
        params_dart_indices = [dart_key1, dart_key2];
        params[DART.Params.dart_indices] = params_dart_indices;
        auto sender = wallet1_hirpc.action("trt." ~ DART.Queries.dartRead, params);

        auto receiver = sendHiRPC(opts1.dart_interface.sock_addr, sender, wallet1_hirpc);

        auto recorder_doc = receiver.message[Keywords.result].get!Document;
        RecordFactory record_factory = RecordFactory(net);

        const recorder = record_factory.recorder(recorder_doc);
        auto result_archives = recorder[].map!(a => a.filed)
            .filter!(doc => doc.isRecord!TRTContractArchive)
            .map!(doc => TRTContractArchive(doc))
            .array;

        check(result_archives.length == 1, "Should be only one contract in TRT");
        check(result_archives[0].contract == signed_contract1.contract.toDoc, "Received contract doesn't match expected");

        return result_ok;
    }

}
