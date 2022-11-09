module tagion.services.TranscriptService;

import std.format;
import std.concurrency;
import core.thread;
import std.array : join;
import std.exception : assumeUnique;
import std.range : empty;
import std.file : dirEntries, SpanMode, isFile, DirIterator, exists;
import std.path : baseName;

import tagion.services.Options;
import tagion.basic.Types : Control, Buffer, FileExtension;
import tagion.hashgraph.HashGraphBasic : EventBody;
import tagion.hibon.HiBON;
import tagion.hibon.Document;

import tagion.logger.Logger;

import tagion.basic.TagionExceptions;
import tagion.script.SmartScript;
import tagion.script.StandardRecords : Contract, SignedContract, PayContract;
import tagion.basic.ConsensusExceptions : ConsensusException;
import tagion.crypto.SecureNet : StdSecureNet, StdHashNet;
import tagion.communication.HiRPC;
import tagion.dart.DART;
import tagion.dart.DARTFile;
import tagion.dart.Recorder : RecordFactory;
import tagion.hibon.HiBONJSON;
import tagion.utils.Fingerprint : Fingerprint;
import tagion.utils.Miscellaneous : toHexString;
import tagion.basic.Basic : fileExtension;
import tagion.hibon.HiBONRecord;

struct EpochDumpRecord
{
    static string previousHashData;

    @Label("") Buffer fingerprint;
    @Label("previous") string previous;
    @Label("bullseye") Buffer bullseye;

    static private bool isValidFile(string name)
    {
        enum HASHNAME_LEN = 64 + FileExtension.hibon.length + 1;
        auto cutname = baseName(name);
        return name.isFile() && (name.fileExtension == FileExtension.hibon) && (cutname.length == HASHNAME_LEN);
    }

    static private EpochDumpRecord* findPrevious(EpochDumpRecord[] records, string hash)
    {
        foreach(ref item; records)
        {
            if (item.previous == hash)
            {
                return &item;
            }
        }
        return null;
    }

    static bool isValidChain(string hash, string work_folder)
    {
        auto actual_hash = hash;
        enum TERMINATE = "0";
        do
        {
            auto file_name = actual_hash ~ "." ~ FileExtension.hibon;
            if (!work_folder.empty)
            {
                file_name = work_folder ~ "/" ~ file_name;
            }

            if (!file_name.exists)
            {
                return false;
            }
            auto item = fread!EpochDumpRecord(file_name);
            actual_hash = item.previous;
        }
        while(actual_hash != TERMINATE);
        return true;
    }

    static private string findAbsentWritedHash(EpochDumpRecord[] records)
    {
        foreach(item; records)
        {
            auto hash = toHexString(item.fingerprint);
            if (!findPrevious(records, hash))
            {
                return hash;
            }
        }
        assert(0, "check hashes collisions");
    }

    static string RestoreLastHash()
    {
        auto hasher = new StdHashNet;
        const options = getOptions();
        string folder_path = options.transaction_dumps_dirrectory;
        auto files = folder_path.dirEntries(SpanMode.shallow);
        EpochDumpRecord[] array;
        foreach(file; files)
        {
            if (isValidFile(file))
            {
                auto record = fread!EpochDumpRecord(file);
                record.fingerprint = hasher.rawCalcHash(record.toDoc.data);
                array = array ~ record;
            }
        }

        if (array.length == 0)
        {
            return "0";
        }
        auto absent_hash = findAbsentWritedHash(array);
        if (isValidChain(absent_hash, folder_path))
        {
            return absent_hash;
        }
        assert(0, "IVNALIDE CHAIN");
    }

    public string hashName()
    {
        return toHexString(this.fingerprint);
    }

    mixin HiBONRecord!(
        q{
            this(
                Buffer bullseye,
                const(StdHashNet) net)
            {
                this.bullseye = bullseye;
                this.previous = this.previousHashData;

                this.fingerprint = net.rawCalcHash(toDoc.serialize);
                this.previousHashData = toHexString(this.fingerprint);
            }
        });
}

private static void saveHashedDump(ref const Document bullseye)
{

    if (EpochDumpRecord.previousHashData.empty)
    {
        EpochDumpRecord.previousHashData = EpochDumpRecord.RestoreLastHash();
    }
    const static hasher = new StdHashNet;
    Buffer representation = bullseye.data;
    auto file = EpochDumpRecord(representation, hasher);
    const Options options = getOptions();
    auto actualHash = file.hashName();
    auto filename = actualHash ~ "." ~ FileExtension.hibon;
    string directory = options.transaction_dumps_dirrectory;
    fwrite(directory.empty ? filename : (directory ~ "/" ~ filename), file.toHiBON);
}

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

        Buffer modifyDART(RecordFactory.Recorder recorder, bool performDumping)
        {
            auto sender = empty_hirpc.dartModify(recorder);
            if (dart_tid !is Tid.init)
            {
                dart_tid.send(task_name, sender.toDoc.serialize);

                const result = receiveOnly!Buffer;
                const received = empty_hirpc.receive(Document(result));
                if (performDumping)
                {
                   saveHashedDump(sender.message);
                }
                return received.response.result[DARTFile.Params.bullseye].get!Buffer;
            }
            else
            {
                log.error("Cannot locate DART service");
                stop = true;
                return [];
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
                    const Options options = getOptions();
                    log("Sending to DART len: %d", recorder.length);
                    recorder.dump;
                    auto bullseye = modifyDART(recorder, !options.disable_transaction_dumping);

                    dumpRecorderBlock(rec_factory.uniqueRecorder(recorder), Fingerprint(bullseye));
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

unittest
{
    import std.file : remove, exists, mkdir, rmdirRecurse;

    auto hibon = new HiBON();
    hibon["A"] = "B";
    auto doc = Document(hibon);
    Options options = getOptions();
    options.transaction_dumps_dirrectory = "tmp_hashes";
    setOptions(options);

    mkdir(options.transaction_dumps_dirrectory);

    saveHashedDump(doc);
    saveHashedDump(doc);

    enum hashOne = "tmp_hashes/10236aa77cf4f3cb68c3871e6e2c7ee053d3e7e4c49e3635a3e8708a81637502.hibon";
    enum hashTwo = "tmp_hashes/c1b47d4425ba549aad30ec8386e5cba00e60ba76694ce1c82af8cefc53da6fe1.hibon";

    assert(exists(hashOne));
    assert(exists(hashTwo));
    rmdirRecurse(options.transaction_dumps_dirrectory);    
}
