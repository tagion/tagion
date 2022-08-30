module tagion.services.TranscriptService;

import std.format;
import std.concurrency;
import core.thread;
import std.array : join;
import std.datetime.systime;
import std.exception : assumeUnique;

import tagion.services.Options;
import tagion.basic.Types : Control, Buffer;
import tagion.hashgraph.HashGraphBasic : EventBody;
import tagion.hibon.HiBON;
import tagion.hibon.Document;

import tagion.logger.Logger;

import tagion.basic.TagionExceptions;
import tagion.script.SmartScript;
import tagion.script.StandardRecords : Contract, SignedContract, PayContract, HealthcheckParams;
import tagion.basic.ConsensusExceptions : ConsensusException;
import tagion.crypto.SecureNet : StdSecureNet;
import tagion.communication.HiRPC;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.Recorder : RecordFactory;
import tagion.hibon.HiBONJSON;

// This function performs Smart contract executions
void transcriptServiceTask(string task_name, string dart_task_name) nothrow
{
    try
    {
        HealthcheckParams health_params;

        HiRPC internal_hirpc = HiRPC(null);

        scope (success)
        {
            ownerTid.prioritySend(Control.END);
        }
        log.register(task_name);
        log("Transcript service started");

        uint current_epoch;
        uint count_transactions;
        long epoch_timestamp = Clock.currTime().toTimeSpec.tv_sec;

        const net = new StdSecureNet;
        auto rec_factory = RecordFactory(net);
        const empty_hirpc = HiRPC(null);
        Tid dart_tid = locate(dart_task_name);
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

        void modifyDART(RecordFactory.Recorder recorder)
        {
            auto sender = empty_hirpc.dartModify(recorder);
            if (dart_tid !is Tid.init)
            {
                dart_tid.send("blackhole", sender.toDoc.serialize); //TODO: remove blackhole
            }
            else
            {
                log.error("Cannot locate DART service");
                stop = true;
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

        void receive_healthcheck_request(string respond_task_name, Buffer data)
        {
            import std.stdio;

            // hirpc receive
            const received = internal_hirpc.receive(Document(data));
            writeln("recived healthcheck request");

            health_params.epoch_timestamp = epoch_timestamp;
            health_params.transactions_amount = count_transactions;
            health_params.epoch_num = current_epoch;

            const response = internal_hirpc.result(received, health_params.toDoc);
            log("Healthcheck: %s", response.toDoc.toJSON);

            locate(respond_task_name).send(response.toDoc.serialize);
        }

        RecordFactory.Recorder input_recorder;

        void receive_epoch(Buffer payloads_buff) nothrow
        {
            try
            {
                epoch_timestamp = Clock.currTime().toTimeSpec.tv_sec;
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
                    log("PAYLOAD: %s", doc.toJSON);
                    if (!SignedContract.isRecord(doc))
                    {
                        continue;
                    }
                    import std.datetime : Clock;

                    log("Signed contract %s", Clock.currTime().toUTC());
                    scope signed_contract = SignedContract(doc);
                    //smart_script.check(net);
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
                            count_transactions++;
                            scope smart_script = smart_scripts[fingerprint];
                            version (OLD_TRANSACTION)
                            {
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
                            log("not in smart script");
                            invalid = true;
                        }
                    }
                    else
                    {
                        log("invalid!!");
                    }
                }
                if (recorder.length > 0)
                {
                    log("Sending to dart len: %d", recorder.length);
                    recorder.dump;
                    modifyDART(recorder);
                }
                else
                {
                    log("Empty epoch");
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
                &receive_healthcheck_request,
            );
        }
    }

    catch (Throwable t)
    {
        fatal(t);
    }
}
