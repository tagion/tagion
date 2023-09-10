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
    this(immutable(CollectedSignedContract)* contract, const(Document)[] outputs) @trusted immutable {
        this.contract = contract;
        this.outputs = cast(immutable) outputs;
    }
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
        import std.exception;

        const pay_script = PayScript(exec_contract.sign_contract.contract.script);
        const input_ammount = exec_contract.inputs
            .map!(doc => TagionBill(doc).value)

            .totalAmount;
        const output_amount = pay_script.outputs.totalAmount;
        pragma(msg, "Outputs ", typeof(pay_script.outputs.map!(v => v.toDoc).array));
        const result = new immutable(ContractProduct)(
                exec_contract,
                pay_script.outputs.map!(v => v.toDoc).array);
        check(check_contract.validAmout(exec_contract, input_ammount, output_amount,
                GasUse(1000, result.outputs.map!(doc => doc.full_size).sum)), "Invalid amount");
        return result;
    }
}
