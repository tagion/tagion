module tagion.testbench.services.malformed_contract;
// Default import list for bdd
import tagion.behaviour;
import tagion.hibon.Document;
import std.typecons : Tuple;
import tagion.testbench.tools.Environment;

import tagion.wallet.SecureWallet : SecureWallet;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.tools.wallet.WalletInterface;
import tagion.services.options;
import tagion.hibon.Document;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.execute;
import tagion.script.Currency : totalAmount;
import tagion.communication.HiRPC;
import tagion.utils.pretend_safe_concurrency : receiveOnly, receiveTimeout;
import tagion.logger.Logger;
import tagion.logger.LogRecords : LogInfo;
import tagion.actor;
import tagion.testbench.actor.util;
import tagion.dart.DARTcrud;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;


import std.range;
import std.algorithm;
import core.time;
import core.thread;
import std.stdio;
import std.format;

alias StdSecureWallet = SecureWallet!StdSecureNet;
enum CONTRACT_TIMEOUT = 25;

enum feature = Feature(
            "malformed contracts",
            []);

alias FeatureContext = Tuple!(
        ContractTypeWithoutCorrectInformation, "ContractTypeWithoutCorrectInformation",
        InputsAreNotBillsInDart, "InputsAreNotBillsInDart",
        NoInputBillsInContract, "NoInputBillsInContract",
        NegativeAmountAndZeroAmountOnOutputBills, "NegativeAmountAndZeroAmountOnOutputBills",
        ContractWhereInputIsSmallerThanOutput, "ContractWhereInputIsSmallerThanOutput",
        FeatureGroup*, "result"
);

@safe @Scenario("contract type without correct information",
        [])
class ContractTypeWithoutCorrectInformation {
    Options node1_opts;
    StdSecureWallet wallet1;
    SignedContract signed_contract;
    HiRPC wallet1_hirpc;
    TagionCurrency start_amount1;

    this(Options opts, ref StdSecureWallet wallet1) {
        this.wallet1 = wallet1;
        this.node1_opts = opts;
        wallet1_hirpc = HiRPC(wallet1.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
    }


    import tagion.hibon.HiBONRecord;
    import tagion.utils.StdTime;
    import tagion.script.TagionCurrency;
    import tagion.script.standardnames;
    import tagion.basic.Types : Buffer;
    import tagion.crypto.Types : Pubkey;

    @recordType("TGN") struct MaliciousBill {
        @label(StdNames.value) @optional @(filter.Initialized) TagionCurrency value; /// Tagion bill 
        @label(StdNames.time) @optional @(filter.Initialized) sdt_t time;
        @label(StdNames.owner) @optional @(filter.Initialized) Pubkey owner;
        @label(StdNames.nonce) @optional Buffer nonce; // extra nonce 
        mixin HiBONRecord!(
            q{
                this(const(TagionCurrency) value,const sdt_t time, Pubkey owner, Buffer nonce) pure nothrow {
                    this.value = value;
                    this.time = time;
                    this.owner = owner;
                    this.nonce = nonce;
                }
            });
    }

    @recordType("pay")
    struct MaliciousPayScript {
        @label(StdNames.values) const(MaliciousBill)[] outputs;
        mixin HiBONRecord!(
            q{
                this(const(MaliciousBill)[] outputs) pure nothrow {
                    this.outputs = outputs;
                }
            });
    }
    
    @Given("i have a malformed signed contract where the type is correct but the fields are wrong.")
    Document wrong() {

        // the bill to pay
        const malicious_bill = MaliciousBill(10.TGN,sdt_t.init, Pubkey([1,2,3,4]), null);
        MaliciousPayScript pay_script;
        pay_script.outputs = [malicious_bill];

        TagionBill[] collected_bills = [wallet1.account.bills.front];
        const nets = wallet1.collectNets(collected_bills);
        check(nets.all!(net => net !is net.init), "Missing deriver of some of the bills");

        signed_contract = sign(
            nets,
            collected_bills.map!(bill => bill.toDoc).array,
            null,
            pay_script.toDoc
        );


        writefln("signed_contract %s", signed_contract.toDoc.toPretty);
        
        return result_ok;
    }

    @When("i send the contract to the network.")
    Document network() {
        thisActor.task_name = "spam_contract_task";
        log.registerSubscriptionTask(thisActor.task_name);
        submask.subscribe("error/tvm");

        sendSubmitHiRPC(node1_opts.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract), wallet1.net);
        return result_ok;
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        auto error = receiveOnlyTimeout!(LogInfo, const(Document))(CONTRACT_TIMEOUT.seconds);


        writefln("WOWOWOWOWOWOWOWOW %s", error);
        return result_ok;
    }

}

@safe @Scenario("inputs are not bills in dart",
        [])
class InputsAreNotBillsInDart {

    @Given("i have a malformed contract where the inputs are another type than bills.")
    Document bills() {
        return Document();
    }

    @When("i send the contract to the network.")
    Document network() {
        return Document();
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("no input bills in contract",
        [])
class NoInputBillsInContract {

    @Given("i have a malformed payment contract withtout any tagion bills.")
    Document bills() {
        return Document();
    }

    @When("i send the contract to the network.")
    Document network() {
        return Document();
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Negative amount and zero amount on output bills.",
        [])
class NegativeAmountAndZeroAmountOnOutputBills {

    @Given("i have three contracts. One with output that is zero. Another where it is negative. And one with a negative and a valid output.")
    Document output() {
        return Document();
    }

    @When("i send the contracts to the network.")
    Document network() {
        return Document();
    }

    @Then("the contracts should be rejected.")
    Document rejected() {
        return Document();
    }

}

@safe @Scenario("Contract where input is smaller than output.",
        [])
class ContractWhereInputIsSmallerThanOutput {

    @Given("i have a contract where the input bill is smaller than the output bill.")
    Document bill() {
        return Document();
    }

    @When("i send the contract to the network.")
    Document network() {
        return Document();
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        return Document();
    }

}
