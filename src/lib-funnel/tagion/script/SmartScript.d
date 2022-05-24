module tagion.script.SmartScript;

import std.exception : assumeUnique;
import std.range : lockstep, zip;
import std.format;
import std.algorithm.iteration : sum, map;
import std.algorithm.searching : all;

import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.basic.ConsensusExceptions : SmartScriptException, ConsensusFailCode, Check;
import tagion.basic.TagionExceptions : TagionException;
import tagion.script.StandardRecords : SignedContract, StandardBill, PayContract, OwnerKey, Contract;
import tagion.basic.Types : Pubkey, Buffer, Signature;
import tagion.script.TagionCurrency;
import tagion.dart.Recorder : RecordFactory;
import tagion.hibon.HiBONRecord : GetLabel;


//import tagion.script.Script : Script, ScriptContext;
//import tagion.script.ScriptParser : ScriptParser;
//import tagion.script.ScriptBuilder : ScriptBuilder;
//import tagion.script.ScriptBase : Number;
import tagion.logger.Logger;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;

//import tagion.script.ScriptCrypto;

alias check = Check!SmartScriptException;

@safe
const(TagionCurrency) calcTotal(const(StandardBill[]) bills) pure {
    return bills.map!(b => b.value).sum;
}

@safe
class SmartScript {
//     this(SignedContract signed_contract) {
// //        this.net = net;
//     }
    SignedContract signed_contract;
    RecordFactory.Recorder inputs;
    this(const SecureNet net, ref const SignedContract signed_contract) {
    //     this.signed_contract = signed_contract;
    }

    // void check(const SecureNet net) const {
    //     check(net, signed_contract);
    // }

//    @trusted
    static ConsensusFailCode check(
        const SecureNet net,
        const ref SignedContract signed_contract,
        const RecordFactory.Recorder inputs) nothrow
    in {
        assert(net);
    }
    do {
        try {
        if (signed_contract.contract.output.length == 0) {
            return ConsensusFailCode.SMARTSCRIPT_NO_OUTPUT;
        }
        if (signed_contract.signs.length == 0) {
            return ConsensusFailCode.SMARTSCRIPT_NO_SIGNATURE;
        }
        const message = net.hashOf(signed_contract.contract.toDoc);
        if (signed_contract.signs.length != inputs.length) {
            return ConsensusFailCode.SMARTSCRIPT_MISSING_SIGNATURE_OR_INPUTS;
        }
//        pragma(msg, typeof(inputs[].front.filed[OwnerKey].get!Pubkey));
        if (inputs[].all!(a => a.filed.hasMember(OwnerKey) && a.filed[OwnerKey].isType!Pubkey)) {
            return ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING;
        }
        // do not understand this if
        if (signed_contract.contract.inputs.length != inputs.length) {
                return ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING;
        }

        auto check_range = () @trusted => lockstep(
                    signed_contract.contract.inputs,
                    inputs[],
                    signed_contract.signs);

        foreach (print, input, signature; zip(signed_contract.contract.inputs,
                    inputs[],
                    signed_contract.signs)) {
            import tagion.utils.Miscellaneous : toHexString;

            immutable fingerprint = net.hashOf(input);

            if (print == fingerprint) {
                return ConsensusFailCode.SMARTSCRIPT_FINGERPRINT_DOES_NOT_MATCH_INPUT;
            }
            Pubkey pkey = input.filed[OwnerKey].get!Buffer;


            if (net.verify(message, signature, pkey)) {
                return ConsensusFailCode.SMARTSCRIPT_INPUT_NOT_SIGNED_CORRECTLY;
            }
        }
        }
        catch (TagionException e) {
            log.trace(e.msg);
            return ConsensusFailCode.SMARTSCRIPT_CAUGHT_TAGIONEXCEPTION;
        }
        catch (Exception e) {
            log.trace(e.msg);
            return ConsensusFailCode.SMARTSCRIPT_CAUGHT_EXCEPTION;
        }
        return ConsensusFailCode.NONE;
    }

    // protected StandardBill[] _output_bills;

    // const(StandardBill[]) output_bills() const pure nothrow {
    //     return _output_bills;
    // }

    void run(const(SecureNet) net,
        const(string) method,
        const ref SignedContract signed_contract,
        const RecordFactory.Recorder inputs) {
        try {
            check(net, signed_contract, inputs);

        }
        catch (SmartScriptException e) {
            log.error(e.msg);
            return;
        }
    }
    version(none)
    void run(const uint epoch) {
        assert(0);
    }

    // check values
    version (none) void run(const uint epoch) {
        // immutable source=signed_contract.contract.script;
        enum transactions_name = "#trans";
        immutable source = (() @trusted =>
                format(": %s %s ;", transactions_name, signed_contract.contract.script)
        )();
        auto src = ScriptParser(source);
        Script script;
        auto builder = ScriptBuilder(src[]);
        builder.build(script);

        auto sc = new ScriptContext(10, 10, 10, 100);
        script.execute(transactions_name, sc);

        const payment = PayContract(signed_contract.input);
        const total_input = calcTotal(payment.bills);
        TagionCurrency total_output;
        foreach (pkey, doc; signed_contract.contract.output) {
            StandardBill bill;
            bill.epoch = epoch;
            const num = sc.pop.get!Number;
            pragma(msg, "fixme(cbr): Check for overflow");
            const amount = TagionCurrency(cast(long) num);
            total_output += amount;
            bill.value = amount;
            bill.owner = pkey;
            //            bill.bill_type = "TGN";
            _output_bills ~= bill;
        }



        .check(total_output <= total_input, ConsensusFailCode.SMARTSCRIPT_NOT_ENOUGH_MONEY);
    }
}


