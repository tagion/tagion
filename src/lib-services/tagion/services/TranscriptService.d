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
import tagion.utils.Fingerprint : Fingerprint;

// This function performs Smart contract executions
void transcriptServiceTask(string task_name, string dart_task_name, string recorder_task_name) nothrow
{
    try
    {
        scope (success)
        {
            ownerTid.prioritySend(Control.END);
        }
        log.register(task_name);

        uint current_epoch;

        const net = new StdSecureNet;
        auto rec_factory = RecordFactory(net);
        const empty_hirpc = HiRPC(null);
        Tid dart_tid = locate(dart_task_name);
        Tid recorder_tid = locate(recorder_task_name);
        SmartScript[Buffer] smart_scripts;

        bool stop;
        void controller(Control ctrl)
        {
            if (ctrl == Control.STOP)
            {
                stop = true;
                log("Scripting-Api %s stopped", task_name);
            }
        }

        Fingerprint requestBullseye() {
            auto sender = DART.dartBullseye();
            if (dart_tid !is Tid.init)
            {
                dart_tid.send(task_name, sender.toDoc.serialize);

                const result = receiveOnly!Buffer;
                const received = empty_hirpc.receive(Document(result));
                return Fingerprint(received.response.result[DARTFile.Params.bullseye].get!Buffer);
            }
            else
            {
                log.error("Cannot locate DART service");
                stop = true;
                return Fingerprint([]);
            }
        }
        Fingerprint modifyDART(RecordFactory.Recorder recorder)
        {
            auto sender = empty_hirpc.dartModify(recorder);
            if (dart_tid !is Tid.init)
            {
                dart_tid.send(task_name, sender.toDoc.serialize);

                const result = receiveOnly!Buffer;
                const received = empty_hirpc.receive(Document(result));
                return Fingerprint(received.response.result[DARTFile.Params.bullseye].get!Buffer);
            }
            else
            {
                log.error("Cannot locate DART service");
                stop = true;
                return Fingerprint([]);
            }
        }

        void dumpRecorderBlock(immutable(RecordFactory.Recorder) recorder, immutable(Fingerprint) dart_bullseye)
        {
            if (recorder_tid is Tid.init)
            {
                recorder_tid = locate(recorder_task_name);
            }
            recorder_tid.send(recorder, dart_bullseye);
        }

        Fingerprint last_bullseye = requestBullseye();
        log("Start with bullseye: %X", last_bullseye);
        bool to_smart_script(ref const(SignedContract) signed_contract, ref uint index) nothrow
        {
            try
            {
                version (OLD_TRANSACTION)
                {
                    pragma(msg, "OLD_TRANSACTION ", __FILE__, ":", __LINE__);
                    auto smart_script = new SmartScript(signed_contract);
                    smart_script.check(net);
                    const signed_contract_doc = signed_contract.toDoc;
                    const fingerprint = net.HashNet.hashOf(signed_contract_doc);
                    uint prev_index = index;
                    smart_script.run(current_epoch + 1, index, last_bullseye, net);
                    assert(index == prev_index + smart_script.output_bills.length);
                    smart_scripts[fingerprint] = smart_script;
                }
                return true;
            }
            catch (ConsensusException e)
            {
                log.warning("ConsensusException: %s", e.msg);
                return false;
                // Not approved
            }
            catch (TagionException e)
            {
                log.warning("TagionException: %s", e.msg);
                return false;
            }
            catch (Exception e)
            {
                log.warning("Exception: %s", e.msg);
                return false;
            }
            catch (Error e)
            {
                fatal(e);
                return false;
            }
        }

        RecordFactory.Recorder input_recorder;

        void receive_epoch(Buffer payloads_buff) nothrow
        {
            try
            {

                const payload_doc = Document(payloads_buff);
                log("Received epoch: len:%d", payload_doc.length);

                scope bool[Buffer] used_inputs;
                scope (exit)
                {
                    used_inputs = null;
                    smart_scripts = null;
                    current_epoch++;
                }
                auto recorder = rec_factory.recorder;
                uint index = 0;
                foreach (payload_el; payload_doc[])
                {
                    immutable doc = payload_el.get!Document;
                    if (!SignedContract.isRecord(doc))
                    {
                        continue;
                    }

                    scope signed_contract = SignedContract(doc);
                    log("Executing contract: %s", doc.toJSON);

                    bool invalid;
                    ForachInput: foreach (input; signed_contract.contract.inputs)
                    {
                        if (input in used_inputs)
                        {
                            invalid = true;
                            break ForachInput;
                        }
                        else
                        {
                            used_inputs[input] = true;
                        }
                    }
                    if (!invalid)
                    {
                        const signed_contract_doc = signed_contract.toDoc;
                        const fingerprint = net.hashOf(signed_contract_doc);
                        const added = to_smart_script(signed_contract, index);
                        if (added && fingerprint in smart_scripts)
                        {
                            scope smart_script = smart_scripts[fingerprint];
                            version (OLD_TRANSACTION)
                            {
                                pragma(msg, "OLD_TRANSACTION ", __FUNCTION__, " ", __FILE__, ":", __LINE__);
                                foreach (bill; signed_contract.inputs)
                                {
                                    const bill_doc = bill.toDoc;
                                    recorder.remove(bill_doc);
                                }
                                pragma(msg, "OLD_TRANSACTION ", __FILE__, ":", __LINE__);
                                foreach (bill; smart_script.output_bills)
                                {
                                    const bill_doc = bill.toDoc;
                                    recorder.add(bill_doc);
                                }
                            }
                        }
                        else
                        {
                            log("Signed contract not in smart script");
                            invalid = true;
                        }
                    }
                    else
                    {
                        log.warning("Invalid input");
                    }
                }
                if (recorder.length > 0)
                {
                    log("Sending to DART len: %d", recorder.length);
                    recorder.dump;
                    last_bullseye = modifyDART(recorder);

                    dumpRecorderBlock(rec_factory.uniqueRecorder(recorder), last_bullseye);
                }
                else
                {
                    log("Received empty epoch");
                }
            }
            catch (Exception e)
            {
                log.warning("Epoch exception:%s ", e);
            }
            catch (Error e)
            {
                log.warning("Epoch throwable:%s ", e);
            }

        }

        void register_input(immutable(RecordFactory.Recorder) recorder)
        {

        }

        uint counter;
        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receive(

                &receive_epoch,

                &register_input,

                &controller,

                &taskfailure,
            );
        }
    }
    catch (Throwable t)
    {
        fatal(t);
    }
}
