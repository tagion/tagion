/// Service for the tagion virtual machine 
/// [Documentation](https://docs.tagion.org/#/documents/architecture/TVM)
module tagion.services.TVM;

import std.stdio;
import core.time;

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
@safe
struct TVMOptions {
    import tagion.utils.JSONCommon;

    mixin JSONCommon;
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
@safe
struct TVMService {
    TVMOptions opts;
    TaskNames task_names;
    static ContractExecution execute;

    void task() {
        run(&contract, &consensus_contract);
    }

    void contract(signedContract, immutable(CollectedSignedContract)* collected) {
        auto result = execute(collected);
        if (result.error) {
            return;
        }
        locate(task_names.epoch_creator).send(Payload(), collected.sign_contract.contract.toDoc);
        locate(task_names.transcript).send(producedContract(), result.get);
    }

    void consensus_contract(consensusContract, immutable(CollectedSignedContract)* collected) {
        auto result = execute(collected);
        if (result.error) {
            return;
        }
        locate(task_names.transcript).send(producedContract(), result.get);
    }
}

alias TVMServiceHandle = ActorHandle!TVMService;

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
    import tagion.script.common;
    import tagion.crypto.Types;
    import tagion.script.TagionCurrency;
    import std.array;
    import tagion.utils.StdTime;
    import tagion.basic.Types : Buffer;
    import std.algorithm.iteration : map;

    const in_bills = iota(0, 10).map!(_ => TagionBill(TGN(100), sdt_t.init, Pubkey.init, Buffer.init).toDoc).array;
    const out_bills = iota(0, 10).map!(_ => TagionBill(TGN(50), sdt_t.init, Pubkey.init, Buffer.init)).array;
    auto collected = new CollectedSignedContract();
    collected.inputs ~= in_bills;
    collected.sign_contract.contract.script = PayScript(out_bills).toDoc;

    tvm_service.contract(signedContract(), cast(immutable) collected);
    collected = null;

    const received1 = receiveTimeout(
            Duration.zero,
            (Payload _, const(Document) __) {}
    );
    assert(received1, "Did not receive collected Payload");

    const received2 = receiveTimeout(
            Duration.zero,
            (producedContract _, immutable(ContractProduct)* __) {}
    );
    assert(received2, "Did not receive collected signedContract *");

}
