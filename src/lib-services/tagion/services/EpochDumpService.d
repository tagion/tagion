/// \EpochDumpService.d
module tagion.services.EpochDumpService;

import std.concurrency;

import tagion.hashchain.HashChainStorage : HashChainStorage;
import tagion.hashchain.HashChainFileStorage : HashChainFileStorage;
import tagion.epochain.EpochChainBlock;
import tagion.epochain.EpochChain;
import tagion.basic.Types : Control, Buffer;
import tagion.basic.Basic : TrustedConcurrency;
import tagion.hibon.Document;
import tagion.tasks.TaskWrapper;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.services.Options : Options, setDefaultOption;

mixin TrustedConcurrency;

/** @brief File contains service for handling and saving epochs chain blocks
 */

struct EpochDumpTask
{
    mixin TaskBasic;

    alias DumpEpochChainStorage = HashChainStorage!EpochChainBlock;
    alias DumpEpochChainFileStorage = HashChainFileStorage!EpochChainBlock;

    /** Epoch chain stored for working with blocks */
    EpochChain epoch_chain;

    /** Default hasher */
    const StdHashNet hash_net = new StdHashNet;

    @TaskMethod void dumpEpoch(Document transactions_list, Buffer bullseye)
    {
        auto last_block = epoch_chain.getLastBlock();
        auto last_hash = last_block ? last_block.fingerprint : [];
        auto block = new EpochChainBlock(transactions_list, last_hash, bullseye, this.hash_net);
        epoch_chain.append(block);

        version (unittest)
        {
            ownerTid.send(Control.LIVE);
        }
    }

    /** Main service method that runs service
     *      @param opts - options for service
     */
    void opCall(immutable(Options) opts) @trusted
    {
        DumpEpochChainStorage storage = new DumpEpochChainFileStorage(opts.epoch_dump.transaction_dumps_directory, this.hash_net);
        epoch_chain = new EpochChain(storage);

        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receive(&control, &dumpEpoch);
        }
    }
}

/// test hashes dump creating
unittest
{
    import std.file;
    import core.thread;
    import tagion.services.EpochDumpService : EpochDumpTask;
    import tagion.tasks.TaskWrapper : Task;
    import tagion.services.Options : Options, getOptions, setOptions;
    import tagion.hibon.HiBON;

    void saveHashedDump(Document list, Buffer bullseye, ref const string task_name)
    {
        Tid epoch_dump_service = locate(task_name);
        epoch_dump_service.send(list, bullseye);
    }

    auto doc = new HiBON();
    doc["A"] = "B";
    immutable ubyte[] eye = [6, 5, 4];
    auto realDoc = Document(doc);

    Options _options;
    _options.setDefaultOption;
    _options.epoch_dump.transaction_dumps_directory = "tmp_hashes";
    const string dumper_task = "dumper_task";
    auto task = Task!EpochDumpTask(dumper_task, _options);
    assert(receiveOnly!Control == Control.LIVE);

    scope (exit)
    {
        task.control(Control.STOP);
        receiveOnly!Control;
    }

    saveHashedDump(realDoc, eye, dumper_task);
    assert(receiveOnly!Control == Control.LIVE);

    saveHashedDump(realDoc, eye, dumper_task);
    assert(receiveOnly!Control == Control.LIVE);

    enum hashOne = "tmp_hashes/3746c7e6718203846e8d2676baeea127a1c144752721a7c7671c3373b89dca35.epdmp";
    enum hashTwo = "tmp_hashes/9f860b17e59c0b509127ce27dbb19433768ff857cc1c11c5ffad399a340654fa.epdmp";

    Thread.sleep(40.msecs);

    assert(exists(hashOne));
    assert(exists(hashTwo));

    auto hasher = new StdHashNet;
    EpochDumpTask.DumpEpochChainStorage storage = new EpochDumpTask.DumpEpochChainFileStorage(
        _options.epoch_dump.transaction_dumps_directory, hasher
    );
    auto epoch_chain = new EpochChain(storage);
    assert(epoch_chain.isValidChain);

    rmdirRecurse(_options.epoch_dump.transaction_dumps_directory);
}