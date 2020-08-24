module tagion.services.TranscriptService;

import std.format;
import std.concurrency;
import core.thread;
import std.array : join;
import std.exception : assumeUnique;

import tagion.Options;
import tagion.basic.Basic : Payload, Control, Buffer;
import tagion.hashgraph.Event : EventBody;
import tagion.hibon.HiBON;
import tagion.hibon.Document;

import tagion.services.LoggerService;
import tagion.utils.Random;
import tagion.basic.TagionExceptions;
import tagion.script.SmartScript;
import tagion.script.StandardRecords : Contract, SignedContract;
import tagion.hashgraph.ConsensusExceptions : ConsensusException;
import tagion.gossip.GossipNet : StdSecureNet;
import tagion.communication.HiRPC;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.hibon.HiBONJSON;
//import tagion.gossip.EmulatorGossipNet;

// This function is just to perform a test on the scripting-api input
void transcriptServiceTask(immutable(Options) opts) {
    setOptions(opts);
    immutable task_name=opts.transcript.task_name;
    log.register(task_name);
    // assert(opts.transcript.enable, "Scripting-Api test is not enabled");
    // assert(opts.transcript.pause_from < opts.transcript.pause_to);

    uint current_epoch;
    Random!uint rand;
    rand.seed(opts.seed);
//    immutable name=[opts.node_name, options.transcript.name].join;
    log("Scripting-Api script test %s started", task_name);
    Tid node_tid=locate(opts.node_name);
    node_tid.send(Control.LIVE);

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

    void modifyDART(DARTFile.Recorder recorder){
        // auto sender = DART.dartModify(recorder, empty_hirpc);
        Tid dart_tid = locate(opts.dart.task_name);
        if(dart_tid != Tid.init){
            dart_tid.send(cast(immutable) recorder); //TODO: remove blackhole
        }else{
            log("Cannot locate Dart service");
        }
    }
    void receive_epoch(Buffer payloads_buff) {
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
                    const fingerprint=net.calcHash(signed_contract.toHiBON.serialize);
                    if(fingerprint in smart_scripts){
                        scope smart_script=smart_scripts[fingerprint];
                        foreach(bill; smart_script.signed_contract.input){
                            recorder.remove(bill.toHiBON.serialize);
                        }
                        foreach(bill; smart_script.output_bills){
                            recorder.add(bill.toHiBON.serialize);
                        }
                    }else{
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
            }else{
                log("Empty epoch");
            }
        }catch(Exception e){
            log("Epoch exception:%s ", e);
        }
        catch(Throwable e){
            log("Epoch throwable:%s ", e);
        }

    }

    void receive_ebody(immutable(EventBody) ebody) {
        try {
            log("Received Ebody %d", ebody.payload.length);
            const doc=Document(ebody.payload);
            auto signed_contract=SignedContract(doc);
            auto smart_script=new SmartScript(signed_contract);
            smart_script.check(net);
            const fingerprint=net.calcHash(signed_contract.toHiBON.serialize);

            smart_script.run(current_epoch+1);


            smart_scripts[fingerprint]=smart_script;
        }
        catch (ConsensusException e) {
            log("ConsensusException: %s", e.msg);
            // Not approved
        }
        catch(TagionException e){
            log("TagionException: %s", e.msg);
        }catch(Exception e){
            log("Exception: %s", e.msg);
        }
        catch(Throwable e){
            log("Throwable: %s", e.msg);
        }
    }

    void tagionexception(immutable(TagionException) e) {
        ownerTid.send(e);
    }

    void exception(immutable(Exception) e) {
        ownerTid.send(e);
    }

    void throwable(immutable(Throwable) t) {
        ownerTid.send(t);
    }



    uint counter;

    scope(exit) {
        log("Scripting-Api script test stopped %s", task_name);
        node_tid.prioritySend(Control.END);
    }


    while(!stop) {
        //    immutable delay=rand.value(opts.transcript.pause_from, opts.transcript.pause_to);
        //  log("delay=%s", delay);

        receive(
            &receive_epoch,
            &receive_ebody,
            //&receive_payload,
            // &epoch,
            &controller,
            &tagionexception,
            &exception,
            &throwable,
            // (Buffer response, bool flag){
            //     auto receiver = empty_hirpc.receive(Document(response));
            //     auto bullseye = receiver.params[DARTFile.Params.bullseye].get!Buffer;

            //     import tagion.utils.Miscellaneous: cutHex;
            //     log("Bullseye %s", bullseye.cutHex);
            // }
            );
        // immutable message_received=receiveTimeout(delay.msecs, &controller);
        // log("message_received=%s", message_received);
        // if (!message_received) {
        //     // Send pseudo payload
        //     counter++;
        //     auto hibon=new HiBON;
        //     hibon["transaction"]=task_name;
        //     hibon["count"]=counter;

        //     // Sends the transaction script to the node
        //     log("Scripting-Api %s send counter=%s", task_name, counter);
        //     Payload payload=hibon.serialize;
        //     node_tid.send(payload);
        // }
    }
}
