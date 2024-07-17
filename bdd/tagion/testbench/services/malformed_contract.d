module tagion.testbench.services.malformed_contract;
// Default import list for bdd
import std.typecons : Tuple;
import tagion.actor;
import tagion.basic.Types;
import tagion.behaviour;
import tagion.communication.HiRPC;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.crypto.Types;
import tagion.dart.DARTcrud;
import tagion.dart.DARTBasic;
import tagion.hibon.Document;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.logger.LogRecords : LogInfo;
import tagion.logger.Logger;
import tagion.script.Currency : totalAmount;
import tagion.script.TagionCurrency;
import tagion.script.common;
import tagion.script.execute;
import tagion.services.options;
import tagion.testbench.actor.util;
import tagion.testbench.services.helper_functions;
import tagion.testbench.tools.Environment;
import tagion.tools.wallet.WalletInterface;
import tagion.utils.pretend_safe_concurrency : receiveOnly, receiveTimeout;
import tagion.wallet.SecureWallet : SecureWallet;
import tagion.wallet.request;

import core.thread;
import core.time;
import std.algorithm;
import std.format;
import std.range;
import std.stdio;

alias StdSecureWallet = SecureWallet!StdSecureNet;
enum CONTRACT_TIMEOUT = 25;

enum feature = Feature(
            "malformed contracts",
            []);

alias FeatureContext = Tuple!(
        ContractTypeWithoutCorrectInformation, "ContractTypeWithoutCorrectInformation",
        InputsAreNotBillsInDart, "InputsAreNotBillsInDart",
        NegativeAmountAndZeroAmountOnOutputBills, "NegativeAmountAndZeroAmountOnOutputBills",
        ContractWhereInputIsSmallerThanOutput, "ContractWhereInputIsSmallerThanOutput",
        FeatureGroup*, "result"
);
import tagion.hashgraph.Refinement;

@safe @Scenario("contract type without correct information",
        [])
class ContractTypeWithoutCorrectInformation {
    Options node1_opts;
    StdSecureWallet wallet1;
    SignedContract signed_contract;
    HiRPC wallet1_hirpc;
    TagionCurrency start_amount1;
    bool epoch_on_startup; 

    this(Options opts, ref StdSecureWallet wallet1) {
        this.wallet1 = wallet1;
        this.node1_opts = opts;
        wallet1_hirpc = HiRPC(wallet1.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
    }


    import tagion.basic.Types : Buffer;
    import tagion.crypto.Types : Pubkey;
    import tagion.hibon.HiBONRecord;
    import tagion.script.TagionCurrency;
    import tagion.script.standardnames;
    import tagion.utils.StdTime;

    @recordType("TGN")
    struct MaliciousBill {
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
        submask.subscribe(StdRefinement.epoch_created);
        writeln("waiting for epoch");
        epoch_on_startup = receiveTimeout(20.seconds, (LogInfo _, const(Document) __) {});
        submask.unsubscribe(StdRefinement.epoch_created);
        check(epoch_on_startup, "No epoch on startup");


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
        check(epoch_on_startup, "No epoch on startup");
        submask.subscribe("error/tvm");

        sendHiRPC(node1_opts.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract), wallet1_hirpc);
        return result_ok;
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        check(epoch_on_startup, "No epoch on startup");
        auto error = receiveOnlyTimeout!(LogInfo, const(Document))(CONTRACT_TIMEOUT.seconds);
        submask.unsubscribe("error/tvm");
        return result_ok;
    }

}

@safe @Scenario("inputs are not bills in dart",
        [])
class InputsAreNotBillsInDart {

    Options node1_opts;
    StdSecureWallet wallet1;
    SignedContract signed_contract;
    HiRPC wallet1_hirpc;
    TagionCurrency start_amount1;
    const(Document) random_data;

    this(Options opts, ref StdSecureWallet wallet1, const(Document) random_data) {
        this.wallet1 = wallet1;
        this.node1_opts = opts;
        wallet1_hirpc = HiRPC(wallet1.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
        this.random_data = random_data;
    }
    

    @Given("i have a malformed contract where the inputs are another type than bills.")
    Document bills() {
        submask.subscribe("error/tvm");
        import tagion.script.common;


        const bill = wallet1.requestBill(100.TGN);
        PayScript pay_script;
        pay_script.outputs = [bill];

        signed_contract = sign(
            [wallet1.net],
            [random_data],
            null,
            pay_script.toDoc
        );

        writefln("NOTBILL signed_contract %s", signed_contract.toDoc.toPretty);

        return result_ok;
            
    }

    @When("i send the contract to the network.")
    Document network() {
        sendHiRPC(node1_opts.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract), wallet1_hirpc);
        return result_ok;
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        auto error = receiveOnlyTimeout!(LogInfo, const(Document))(CONTRACT_TIMEOUT.seconds);
        submask.unsubscribe("error/tvm");
        return result_ok;
    }

}

@safe @Scenario("Negative amount and zero amount on output bills.",
        [])
class NegativeAmountAndZeroAmountOnOutputBills {
    Options node1_opts;
    StdSecureWallet wallet1;
    SignedContract zero_contract;
    SignedContract negative_contract;
    SignedContract combined_contract;
    HiRPC wallet1_hirpc;
    TagionCurrency start_amount1;

    TagionBill[] used_bills;
    TagionBill[] output_bills;
    
