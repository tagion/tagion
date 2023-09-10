module tagion.script.execute;
import std.algorithm;
import tagion.script.common;
import tagion.script.Currency;
import std.array;
import std.format;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : isRecord, getType;
import tagion.script.TagionCurrency;
import tagion.script.ScriptException;

@safe
struct ContractProduct {
    immutable(CollectedSignedContract*) contract;
    Document[] outputs;
}

@safe
struct CollectedSignedContract {
    Document[] inputs;
    Document[] reads;
    SignedContract sign_contract;
    //mixin HiBONRecord;
}

@safe
interface CheckContract {
    const(TagionCurrency) calcFees(immutable(CollectedSignedContract)* exec_contract, in TagionCurrency amount, in GasUse gas_use);
    bool validAmout(immutable(CollectedSignedContract)* exec_contract,
            in TagionCurrency input_ammount,
            in TagionCurrency output_amount,
            in GasUse use);
}

@safe
struct GasUse {
    size_t gas;
    size_t storage;
}

import tagion.utils.Result;

alias ContractProductResult = Result!(immutable(ContractProduct)*, Exception);

@safe
class StdCheckContract : CheckContract {
    TagionCurrency storage_fees; /// Fees per bytes
    TagionCurrency gas_price; /// Fees per TVM instruction
    const(TagionCurrency) calcFees(
            immutable(CollectedSignedContract)* exec_contract,
            in TagionCurrency amount,
            in GasUse use) {
        return use.gas * gas_price + use.storage * storage_fees;

    }

    bool validAmout(immutable(CollectedSignedContract)* exec_contract,
            in TagionCurrency input_ammount,
            in TagionCurrency output_amount,
            in GasUse use) {
        const gas_cost = calcFees(exec_contract, output_amount, use);
        return input_ammount + gas_cost <= output_amount;
    }

}

@safe
struct ContractExecution {
    static StdCheckContract check_contract;
    ContractProductResult opCall(immutable(CollectedSignedContract)* exec_contract) nothrow {
        const script_doc = exec_contract.sign_contract.contract.script;
        try {
            if (isRecord!PayScript(script_doc)) {
                return ContractProductResult(pay(exec_contract));
            }
            return ContractProductResult(format("Illegal corrected contract %s", script_doc.getType));
        }
        catch (Exception e) {
            return ContractProductResult(e);
        }
    }

    immutable(ContractProduct)* pay(immutable(CollectedSignedContract)* exec_contract) {
        const pay_script = PayScript(exec_contract.sign_contract.contract.script);
        const input_ammount = exec_contract.inputs
            .map!(doc => TagionBill(doc).value)

            .totalAmount;
        const output_amount = pay_script.outputs.totalAmount;

        return new immutable(ContractProduct)(
                exec_contract,
                pay_script.outputs
                .map!(v => v.toDoc)
                .array);

    }
}

version (none) {
    @safe
    class SmartScript {
        SignedContract signed_contract;
        RecordFactory.Recorder inputs;
        this(const SecureNet net, ref const SignedContract signed_contract) {
            //     this.signed_contract = signed_contract;
        }

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
                const message = net.calcHas(signed_contract.contract.toDoc);
                if (signed_contract.signs.length != inputs.length) {
                    return ConsensusFailCode.SMARTSCRIPT_MISSING_SIGNATURE_OR_INPUTS;
                }
                if (!inputs[].all!(a => a.filed.hasMember(OwnerKey) && a
                        .filed[OwnerKey].isType!Pubkey)) {
                    return ConsensusFailCode.SMARTSCRIPT_FINGERS_OR_INPUTS_MISSING;
                }
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
                    immutable fingerprint = net.dartIndex(input);

                    if (print != fingerprint) {
                        return ConsensusFailCode.SMARTSCRIPT_FINGERPRINT_DOES_NOT_MATCH_INPUT;
                    }
                    Pubkey pkey = input.filed[OwnerKey].get!Buffer;

                    if (!net.verify(message, signature, pkey)) {
                        return ConsensusFailCode.SMARTSCRIPT_INPUT_NOT_SIGNED_CORRECTLY;
                    }
                }
            }
            catch (TagionException e) {
                log.warning(e.msg);
                return ConsensusFailCode.SMARTSCRIPT_CAUGHT_TAGIONEXCEPTION;
            }
            catch (Exception e) {
                log.warning(e.msg);
                return ConsensusFailCode.SMARTSCRIPT_CAUGHT_EXCEPTION;
            }
            return ConsensusFailCode.NONE;
        }

        static ConsensusFailCode run(const(SecureNet) net, /*const(string) method,*/
                const ref SignedContract signed_contract,
                const RecordFactory.Recorder inputs,
                ref RecordFactory.Recorder outputs) {
            try {
                // check(net, signed_contract, inputs);
                auto total_input = inputs[]
                    .map!(a => a.filed)
                    .filter!(a => StandardBill.isRecord(a))
                    .map!(a => TagionCurrency(a["$V"].get!Document))
                    .sum;

                TagionCurrency total_output;
                foreach (key; signed_contract.contract.output) {
                    total_output += TagionCurrency(key["$V"].get!Document);
                }
                if (total_output > total_input - globals.fees()) {
                    return ConsensusFailCode.SMARTSCRIPT_INVALID_OUTPUT;
                }

                foreach (contract_output; signed_contract.contract.output) {
                    outputs.insert(contract_output);
                }
            }
            catch (SmartScriptException e) {
                log.error(e.msg);
                return ConsensusFailCode.SMARTSCRIPT_CAUGHT_SMARTSCRIPTEXCEPTION;
            }
            return ConsensusFailCode.NONE;
        }

        // version(none)
        // void run(const uint epoch) {
        //     assert(0);
        // }

        // // check values
        // version (none) void run(const uint epoch) {
        //     // immutable source=signed_contract.contract.script;
        //     enum transactions_name = "#trans";
        //     immutable source = (() @trusted =>
        //             format(": %s %s ;", transactions_name, signed_contract.contract.script)
        //     )();
        //     auto src = ScriptParser(source);
        //     Script script;
        //     auto builder = ScriptBuilder(src[]);
        //     builder.build(script);

        //     auto sc = new ScriptContext(10, 10, 10, 100);
        //     script.execute(transactions_name, sc);

        //     const payment = PayContract(signed_contract.input);
        //     const total_input = calcTotal(payment.bills);
        //     TagionCurrency total_output;
        //     foreach (pkey, doc; signed_contract.contract.output) {
        //         StandardBill bill;
        //         bill.epoch = epoch;
        //         const num = sc.pop.get!Number;
        //         pragma(msg, "fixme(cbr): Check for overflow");
        //         const amount = TagionCurrency(cast(long) num);
        //         total_output += amount;
        //         bill.value = amount;
        //         bill.owner = pkey;
        //         //            bill.bill_type = "TGN";
        //         _output_bills ~= bill;
        //     }

        //     .check(total_output <= total_input, ConsensusFailCode.SMARTSCRIPT_NOT_ENOUGH_MONEY);
        // }
    }
}
