module tagion.script.SmartScript;

import std.exception : assumeUnique;
import std.range : lockstep;
import std.format;
import std.algorithm.iteration : sum, map;

import tagion.crypto.SecureInterfaceNet : SecureNet;
import tagion.basic.ConsensusExceptions : SmartScriptException, ConsensusFailCode, Check;
import tagion.script.StandardRecords : SignedContract, StandardBill, PayContract;
import tagion.basic.Types : Pubkey;
import tagion.script.TagionCurrency;
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
    const SignedContract signed_contract;
    this(const SignedContract signed_contract) {
        this.signed_contract = signed_contract;
    }

    void check(const SecureNet net) const {
        check(net, signed_contract);
    }

    @trusted
    static void check(const SecureNet net, const SignedContract signed_contract)
    in {
        assert(net);
    }
    do {



            .check(signed_contract.signs.length > 0, ConsensusFailCode.SMARTSCRIPT_NO_SIGNATURE);
        const message = net.hashOf(signed_contract.contract.toDoc);



        .check(signed_contract.signs.length >= signed_contract.input.length,
                ConsensusFailCode.SMARTSCRIPT_MISSING_SIGNATURE);



        .check(signed_contract.contract.input.length == signed_contract.input.length,
                ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING);
        const payment = PayContract(signed_contract.input);
        foreach (i, print, input, signature; lockstep(signed_contract.contract.input, payment.bills, signed_contract
                .signs)) {
            import tagion.utils.Miscellaneous : toHexString;

            immutable fingerprint = net.hashOf(input.toDoc);



            .check(print == fingerprint, ConsensusFailCode
                    .SMARTSCRIPT_FINGERPRINT_DOES_NOT_MATCH_INPUT);
            Pubkey pkey = input.owner;



            .check(net.verify(message, signature, pkey),
                    ConsensusFailCode.SMARTSCRIPT_INPUT_NOT_SIGNED_CORRECTLY);

        }
    }

    protected StandardBill[] _output_bills;

    const(StandardBill[]) output_bills() const pure nothrow {
        return _output_bills;
    }
    void run(const uint epoch) {
        assert(0);
    }

    version(none)
    void run(const uint epoch) {
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
