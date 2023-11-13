/// Service for the tagion virtual machine 
/// [Documentation](https://docs.tagion.org/#/documents/architecture/TVM)
module tagion.services.TVM;

@safe:

import std.stdio;
import core.time;
import std.conv : to;

import tagion.logger.Logger;
import tagion.basic.Debug : __write;
import tagion.actor.actor;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.services.options;
import tagion.services.messages;
import tagion.logger.Logger;
import tagion.script.common;
import tagion.script.execute;
import tagion.utils.pretend_safe_concurrency : locate, send;

/// Msg type sent to receiver task along with a hirpc
//alias contractProduct = Msg!"contract_product";
struct TVMOptions {
    import tagion.utils.JSONCommon;

    mixin JSONCommon;
}

enum ResponseError {
    UnsupportedScript,
    ExecutionError,
}

/**
 * TVMService actor
 * Receives: 
 *  (signedContract, immutable(CollectedSignedContract)*)
 *  (consensusContract, immutable(CollectedSignedContract)*)
 *
 * Sends:
 *  (Payload, const(Document)) to TaskNames.epoch_creator
 *  (producedContract, immutable(ContractProduct)*) to TaskNames.transcript
**/
struct TVMService {
    TVMOptions opts;
    TaskNames task_names;
    static ContractExecution execute;
    static Topic tvm_error = Topic("error/tvm");

    void task() {
        run(&contract, &consensus_contract);
    }

    void contract(signedContract, immutable(CollectedSignedContract)* collected) {

        if (!engine(collected)) {
            log(tvm_error, ResponseError.UnsupportedScript.to!string, Document());
            return;
        }
        log("sending pload to epoch creator");
        locate(task_names.epoch_creator).send(Payload(), collected.sign_contract.toDoc);
    }

    void consensus_contract(consensusContract, immutable(CollectedSignedContract)* collected) {
        engine(collected);
    }

    bool engine(immutable(CollectedSignedContract)* collected) {
        log("received signed contract");
        if (!collected.sign_contract.contract.script.isRecord!PayScript) {
            log(tvm_error, ResponseError.UnsupportedScript.to!string);
            return false;
        }
        // import std.algorithm;
        // collected.inputs.each!(d => writefln("%s", d.toPretty));

        log("before sending to tvm");
        auto result = execute(collected);
        if (result.error) {
            log(tvm_error, ResponseError.ExecutionError.to!string, Document());
            log.trace("Execution error - %s\n%s", result.e.message, result.e);
            return false;
        }
        log("sending produced contract to transcript");
        locate(task_names.transcript).send(producedContract(), result.get);
        return true;
    }

}

unittest {
    import tagion.utils.pretend_safe_concurrency;
    import core.time;

    enum task_names = TaskNames();
    scope (exit) {
        unregister(task_names.transcript);
        unregister(task_names.epoch_creator);
    }
    register(task_names.transcript, thisTid);
    register(task_names.epoch_creator, thisTid);
    immutable opts = TVMOptions();
    auto tvm_service = TVMService(opts, task_names);

    import std.range : iota;
    import tagion.crypto.Types;
    import tagion.script.TagionCurrency;
    import tagion.utils.StdTime;
    import tagion.basic.Types : Buffer;
    import std.algorithm.iteration : map;
    import std.array;

    auto createCollected(uint input, uint output) {
        immutable(Document)[] in_bills;
        in_bills ~= iota(0, 10).map!(_ => TagionBill(TGN(input), sdt_t.init, Pubkey.init, Buffer.init).toDoc).array;
        immutable(TagionBill)[] out_bills;
        out_bills ~= iota(0, 10).map!(_ => TagionBill(TGN(output), sdt_t.init, Pubkey.init, Buffer.init)).array;

        auto contract = immutable(Contract)(null, null, PayScript(out_bills).toDoc);
        auto s_contract = new immutable(SignedContract)(null, contract);
        return new immutable(CollectedSignedContract)(
                s_contract,
                in_bills,
                null,
        );
    }

    { /// Positive test
        auto collected = createCollected(100, 50);
        tvm_service.contract(signedContract(), collected);

        foreach (_; 0 .. 2) {
            const received = receiveTimeout(
                    Duration.zero,
                    (Payload _, const(Document) __) {},
                    (producedContract _, immutable(ContractProduct)* __) {},
            );
            assert(received, "TVM did not send the contract or payload");
        }
    }

    { // False test
        auto collected = createCollected(50, 100);
        tvm_service.contract(signedContract(), collected);

        const received = receiveTimeout(
                Duration.zero,
                (Payload _, const(Document) __) {},
                (producedContract _, immutable(ContractProduct)* __) {},
        );
        assert(!received, "The tvm should not send a contract where the output bills are greater than the input");
    }
}
