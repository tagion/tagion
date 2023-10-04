module tagion.script.prior.SmartScript;

import std.exception : assumeUnique;
import std.range : lockstep, zip;
import std.format;
import std.algorithm.iteration : sum, map, filter;
import std.algorithm.searching : all;

import tagion.crypto.SecureInterfaceNet : SecureNet, HashNet;
import tagion.basic.ConsensusExceptions : SmartScriptException, ConsensusFailCode, Check;
import tagion.basic.tagionexceptions : TagionException;
import tagion.script.prior.StandardRecords : _SignedContract, StandardBill, PayContract, OwnerKey, Contract, Script, Globals, globals;
import tagion.basic.Types : Buffer;
import tagion.crypto.Types : Pubkey, Signature, Fingerprint;
import tagion.script.TagionCurrency;
import tagion.dart.Recorder : RecordFactory;
import tagion.dart.DARTBasic;

import tagion.hibon.HiBONRecord : GetLabel;

import tagion.logger.Logger;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import std.bitmanip : nativeToBigEndian;

//import tagion.script.ScriptCrypto;

alias check = Check!SmartScriptException;

@safe
const(TagionCurrency) calcTotal(const(StandardBill[]) bills) pure {
    return bills.map!(b => b.value).sum;
}

@safe
class SmartScript {
    const _SignedContract signed_contract;
    this(const _SignedContract signed_contract) {
        this.signed_contract = signed_contract;
    }

    void check(const SecureNet net) const {
        SmartScript.check(net, signed_contract);
    }

    @trusted
    static void check(const SecureNet net, const _SignedContract signed_contract)
    in {
        assert(net);
    }
    do {

        

            .check(signed_contract.signs.length > 0, ConsensusFailCode.SMARTSCRIPT_NO_SIGNATURE);
        const message = net.calcHash(signed_contract.contract.toDoc);

        

        .check(signed_contract.signs.length == signed_contract.inputs.length,
                ConsensusFailCode.SMARTSCRIPT_MISSING_SIGNATURE_OR_INPUTS);

        

        .check(signed_contract.contract.inputs.length == signed_contract.inputs.length,
                ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING);
        foreach (i, print, input, signature; lockstep(signed_contract.contract.inputs, signed_contract.inputs, signed_contract
                .signs)) {

            immutable fingerprint = net.calcHash(input.toDoc);

            

            .check(print == fingerprint,
                    ConsensusFailCode.SMARTSCRIPT_FINGERPRINT_DOES_NOT_MATCH_INPUT);
            Pubkey pkey = input.owner;

            

            .check(net.verify(message, signature, pkey),
                    ConsensusFailCode.SMARTSCRIPT_INPUT_NOT_SIGNED_CORRECTLY);
        }
    }

    protected StandardBill[] _output_bills;

    const(StandardBill[]) output_bills() const pure nothrow {
        return _output_bills;
    }

    void run(
            const uint epoch,
            ref uint index_in_epoch,
            const Fingerprint bullseye,
            const HashNet net) {
        enum transactions_name = "#trans";
        const total_input = calcTotal(signed_contract.inputs);
        TagionCurrency total_output;
        foreach (pkey, doc; signed_contract.contract.output) {
            StandardBill bill;
            bill.epoch = epoch;
            pragma(msg, "fixme(cbr): Check for overflow");
            const amount = TagionCurrency(doc);
            total_output += amount;
            bill.value = amount;
            bill.owner = pkey;
            auto index_hash = net.rawCalcHash(nativeToBigEndian(index_in_epoch));
            bill.gene = net.rawCalcHash(bullseye ~ index_hash);
            _output_bills ~= bill;
            index_in_epoch++;
        }

        

        .check(total_output <= total_input - globals.fees(),
                ConsensusFailCode.SMARTSCRIPT_NOT_ENOUGH_MONEY);
    }
}