unittest {
    import std.stdio : writefln;
    import tagion.dart.Recorder : Add, Remove;
    import tagion.crypto.SecureNet;
    import tagion.basic.Types : FileExtension;
    import tagion.hibon.HiBON;

    // function for signing all bills
    void sign_all_bills(const StandardBill[] bills, const SecureNet net, ref SignedContract signed_contract) {
        Contract contract;
        foreach (bill; bills)
        {
            Document doc;
            {
                auto h = new HiBON;
                enum bill_name = GetLabel!(StandardBill).name;
                h[bill_name] = bill;
                doc = Document(h);
            }

            auto signed_doc = net.sign(doc);
            contract.inputs ~= net.hashOf(bill);
            signed_contract.signs ~= signed_doc.signature;
            assert(net.verify(doc, signed_doc.signature, net.pubkey));
        }
        signed_contract.contract = contract;
    }


    const net = new StdSecureNet;
    SecureNet alice = new StdSecureNet;
    {
        alice.generateKeyPair("Alice's secret password");
    }
    auto bob = new StdSecureNet;
    {
        bob.generateKeyPair("Bob's secret password");
    }
    uint epoch=42;
    StandardBill[] bills;

    bills~=StandardBill(1000.TGN, epoch, alice.pubkey, null);
    bills~=StandardBill(1200.TGN, epoch, alice.derivePubkey("alice0"), null);
    bills~=StandardBill(3000.TGN, epoch, alice.derivePubkey("alice1"), null);
    bills~=StandardBill(4300.TGN, epoch, alice.derivePubkey("alice2"), null);

    auto factory = RecordFactory(net);
    const alices_bills = factory.recorder(bills);

    import tagion.dart.BlockFile : fileId;
    import tagion.dart.DART : DART;
    immutable filename = fileId!SmartScript(FileExtension.dart).fullpath;

    DART.create(filename);
    auto dart_db =new DART(net, filename);
    dart_db.modify(alices_bills, Add);
    writefln("dart-file %s", filename);
    dart_db.dump(true);

    // simple valid scenario
    {
        import std.algorithm;

        SignedContract signed_contract;
        sign_all_bills(bills, alice, signed_contract);
        

        auto bob_bill = StandardBill(1000.TGN, epoch, bob.pubkey, null);
        signed_contract.contract.output[bob.pubkey] = bob_bill.toDoc;

        // TagionCurrency total_input;
        // enum bill_name = GetLabel!(StandardBill).name;
        // auto total_input = alices_bills[]
        //                             .map!(a => a.filed)
        //                             .filter!(a => StandardBill.isRecord(a))
        //                             .map!(a => TagionCurrency(a[bill_name]))
        //                             .sum;

        assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode.NONE);
    }

    // simple invalid scenario (no output docs)
    {
        SignedContract signed_contract;
        sign_all_bills(bills, alice, signed_contract);

        assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode.SMARTSCRIPT_NO_OUTPUT);
    }

    // invalid scenario (unsigned bill)
    {
        SignedContract signed_contract;
        sign_all_bills(bills[0 .. $-1], alice, signed_contract);

        auto bob_bill = StandardBill(1000.TGN, epoch, bob.pubkey, null);
        signed_contract.contract.output[bob.pubkey] = bob_bill.toDoc;

        assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode.SMARTSCRIPT_MISSING_SIGNATURE_OR_INPUTS);
    }

    //signs.length more than inputs.length
    // {
    //     SignedContract signed_contract;
    //     Contract contract;
    //     foreach (bill; bills)
    //     {
    //         Document doc;
    //         {
    //             auto h = new HiBON;
    //             enum bill_name = GetLabel!(StandardBill).name;
    //             h[bill_name] = bill;
    //             doc = Document(h);
    //         }

    //         auto signed_doc = net.sign(doc);
    //         contract.inputs ~= net.hashOf(bill);
    //         signed_contract.signs ~= signed_doc.signature;
    //         assert(net.verify(doc, signed_doc.signature, net.pubkey));
    //     }
    //     signed_contract.contract = contract;

    // }

    // invalid scenario (inputs value < output value)
    // {
    //     SignedContract signed_contract;

    //     Document doc;

    //         { // Hash key
    //             auto h = new HiBON;
    //             enum bill_name = GetLabel!(StandardBill).name;
    //             h[bill_name] = bills[0];
    //             doc = Document(h);
    //         }

    //     auto signed_doc = alice.sign(doc);

    //     assert(alice.verify(doc, signed_doc.signature, alice.pubkey));

    //     Contract alice_contract;
    //     alice_contract.inputs ~= alice.hashOf(bills[0]);

    //     signed_contract.contract = alice_contract;

    //     StandardBill[] bob_bills;
    //     bob_bills ~= StandardBill(1000.TGN, epoch, bob.pubkey, null);
    //     bob_bills ~= StandardBill(1200.TGN, epoch, bob.derivePubkey("bob0"), null);

    //     signed_contract.contract.output[bob.pubkey] = bob_bills[0].toDoc;
    //     signed_contract.contract.output[bob.derivePubkey("bob0")] = bob_bills[1].toDoc;

    //     signed_contract.signs ~= signed_doc.signature;

    //     assert(SmartScript.check(alice, signed_contract, alices_bills) == ConsensusFailCode.SMARTSCRIPT_NO_SIGNATURE);
    // }

    // check value of TGN (2 inputs and 1 output?)
    // check value of TGN (1 input and 1 output)

    // check signs > inputs.length

    // check 1 input and 2 output (input on 1000TGN, output on 500+500 TGN)
    // invalid signature



    // check with smart script

    // // signed_contract.inputs ~= bills_fingerprint;
    // smart_script.signed_contract = signed_contract;

    /// Create a signaned smartcontract

}
