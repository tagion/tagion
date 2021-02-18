module tagion.services.TranscriptService;

import std.format;
import std.concurrency;
import core.thread;
import std.array : join;
import std.exception : assumeUnique;

import tagion.Options;
import tagion.basic.Basic : Control, Buffer;
import tagion.hashgraph.HashGraphBasic : EventBody;
import tagion.hibon.HiBON;
import tagion.hibon.Document;

import tagion.basic.Logger;
//import tagion.utils.Random;
import tagion.basic.TagionExceptions;
import tagion.script.SmartScript;
import tagion.script.StandardRecords : Contract, SignedContract;
import tagion.basic.ConsensusExceptions : ConsensusException;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.communication.HiRPC;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.hibon.HiBONJSON;
//import tagion.gossip.EmulatorGossipNet;

// This function is just to perform a test on the scripting-api input
void transcriptServiceTask(string task_name, string dart_task_name) nothrow {
    scope(exit) {
        import std.exception : assumeWontThrow;
        log("Scripting-Api script test stopped");
        assumeWontThrow(ownerTid.send(Control.END));
    }

    try {
//        setOptions(opts);
//        immutable task_name=opts.transcript.task_name;
        log.register(task_name);
        // assert(opts.transcript.enable, "Scripting-Api test is not enabled");
        // assert(opts.transcript.pause_from < opts.transcript.pause_to);

        uint current_epoch;
        // Random!uint rand;
        // rand.seed(seed);
//    immutable name=[opts.node_name, options.transcript.name].join;
        // log("Scripting-Api script test %s started", task_name);
        // Tid node_tid=locate(opts.node_name);



        auto net=new StdSecureNet;
        auto empty_hirpc = HiRPC(null);
        scope SmartScript[Buffer] smart_scripts;

        bool stop;
        void controller(Control ctrl) {
            if ( ctrl == Control.STOP ) {
                stop=true;
                log("Scripting-Api %s stopped", task_name);
            }
        }


        void modifyDART(DARTFile.Recorder recorder) {
            Tid dart_tid = locate(dart_task_name);
            // auto sender = DART.dartModify(recorder, empty_hirpc);
            if (dart_tid != Tid.init){
                dart_tid.send(cast(immutable) recorder); //TODO: remove blackhole
            }
            else{
                log.error("Cannot locate Dart service");
                stop=true;
            }
        }


        void receive_epoch(Buffer payloads_buff) nothrow {
            try{
                // pragma(msg, "transcript: ", typeof(payloads));
                log("Received epoch: len:%d", payloads_buff.length);
                auto payload_doc = Document(payloads_buff);

                // log("Epoch: %s", payload_doc.toJSON);
                scope bool[Buffer] used_inputs;
                scope(exit) {
                    used_inputs=null;
                    smart_scripts=null;
                    current_epoch++;
                }
                auto recorder = DARTFile.Recorder(net);
                foreach(payload_el; payload_doc[]) {
                    immutable data=payload_el.get!Buffer;
                    const doc=Document(data);
                    // log("payload: %s", doc.toJSON);
                    scope signed_contract=SignedContract(doc);
                    //smart_script.check(net);
                    bool invalid;
                ForachInput:
                    foreach(input; signed_contract.contract.input) {
                        if (input in used_inputs) {
                            invalid=true;
                            break ForachInput;
                        }
                        else {
                            used_inputs[input]=true;
                        }
                    }
                    if (!invalid) {
                        const signed_contract_doc=Document(signed_contract.toHiBON.serialize);
                        const fingerprint=net.calcHash(signed_contract_doc.serialize);
                        if(fingerprint in smart_scripts){
                            scope smart_script=smart_scripts[fingerprint];
                            foreach(bill; smart_script.signed_contract.input){
                                const bill_doc=Document(bill.toHiBON.serialize);
                                recorder.remove(bill_doc);
                            }
                            foreach(bill; smart_script.output_bills){
                                const bill_doc=Document(bill.toHiBON.serialize);
                                recorder.add(bill_doc);
                            }
                        }
                        else{
                            invalid = true;
                        }
                    }
                }
                if(recorder.length > 0){
                    log("Sending to dart len: %d", recorder.length);
                    recorder.dump;
                    modifyDART(recorder);
                    // import tagion.utils.Miscellaneous: cutHex;
                    // log("Bullseye %s", bullseye.cutHex);
                }
                else{
                    log("Empty epoch");
                }
            }
            catch(Exception e){
                log.warning("Epoch exception:%s ", e);
            }
            catch(Error e){
                log.warning("Epoch throwable:%s ", e);
            }

        }

        void receive_ebody(immutable(EventBody) ebody) nothrow  {
            try {
                log("Received Ebody %d", ebody.payload.length);
                const doc=Document(ebody.payload);
                auto signed_contract=SignedContract(doc);
                auto smart_script=new SmartScript(signed_contract);
                smart_script.check(net);
                const signed_contract_doc=Document(signed_contract.toHiBON.serialize);
                const fingerprint=net.HashNet.calcHash(signed_contract_doc.serialize);

                smart_script.run(current_epoch+1);


                smart_scripts[fingerprint]=smart_script;
            }
            catch (ConsensusException e) {
                log.warning("ConsensusException: %s", e.msg);
                // Not approved
            }
            catch(TagionException e){
                log.warning("TagionException: %s", e.msg);
            }
            catch(Exception e){
                log.warning("Exception: %s", e.msg);
            }
            catch(Error e){
                fatal(e);
                //log("Throwable: %s", e.msg);
            }
        }

        // void taskfailure(immutable(TaskFailure) t) {
        //     ownerTid.send(t);
        // }

        // void tagionexception(immutable(TagionException) e) {
        //     ownerTid.send(e);
        // }

        // void exception(immutable(Exception) e) {
        //     ownerTid.send(e);
        // }

        // void throwable(immutable(Throwable) t) {
        //     ownerTid.send(t);
        // }

        uint counter;
        ownerTid.send(Control.LIVE);
        while(!stop) {
            //    immutable delay=rand.value(opts.transcript.pause_from, opts.transcript.pause_to);
            //  log("delay=%s", delay);

            receive(
                &receive_epoch,
                &receive_ebody,
                &controller,
                &taskfailure,
                // &tagionexception,
                // &exception,
                // &throwable,
                );
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
