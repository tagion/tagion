module tagion.services.replicator;

import tagion.actor;
import tagion.crypto.SecureInterfaceNet;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.crypto.Types : Fingerprint;
import tagion.dart.Recorder : RecordFactory;
import tagion.logger.Logger;
import tagion.recorderchain.RecorderChain;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;
import tagion.services.messages;
import tagion.utils.Miscellaneous : cutHex;

@safe
struct ReplicatorOptions {
    import std.format;
    import tagion.utils.JSONCommon;

    string folder_path = "./recorder";

    void setPrefix(string prefix) nothrow {
        import std.exception;
        import std.path : buildPath;

        folder_path = folder_path ~ prefix;
        // assumeWontThrow(buildPath(folder_path, prefix));
    }

    mixin JSONCommon;
}

enum modify_log = "modify/replicator";

@safe
struct ReplicatorService {
    static Topic modify_recorder = Topic(modify_log);
    
    void task(immutable(ReplicatorOptions) opts) {
        HashNet net = new StdHashNet;
        
        RecorderChainStorage storage = new RecorderChainFileStorage(opts.folder_path, net);
        RecorderChain recorder_chain = new RecorderChain(storage);

        void receiveRecorder(SendRecorder, immutable(RecordFactory.Recorder) recorder, Fingerprint bullseye, immutable(long) epoch_number) {
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