unittest {
    import std.stdio : writefln, writeln;
    import tagion.crypto.SecureNet;
    import tagion.hibon.HiBON;
    import tagion.script.prior.StandardRecords : Script;

    const net = new StdSecureNet;
    import std.array;

    SecureNet alice = new StdSecureNet;
    {
        alice.generateKeyPair("Alice's secret password");
    }
    auto bob = new StdSecureNet;
    {
        bob.generateKeyPair("Bob's secret password");
    }
    uint epoch = 42;
    StandardBill[] bills;

    bills ~= StandardBill(1000.TGN, epoch, alice.pubkey, null);
    bills ~= StandardBill(1200.TGN, epoch, alice.derivePubkey("alice0"), null);
    bills ~= StandardBill(3000.TGN, epoch, alice.derivePubkey("alice1"), null);
    bills ~= StandardBill(4300.TGN, epoch, alice.derivePubkey("alice2"), null);
    _SignedContract createSSC(TagionCurrency amount) {
        auto input_bill = StandardBill(1000.TGN, epoch, alice.pubkey, null);

        _SignedContract ssc;
        Contract contract;

        contract.inputs = [net.HashNet.dartIndex(input_bill)];
        contract.output[bob.pubkey] = amount.toDoc;
        contract.script = Script("pay");

        ssc.contract = contract;
        ssc.signs = [alice.sign(net.calcHash(contract.toDoc))];
        ssc.inputs = [input_bill];
        return ssc;
    }

    // function for signing all bills
    void sign_all_bills(
            const StandardBill[] input_bills,
            const StandardBill[] output_bills,
            const SecureNet net,
            ref _SignedContract signed_contract) {
        Contract contract;
        contract.inputs = input_bills.map!(b => net.dartIndex(b.toDoc)).array;
        foreach (bill; output_bills) {
            contract.output[bill.owner] = bill.value.toDoc;
        }
        contract.script = Script("pay");
        foreach (bill; input_bills) {
            auto signed_doc = net.sign(contract.toDoc);
            signed_contract.signs ~= signed_doc.signature;
            assert(net.verify(contract.toDoc, signed_doc.signature, net.pubkey));
        }
        signed_contract.contract = contract;
    }
    /// SmartScript reject contracts without fee included
    {
        auto ssc = createSSC(1000.TGN);
        auto smart_script = new SmartScript(ssc);
        uint index = 1;
        try {
            smart_script.run(epoch + 1, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
            assert(false, "Input and Output amount not checked");
        }
        catch (SmartScriptException e) {
            assert(e.code == ConsensusFailCode
                    .SMARTSCRIPT_NOT_ENOUGH_MONEY);
        }
    }
    /// SmartScript accept contracts with fee included
    {
        auto ssc = createSSC(1000.TGN - globals.fees());
        auto smart_script = new SmartScript(ssc);
        uint index = 1;
        try {
            smart_script.run(epoch + 1, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
        }
        catch (SmartScriptException e) {
            assert(false, format("Exception code: %s", e.code));
        }
    }

    /// SmartScript accept contracts with output less then input
    {
        auto ssc = createSSC(900.TGN - globals.fees());
        auto smart_script = new SmartScript(ssc);
        uint index = 1;
        try {
            smart_script.run(epoch + 1, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
        }
        catch (SmartScriptException e) {
            assert(false, format("Exception code: %s", e.code));
        }
    }
    StandardBill[] outputbills;
    /// Output bills with same owner get diffrent gene
    {
        _SignedContract signed_contract_1;
        _SignedContract signed_contract_2;
        outputbills ~= StandardBill(100.TGN, epoch, bob.pubkey, null);
        sign_all_bills([bills[0]], outputbills, alice, signed_contract_1);
        signed_contract_1.inputs ~= bills[0];
        sign_all_bills([bills[1]], outputbills, alice, signed_contract_2);
        signed_contract_2.inputs ~= bills[1];

        SmartScript ssc_1 = new SmartScript(signed_contract_1);
        SmartScript ssc_2 = new SmartScript(signed_contract_2);
        uint index = 1;
        ssc_1.run(55, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
        ssc_2.run(55, index, Fingerprint([0, 0, 0, 0]), new StdHashNet());
        assert(index == 3);
        assert(ssc_1.output_bills.length == 1, "Smart contract generate more than one output");
        auto output_bill1 = ssc_1.output_bills[0];
        auto output_bill2 = ssc_2.output_bills[0];
        assert(output_bill1.gene.length != 0, "Output bill gene is empty");
        assert(output_bill1.gene != output_bill2.gene, "Output bill gene are same");
        assert(net.HashNet.dartIndex(output_bill1) != net.HashNet.dartIndex(output_bill2), "Bills with same owner key has same hash");
    }
}
