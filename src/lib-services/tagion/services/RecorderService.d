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
        auto block = recorder_block_factory(recorder, recorder_chain.last_block.fingerprint, bullseye
                .buffer);
        recorder_chain.push(block);
    }

    /** Main service method that runs service
     *      @param opts - options for service
     */
    void opCall(immutable(Options) opts)
    {
        recorder_chain = new RecorderChain(opts.recorder.folder_path, recorder_block_factory.net);

        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receive(&control, &receiveRecorder);
        }
    }
}