    this(Options opts, ref StdSecureWallet wallet1) {
        this.wallet1 = wallet1;
        this.node1_opts = opts;
        wallet1_hirpc = HiRPC(wallet1.net);
        start_amount1 = wallet1.calcTotal(wallet1.account.bills);
    }

    @Given("i have three contracts. One with output that is zero. Another where it is negative. And one with a negative and a valid output.")
    Document output() {
        import tagion.hibon.HiBONtoText;
        import tagion.script.common;
        import tagion.utils.StdTime;



        const zero_bill = TagionBill(0.TGN,currentTime, Pubkey([1,2,3,4]), null);
        const negative_bill = TagionBill(-1000.TGN, currentTime, Pubkey([4,3,2,1]), null);

        writefln("zero_bill = %s", zero_bill.toDoc.encodeBase58);
        writefln("negative_bill = %s", negative_bill.toDoc.encodeBase58);

        PayScript zero_script;
        PayScript negative_script;
        PayScript combined_script;
        negative_script.outputs = [negative_bill];
        zero_script.outputs = [zero_bill];
        combined_script.outputs = [zero_bill, negative_bill];

        output_bills = [zero_bill, negative_bill];


        TagionBill[] input_bills1 = [wallet1.account.bills[0]];
        TagionBill[] input_bills2 = [wallet1.account.bills[1]];
        TagionBill[] input_bills3 = [wallet1.account.bills[2]];

        
        used_bills = input_bills1 ~ input_bills2 ~ input_bills3;
        wallet1.lock_bills(used_bills);

        const nets1 = wallet1.collectNets(input_bills1);
        check(nets1.all!(net => net !is net.init), "Missing deriver of some of the bills");
        zero_contract = sign(
            nets1,
            input_bills1.map!(bill => bill.toDoc).array,
            null,
            zero_script.toDoc
        );
        const nets2 = wallet1.collectNets(input_bills2);
        check(nets2.all!(net => net !is net.init), "Missing deriver of some of the bills");
        negative_contract = sign(
            nets2,
            input_bills2.map!(bill => bill.toDoc).array,
            null,
            negative_script.toDoc
        );
        const nets3 = wallet1.collectNets(input_bills3);
        check(nets3.all!(net => net !is net.init), "Missing deriver of some of the bills");
        combined_contract = sign(
            nets3,
            input_bills3.map!(bill => bill.toDoc).array,
            null,
            combined_script.toDoc
        );

        writefln("zero_contract %s \n negative contract %s \n combined contract %s", zero_contract.toPretty, negative_contract.toPretty, combined_contract.toPretty);
        
        return result_ok;
    }

    @When("i send the contracts to the network.")
    Document network() {
        submask.subscribe("error/tvm");
        foreach(contract; [zero_contract, negative_contract, combined_contract]) {
            sendHiRPC(node1_opts.inputvalidator.sock_addr, wallet1_hirpc.submit(contract), wallet1_hirpc);
        }
        (() @trusted => Thread.sleep(CONTRACT_TIMEOUT.seconds))();
       
        return result_ok;
    }

    @Then("the contracts should be rejected.")
    Document rejected() {
        import tagion.dart.DART;
        auto req = wallet1.getRequestCheckWallet(wallet1_hirpc, used_bills);
        auto received = sendHiRPC(node1_opts.dart_interface.sock_addr, req, wallet1_hirpc);
        auto not_in_dart = received.response.result[Params.dart_indices].get!Document[].map!(d => d.get!Buffer).array;
        check(not_in_dart.length == 0, "all the inputs should still be in the dart");


        auto output_req = wallet1.getRequestCheckWallet(wallet1_hirpc, output_bills);
        auto output_received = sendHiRPC(node1_opts.dart_interface.sock_addr, output_req, wallet1_hirpc);
        auto output_not_in_dart = output_received.response.result[Params.dart_indices].get!Document[].map!(d => d.get!Buffer).array;


        writefln("wowo OUTPUT %s",output_received.toPretty);
        check(output_not_in_dart.length == 2, format("No inputs should have been added %s", output_not_in_dart.length));

        return result_ok;
    }
}

@safe @Scenario("Contract where input is smaller than output.",
        [])
class ContractWhereInputIsSmallerThanOutput {
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

    @Given("i have a contract where the input bill is smaller than the output bill.")
    Document bill() {
        auto bill = wallet1.requestBill(100_000.TGN);

        PayScript pay_script;
        pay_script.outputs = [bill];

        const input_bill = wallet1.account.bills[0];
        wallet1.lock_bills([input_bill]);

        const nets = wallet1.collectNets([input_bill]);
        check(nets.all!(net => net !is net.init), "Missing deriver of some of the bills");
        signed_contract = sign(
            nets,
            [input_bill].map!(bill => bill.toDoc).array,
            null,
            pay_script.toDoc
        );
        return result_ok;
    }

    @When("i send the contract to the network.")
    Document network() {
        sendHiRPC(node1_opts.inputvalidator.sock_addr, wallet1_hirpc.submit(signed_contract), wallet1_hirpc);
        return result_ok;
    }

    @Then("the contract should be rejected.")
    Document rejected() {
        auto error = receiveOnlyTimeout!(LogInfo, const(Document))(CONTRACT_TIMEOUT.seconds);
        return result_ok;
    }

}
