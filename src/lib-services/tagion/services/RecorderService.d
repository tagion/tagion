/// Handles the backup of the Recorders

module tagion.services.RecorderService;

import tagion.basic.Basic : TrustedConcurrency;
import tagion.basic.Types : Control;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.dart.Recorder : RecordFactory;
import tagion.logger.Logger : log;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;
import tagion.recorderchain.RecorderChain;
import tagion.services.Options : Options;
import tagion.actor.TaskWrapper;
import tagion.utils.Fingerprint : Fingerprint_;
import tagion.utils.Miscellaneous : cutHex;

mixin TrustedConcurrency;

/** @brief File contains service for handling and saving recorder chain blocks
 */

@safe struct RecorderTask {
    import tagion.utils.Fingerprint : Fingerprint_;
    mixin TaskBasic;

    /** Recorder chain stored for working with blocks */
    RecorderChain recorder_chain;

    /** Default hash net */
    const HashNet net = new StdHashNet;

    /** Service method that receives recorder and bullseye and adds new block to recorder chain
     *      @param recorder - recorder for new block
     *      @param bullseye - bullseye of the database
     */
    @TaskMethod void receiveRecorder(immutable(RecordFactory.Recorder) recorder, immutable(
            Fingerprint_) bullseye) {
        auto last_block = recorder_chain.getLastBlock;
        auto block = new RecorderChainBlock(
                recorder.toDoc,
                last_block ? last_block.fingerprint : [],
                bullseye.buffer,
                net);

        recorder_chain.append(block);
        log.trace("Added recorder chain block with hash '%s'", block.getHash.cutHex);

        version (unittest) {
            ownerTid.send(Control.LIVE);
        }
    }

    /** Main service method that runs service
     *      @param opts - options for service
     */
    void opCall(immutable(Options) opts) {
        RecorderChainStorage storage = new RecorderChainFileStorage(
                opts.recorder_chain.folder_path, net);

        recorder_chain = new RecorderChain(storage);

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receive(&control, &receiveRecorder);
        }
    }
}

/// RecorderService_add_many_blocks
unittest {
    import tagion.basic.Basic : tempfile;
    import tagion.services.Options : setDefaultOption;
    import tagion.utils.Fingerprint : Fingerprint_;

    const temp_folder = tempfile ~ "/";

    Options options;
    setDefaultOption(options);
    options.recorder_chain.folder_path = temp_folder;
    scope (exit) {
        import std.file : rmdirRecurse;

        rmdirRecurse(temp_folder);
    }

    auto recorderService = Task!RecorderTask(options.recorder_chain.task_name ~ "unittest", options);
    assert(receiveOnly!Control == Control.LIVE);
    scope (exit) {
        recorderService.control(Control.STOP);
        assert(receiveOnly!Control == Control.END);
    }

    log.silent = true;

    enum blocks_count = 10;

    auto factory = RecordFactory(new StdHashNet);
    immutable empty_recorder = cast(immutable) factory.recorder;
    immutable empty_bullseye = Fingerprint_([]);

    foreach (i; 0 .. blocks_count) {
        recorderService.receiveRecorder(empty_recorder, empty_bullseye);
        assert(receiveOnly!Control == Control.LIVE);
    }

    HashNet net = new StdHashNet;
    RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
    auto temp_recorder_chain = new RecorderChain(storage);
    assert(temp_recorder_chain.isValidChain);

    log.silent = false;
}
