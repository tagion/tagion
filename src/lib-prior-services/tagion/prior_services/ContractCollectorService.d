/// Handles the validation and smart-contract and verifies the Archives in the network
module tagion.prior_services.ContactCollectorService;

import std.concurrency;
import std.range : chain;

import tagion.basic.tagionexceptions;
import tagion.basic.Types : Control;
import tagion.logger.Logger;
import tagion.prior_services.Options;
import tagion.communication.HiRPC : HiRPC;
import tagion.hashgraph.HashGraphBasic : EventPackage;
import tagion.script.StandardRecords : SignedContract;
import tagion.prior_services.DARTSynchronizeService : DARTReadRequest;

void contractCollectorTask(immutable(Options) opts) nothrow {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }
        immutable task_name = opts.collector.task_name;
        log.register(task_name);

        const hirpc = HiRPC(null);

        auto transcript_tid = locate(opts.transcript.task_name);
        auto dart_sync_tid = locate(opts.dart.sync.task_name);
        bool stop;
        void control(Control ts) {
            switch (ts) {
            case Control.STOP:
                stop = true;
                break;
            default:
                // empty
            }
        }

        //        DARTReadRequest.Cache! cache;
        /// If the response_task_name is set
        version (none) void register_epack(immutable(EventPackage*) epack, immutable(
                ResponseRequest*) response) {
            import std.exception : assumeUnique;

            const doc = epack.event_body.payload;
            try {
                if (SignedContract.isRecord(doc)) {
                    const sigend_contract = SignedContract(doc);
                    // hirpc.dartRead(
                    //     chain(sigend_contract.contract.inputs, sigend_contract.contract.reads),
                    //     response.id);
                    //                    hirpc.opDispatch!"dartRead"(
                    immutable list_of_inputs = () @trusted => assumeUnique([
                        sigend_contract.contract.inputs,
                        sigend_contract.contract.reads
                    ]);
                    dart_sync_tid.send(list_of_inputs,
                            response.id);

                    //                    response(task_name, true);
                    return;
                }
            }
            catch (Exception e) {
                log.error("Package %s:", e.msg);
            }
            response(task_name, true);
        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receive(
                    &control, //                &register_epack

                    

            );
        }
    }
    catch (Exception e) {
        fatal(e);
    }
}
