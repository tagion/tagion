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

        Buffer modifyDART(RecordFactory.Recorder recorder)
        {
            auto sender = empty_hirpc.dartModify(recorder);
            if (dart_tid !is Tid.init)
            {
                dart_tid.send("blackhole", sender.toDoc.serialize, true); //TODO: remove blackhole
                auto bullseye = receiveOnly!Buffer;
                log("TEST ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Transcript bullseye: %s", bullseye);
                return bullseye;
            }
            else
            {
                log.error("Cannot locate DART service");
                stop = true;
                return [];
            }
        }

        bool to_smart_script(ref const(SignedContract) signed_contract) nothrow
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
                    smart_script.run(current_epoch + 1);

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
                        const added = to_smart_script(signed_contract);
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
                    auto bullseye = modifyDART(recorder);
                    log("TEST ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Transcript 2 bullseye: %s", bullseye);

                    recorder_tid.send(rec_factory.uniqueRecorder(recorder), bullseye);
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
