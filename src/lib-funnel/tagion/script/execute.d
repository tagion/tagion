module tagion.script.execute;
import std.algorithm;
import std.array;
import std.format;
import std.range;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : getType, isRecord;
import tagion.logger.Logger;
import tagion.script.Currency;
import tagion.script.ScriptException;
import tagion.script.TagionCurrency;
import tagion.script.common;

@safe
struct ContractProduct {
    immutable(CollectedSignedContract*) contract;
    Document[] outputs;
    this(immutable(CollectedSignedContract)* contract, const(Document)[] outputs) @trusted immutable {
        this.contract = contract;
        this.outputs = cast(immutable) outputs;
    }
}

import tagion.dart.Recorder;

@safe
struct CollectedSignedContract {
    immutable(SignedContract)* sign_contract;
    const(Document)[] inputs;
    const(Document)[] reads;
}

@safe
interface CheckContract {
    const(TagionCurrency) calcFees(immutable(CollectedSignedContract)* exec_contract, in TagionCurrency amount, in GasUse gas_use);
    bool validAmount(immutable(CollectedSignedContract)* exec_contract,
            in TagionCurrency input_amount,
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
    TagionCurrency calcFees(in GasUse use) pure {
        return use.gas * gas_price + use.storage * storage_fees;
    }

    const(TagionCurrency) calcFees(
            immutable(CollectedSignedContract)* exec_contract,
            in TagionCurrency amount,
            in GasUse use) {
        return calcFees(use);
    }

    bool validAmount(immutable(CollectedSignedContract)* exec_contract,
            in TagionCurrency input_amount,
            in TagionCurrency output_amount,
            in GasUse use) {
        const gas_cost = calcFees(exec_contract, output_amount, use);
        return input_amount >= output_amount + gas_cost;
    }

}

@safe
struct ContractExecution {
    static StdCheckContract check_contract;
    enum pay_gas = 1000;
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

    static TagionCurrency _billFees(const size_t number_of_input_bytes, const size_t number_of_output_bytes) {
        const output_fee = check_contract.calcFees(GasUse(pay_gas, number_of_output_bytes));
        const input_fee = check_contract.calcFees(GasUse(0, number_of_input_bytes));
        return output_fee - input_fee;
    }

    static TagionCurrency billFees(R1, R2)(R1 inputs, R2 outputs, const size_t extra)
            if (isInputRange!R1 && isInputRange!R2 &&
                is(ElementType!R1 : const(Document)) && is(ElementType!R2 : const(Document))) {
        return _billFees(
                inputs.map!(doc => doc.full_size).sum,
                outputs.map!(doc => doc.full_size).sum + extra);

    }

    immutable(ContractProduct)* pay(immutable(CollectedSignedContract)* exec_contract) {
        import std.exception;

        const input_amount = exec_contract.inputs
            .map!(doc => TagionBill(doc).value)
            .totalAmount;

        const pay_script = PayScript(exec_contract.sign_contract.contract.script);
        const output_amount = pay_script.outputs
            .map!(bill => bill.value)
            .tee!(value => check(value > 0.TGN, "Output with 0 TGN not allowed"))
            .totalAmount;

        const output_docs = pay_script.outputs.map!(v => v.toDoc).array;
        const result = new immutable(ContractProduct)(
                exec_contract,
                output_docs);

        const bill_fees = billFees(exec_contract.inputs, output_docs, 0);
        check(input_amount >= (output_amount + bill_fees), "Invalid amount");
        return result;
    }
}

static this() {
    ContractExecution.check_contract = new StdCheckContract;
    ContractExecution.check_contract.storage_fees = 1.TGN;
    ContractExecution.check_contract.gas_price = 0.1.TGN;
}
