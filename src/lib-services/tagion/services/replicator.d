module tagion.services.replicator;

import tagion.actor;
import tagion.utils.Miscellaneous : cutHex;
import tagion.logger.Logger;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;
import tagion.recorderchain.RecorderChain;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.Recorder : RecordFactory;
import tagion.crypto.SecureInterfaceNet;
import tagion.services.messages;

@safe
struct ReplicatorOptions {
    import tagion.utils.JSONCommon;
    import std.format;

    string folder_path = "./recorder";

    void setPrefix(string prefix) nothrow {
        import std.path : buildPath;
        import std.exception;

        folder_path = folder_path ~ prefix;
        // assumeWontThrow(buildPath(folder_path, prefix));
    }

    mixin JSONCommon;
}

enum modify_log = "modify/replicator";

@safe
struct ReplicatorService {
    static Topic modify_recorder = Topic(modify_log);
    void task(immutable(ReplicatorOptions) opts, immutable(SecureNet) net) {
        RecorderChainStorage storage = new RecorderChainFileStorage(opts.folder_path, net);
        RecorderChain recorder_chain = new RecorderChain(storage);

        void receiveRecorder(SendRecorder, immutable(RecordFactory.Recorder) recorder, Fingerprint bullseye, immutable(int) epoch_number) {
            auto last_block = recorder_chain.getLastBlock;
            auto block = new RecorderChainBlock(
                    recorder.toDoc,
                    last_block ? last_block.fingerprint : Fingerprint.init,
                    bullseye,
                    epoch_number,
                    net);
            recorder_chain.append(block);
            log.trace("Added recorder chain block with hash '%s'", block.getHash.cutHex);
            log(modify_recorder, "modify", recorder);
        }

        run(&receiveRecorder);
    }

}

alias ReplicatorServiceHandle = ActorHandle!ReplicatorService;
