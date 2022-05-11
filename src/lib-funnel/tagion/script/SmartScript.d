module tagion.script.SmartScript;

import std.exception : assumeUnique;
import std.range : lockstep;
import std.format;
import std.algorithm.iteration : sum, map;
import std.algorithm.searching : all;

import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.basic.ConsensusExceptions : SmartScriptException, ConsensusFailCode, Check;
import tagion.script.StandardRecords : SignedContract, StandardBill, PayContract, OwnerKey;
import tagion.basic.Types : Pubkey, Buffer;
import tagion.script.TagionCurrency;
import tagion.dart.Recorder : RecordFactory;

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
    static void check(
        const SecureNet net,
        const ref SignedContract signed_contract,
        const RecordFactory.Recorder inputs)
    in {
        assert(net);
    }
    do {
        .check(signed_contract.signs.length > 0, ConsensusFailCode.SMARTSCRIPT_NO_SIGNATURE);
        const message = net.hashOf(signed_contract.contract.toDoc);
        .check(signed_contract.signs.length >= inputs.length,
                ConsensusFailCode.SMARTSCRIPT_MISSING_SIGNATURE);

//        pragma(msg, typeof(inputs[].front.filed[OwnerKey].get!Pubkey));
        .check(inputs[].all!(a => a.filed.hasMember(OwnerKey) && a.filed[OwnerKey].isType!Buffer),
                ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING);

        .check(signed_contract.contract.input.length == inputs.length,
                ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING);
//        const payment = PayContract(signed_contract.input);
        (() @trusted {
            foreach (i, print, input, signature;
                lockstep(
                    signed_contract.contract.input,
                    inputs[],
                    signed_contract.signs)) {
                import tagion.utils.Miscellaneous : toHexString;

                immutable fingerprint = net.hashOf(input);

                .check(print == fingerprint,
                    ConsensusFailCode.SMARTSCRIPT_FINGERPRINT_DOES_NOT_MATCH_INPUT);
                Pubkey pkey = input.filed[OwnerKey].get!Buffer;


                .check(net.verify(message, signature, pkey),
                    ConsensusFailCode.SMARTSCRIPT_INPUT_NOT_SIGNED_CORRECTLY);

            }
        })();
    }

    // protected StandardBill[] _output_bills;

    // const(StandardBill[]) output_bills() const pure nothrow {
    //     return _output_bills;
    // }

    void run(const(SecureNet) net, const(string) method, const ref SignedContract signed_contract, const RecordFactory.Recorder inputs) {
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
    import tagion.crypto.SecureNet;
    const net = new StdSecureNet;
    auto alice = new StdSecureNet;
    {
        alice.generateKeyPair("Alice's secret password");
    }
    uint epoch=42;
    StandardBill[] bills;
    bills~=StandardBill(1000.TGN, epoch, alice.pubkey, null);
    bills~=StandardBill(1200.TGN, epoch, alice.derivePubkey("alice0"), null);
    bills~=StandardBill(3000.TGN, epoch, alice.derivePubkey("alice1"), null);
    bills~=StandardBill(4300.TGN, epoch, alice.derivePubkey("alice2"), null);

    auto bob = new StdSecureNet;
    {
        bob.generateKeyPair("Bob's secret password");
    }

    auto factory = RecordFactory(net);
    const alices_bills = factory.recorder(bills);

    import tagion.dart.BlockFile : fileId;
    import tagion.dart.DART : DART;
    immutable filename = fileId!SmartScript.fullpath;

    DART.create(filename);
    auto db =new DART(net, filename);
}
