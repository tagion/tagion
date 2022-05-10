module tagion.services.TranscriptService;

import std.format;
import std.concurrency;
import core.thread;
import std.array : join;
import std.exception : assumeUnique;

import tagion.services.Options;
import tagion.basic.Types : Control, Buffer;
import tagion.hashgraph.HashGraphBasic : EventBody;
import tagion.hibon.HiBON;
import tagion.hibon.Document;

import tagion.logger.Logger;

import tagion.basic.TagionExceptions;
import tagion.script.SmartScript;
import tagion.script.StandardRecords : Contract, SignedContract, PayContract;
import tagion.basic.ConsensusExceptions : ConsensusException;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.communication.HiRPC;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.Recorder : RecordFactory;
import tagion.hibon.HiBONJSON;

// This function performs Smart contract executions
void transcriptServiceTask(string task_name, string dart_task_name) nothrow {
    try {
        scope (success) {
            ownerTid.prioritySend(Control.END);
        }
        log.register(task_name);

        uint current_epoch;

        auto net = new StdSecureNet;
        auto rec_factory = RecordFactory(net);
        auto empty_hirpc = HiRPC(null);
        Tid dart_tid = locate(dart_task_name);
        SmartScript[Buffer] smart_scripts;

        bool stop;
        void controller(Control ctrl) {
            if (ctrl == Control.STOP) {
                stop = true;
                log("Scripting-Api %s stopped", task_name);
            }
        }

        void modifyDART(RecordFactory.Recorder recorder) {
            auto sender = empty_hirpc.dartModify(recorder);
            if (dart_tid !is Tid.init) {
                dart_tid.send("blackhole", sender.toDoc.serialize); //TODO: remove blackhole
            }
            else {
                log.error("Cannot locate DART service");
                stop = true;
            }
        }

        bool to_smart_script(SignedContract signed_contract) nothrow {
            try {
                auto smart_script = new SmartScript(signed_contract);
                smart_script.check(net, smart_script);
                const signed_contract_doc = signed_contract.toDoc;
                const fingerprint = net.HashNet.hashOf(signed_contract_doc);

                smart_script.run(current_epoch + 1);

                smart_scripts[fingerprint] = smart_script;
                return true;
            }
            catch (ConsensusException e) {
                log.warning("ConsensusException: %s", e.msg);
                return false;
                // Not approved
            }
            catch (TagionException e) {
                log.warning("TagionException: %s", e.msg);
                return false;
            }
            catch (Exception e) {
                log.warning("Exception: %s", e.msg);
                return false;
            }
            catch (Error e) {
                fatal(e);
                return false;
            }
        }

        void receive_epoch(Buffer payloads_buff) nothrow {
            try {
                auto payload_doc = Document(payloads_buff);
                log("Received epoch: len:%d", payload_doc.length);

                scope bool[Buffer] used_inputs;
                scope (exit) {
                    used_inputs = null;
                    smart_scripts = null;
                    current_epoch++;
                }
                auto recorder = rec_factory.recorder;
                foreach (payload_el; payload_doc[]) {
                    immutable doc = payload_el.get!Document;
                    log("PAYLOAD: %s", doc.toJSON);
                    if (!SignedContract.isRecord(doc)) {
                        continue;
                    }
                    import std.datetime : Clock;

                    log("Signed contract %s", Clock.currTime().toUTC());
                    scope signed_contract = new SignedContract(doc);
                    //smart_script.check(net);
                    bool invalid;
                    ForachInput: foreach (input; signed_contract.contract.input) {
                        if (input in used_inputs) {
                            invalid = true;
                            break ForachInput;
                        }
                        else {
                            used_inputs[input] = true;
                        }
                    }
                    if (!invalid) {
                        const signed_contract_doc = signed_contract.toDoc;
                        const fingerprint = net.hashOf(signed_contract_doc);
                        const added = to_smart_script(signed_contract);
                        if (added && fingerprint in smart_scripts) {
                            scope smart_script = smart_scripts[fingerprint];
                            const payment = PayContract(smart_script.signed_contract.input);
                            foreach (bill; payment.bills) {
                                const bill_doc = bill.toDoc;
                                recorder.remove(bill_doc);
                            }
                            foreach (bill; smart_script.output_bills) {
                                const bill_doc = bill.toDoc;
                                recorder.add(bill_doc);
                            }
                        }
                        else {
                            log("not in smart script");
                            invalid = true;
                        }
                    }
                    else {
                        log("invalid!!");
                    }
                }
                if (recorder.length > 0) {
                    log("Sending to dart len: %d", recorder.length);
                    recorder.dump;
                    modifyDART(recorder);
                }
                else {
                    log("Empty epoch");
                }
            }
            catch (Exception e) {
                log.warning("Epoch exception:%s ", e);
            }
            catch (Error e) {
                log.warning("Epoch throwable:%s ", e);
            }

        }

        uint counter;
        ownerTid.send(Control.LIVE);
        while (!stop) {
            receive(&receive_epoch, &controller, &taskfailure,
            );
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
