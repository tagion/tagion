/// \file RecorderService.d

module tagion.services.RecorderService;

import tagion.basic.Basic : TrustedConcurrency;
import tagion.basic.Types : Control;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.dart.RecorderChainBlock : RecorderChainBlockFactory;
import tagion.dart.Recorder : RecordFactory;
import tagion.dart.RecorderChain : RecorderChain;
import tagion.services.Options : Options;
import tagion.tasks.TaskWrapper;
import tagion.utils.Fingerprint : Fingerprint;

mixin TrustedConcurrency;

/** @brief File contains service for handling and saving recorder chain blocks
 */

@safe struct RecorderTask
{
    mixin TaskBasic;

    /** Recorder chain stored for working with blocks */
    RecorderChain recorder_chain;

    /** Recorder chain block factory. By default init with default net */
    RecorderChainBlockFactory recorder_block_factory = RecorderChainBlockFactory(new StdHashNet);

    /** Service method that receives recorder and bullseye and adds new block to recorder chain
     *      @param recorder - recorder for new block
     *      @param bullseye - bullseye of the database
     */
    @TaskMethod void receiveRecorder(immutable(RecordFactory.Recorder) recorder, immutable(
            Fingerprint) bullseye)
    {
        auto last_block = recorder_chain.getLastBlock;
        auto block = recorder_block_factory(
            recorder,
            last_block ? last_block.fingerprint : [],
            bullseye.buffer);

        recorder_chain.push(block);

        version (unittest)
        {
            ownerTid.send(Control.LIVE);
        }
    }

    /** Main service method that runs service
     *      @param opts - options for service
     */
    void opCall(immutable(Options) opts)
    {
        recorder_chain = new RecorderChain(opts.recorder.folder_path, recorder_block_factory
                .net);

        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receive(&control, &receiveRecorder);
        }
    }
}

/// RecorderService_add_many_blocks
unittest
{
    import tagion.basic.Basic : tempfile;
    import tagion.services.Options : setDefaultOption;

    const temp_folder = tempfile ~ "/";

    Options options;
    setDefaultOption(options);
    options.recorder.folder_path = temp_folder;
    scope (exit)
    {
        import std.file : rmdirRecurse;

        rmdirRecurse(temp_folder);
    }

    auto recorderService = Task!RecorderTask(options.recorder.task_name ~ "unittest", options);
    assert(receiveOnly!Control == Control.LIVE);
    scope (exit)
    {
        recorderService.control(Control.STOP);
        assert(receiveOnly!Control == Control.END);
    }

    enum blocks_count = 10;

    auto factory = RecordFactory(new StdHashNet);
    immutable empty_recorder = cast(immutable) factory.recorder;
    immutable empty_bullseye = Fingerprint([]);

    foreach (i; 0 .. blocks_count)
    {
        recorderService.receiveRecorder(empty_recorder, empty_bullseye);
        assert(receiveOnly!Control == Control.LIVE);
    }

    auto blocks_info = RecorderChain.getBlocksInfo(temp_folder, new StdHashNet);
    assert(blocks_info.amount == blocks_count);
    assert(blocks_info.first);
    assert(blocks_info.last);
}
