module tagion.script.SmartScript;

import std.exception : assumeUnique;
import std.range : lockstep;
import std.format;

import tagion.gossip.InterfaceNet : SecureNet;
import tagion.basic.ConsensusExceptions : SmartScriptException, ConsensusFailCode, Check;
import tagion.script.StandardRecords : SignedContract, StandardBill;
import tagion.basic.Basic : Pubkey;
import tagion.script.Script : Script, ScriptContext;
import tagion.script.ScriptParser : ScriptParser;
import tagion.script.ScriptBuilder : ScriptBuilder;
import tagion.script.ScriptBase : Number;
import tagion.basic.Logger;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;

import tagion.script.ScriptCrypto;

alias check=Check!SmartScriptException;

@safe
ulong calcTotal(const(StandardBill[]) bills) {
    ulong result;
    foreach(b; bills) {
        result+=b.value;
    }
    return result;
}



@safe
class SmartScript {
    const SignedContract signed_contract;
    this(const SignedContract signed_contract) {
        this.signed_contract=signed_contract;
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
        const message=net.calcHash(signed_contract.contract.toHiBON.serialize);
        .check(signed_contract.signs.length >= signed_contract.input.length,
            ConsensusFailCode.SMARTSCRIPT_MISSING_SIGNATURE);
        .check(signed_contract.contract.input.length == signed_contract.input.length,
            ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING);

        foreach(i, print, input, signature; lockstep(signed_contract.contract.input, signed_contract.input, signed_contract.signs)) {
            import tagion.utils.Miscellaneous: toHexString;
            immutable fingerprint=net.calcHash(input.toHiBON.serialize);
            .check(print == fingerprint, ConsensusFailCode.SMARTSCRIPT_FINGERPRINT_DOES_NOT_MATCH_INPUT);
            Pubkey pkey=input.owner;
            .check(net.verify(message, signature, pkey),
                ConsensusFailCode.SMARTSCRIPT_INPUT_NOT_SIGNED_CORRECTLY);

        }
    }

    protected StandardBill[] _output_bills;

    const(StandardBill[]) output_bills() const pure nothrow {
        return _output_bills;
    }

    void run(const uint epoch) {
        // immutable source=signed_contract.contract.script;
        enum transactions_name="#trans";
        immutable source=format(": %s %s ;", transactions_name, signed_contract.contract.script);
        auto src=ScriptParser(source);
        Script script;
        auto builder=ScriptBuilder(src[]);
        builder.build(script);

        auto sc=new ScriptContext(10, 10, 10, 100);
        script.execute(transactions_name, sc);

        const total_input=calcTotal(signed_contract.input);
        ulong total_output;
        foreach(pkey; signed_contract.contract.output) {
            StandardBill bill;
            bill.epoch=epoch;
            const num=sc.pop.get!Number;
            pragma(msg, "fixme(cbr): Check for overflow");
            const amount=cast(ulong)num;
            total_output+=amount;
            bill.value=amount;
            bill.owner=pkey;
            bill.bill_type="TGN";
            _output_bills~=bill;
        }
        .check(total_output <= total_input, ConsensusFailCode.SMARTSCRIPT_NOT_ENOUGH_MONEY);
    }
}
