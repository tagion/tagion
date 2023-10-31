/// \file RecorderChain.d
module tagion.recorderchain.RecorderChain;

import tagion.hashchain.HashChain : HashChain;
import tagion.hashchain.HashChainStorage : HashChainStorage;
import tagion.hashchain.HashChainFileStorage : HashChainFileStorage;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;

/** @brief File contains class RecorderChain
 */

/**
 * \class RecorderChain
 * Class stores info and handles local files of recorder chain
 */

alias RecorderChain = HashChain!(RecorderChainBlock);
alias RecorderChainStorage = HashChainStorage!RecorderChainBlock;
alias RecorderChainFileStorage = HashChainFileStorage!RecorderChainBlock;

unittest {
    import std.file;
    import std.path;
    import std.range : empty;

    import tagion.basic.basic : tempfile, fileId;
    import tagion.basic.Types : FileExtension;
    import tagion.crypto.SecureNet : StdSecureNet;
    import tagion.crypto.SecureInterfaceNet : SecureNet;
    import tagion.crypto.Types : Fingerprint;
    import tagion.dart.DART : DART;
    import tagion.dart.Recorder;
    import tagion.script.common : TagionBill;
    import tagion.script.TagionCurrency : TGN;
    import tagion.utils.Miscellaneous : toHexString;
    import tagion.utils.StdTime;

    const temp_folder = tempfile ~ "/";

    const dart_filename = fileId!RecorderChain(FileExtension.dart, "dart").fullpath;
    const dart_recovered_filename = fileId!RecorderChain(FileExtension.dart, "recovered").fullpath;
    const dart_genesis_filename = fileId!RecorderChain(FileExtension.dart, "genesis").fullpath;

    SecureNet net = new StdSecureNet;
    auto factory = RecordFactory(net);

    net.generateKeyPair("very secret password");

    TagionBill[] makeBills(uint epoch) {
        SecureNet secure_net = new StdSecureNet;
        {
            secure_net.generateKeyPair("secure_net secret password");
        }

        TagionBill[] bills;
        // bills ~= TagionBill(1000.TGN, currentTime, securenet);

        bills ~= TagionBill((1000).TGN, currentTime, secure_net.pubkey, null);
        bills ~= TagionBill((1200).TGN, currentTime, secure_net.derivePubkey("secure_net0"), null);
        bills ~= TagionBill((3000).TGN, currentTime, secure_net.derivePubkey("secure_net1"), null);
        bills ~= TagionBill((4300).TGN, currentTime, secure_net.derivePubkey("secure_net2"), null);

        return bills;
    }

    /// RecorderChain_replay_no_genesis
    {
        // Create empty recorder chain
        RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
        auto recorder_chain = new RecorderChain(storage);

        // Create empty DART
        DART.create(dart_filename, net);
        Exception dart_exception;
        auto dart = new DART(net, dart_filename, dart_exception);
        assert(dart_exception is null);

        // In loop fill DART and Add blocks
        enum blocks_count = 10;
        foreach (i; 0 .. blocks_count) {
            const bills_recorder = factory.recorder(makeBills(i), Archive.Type.ADD);
            dart.modify(bills_recorder);

            auto last_block = recorder_chain.getLastBlock;
            auto previous_hash = last_block is null ? Fingerprint.init : last_block.getHash;
            recorder_chain.append(new RecorderChainBlock(bills_recorder.toDoc,
                    previous_hash, Fingerprint(dart.fingerprint), i, net));
        }

        assert(recorder_chain.isValidChain);

        // Find last block with actual DART bullseye
        {
            auto block_last_bullseye = recorder_chain.storage.find(
                    (b) => b.bullseye == dart.fingerprint);
            assert(block_last_bullseye !is null);
            assert(
                    block_last_bullseye.toDoc.serialize == recorder_chain.getLastBlock.toDoc.serialize);
        }

        // Create new empty DART for recovery
        DART.create(dart_recovered_filename, net);
        auto dart_recovered = new DART(net, dart_recovered_filename, dart_exception);
        assert(dart_exception is null);

        // Replay blocks
        {
            recorder_chain.replay((RecorderChainBlock block) {
                auto block_recorder = factory.recorder(block.recorder_doc);
                dart_recovered.modify(block_recorder);

                assert(block.bullseye == dart_recovered.fingerprint);
            });
        }

        // Compare bullseyes of result DART and recovered from blocks
        assert(dart.fingerprint == dart_recovered.fingerprint);

        rmdirRecurse(temp_folder);
        remove(dart_filename);
        remove(dart_recovered_filename);
    }

    /// RecorderChain_replay_genesis
    {
        // Create empty recorder chain
        RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
        auto recorder_chain = new RecorderChain(storage);

        // Create empty DART
        DART.create(dart_filename, net);
        Exception dart_exception;
        auto dart = new DART(net, dart_filename, dart_exception);
        assert(dart_exception is null);

        // Add something to DART and make genesis
        const genesis_recorder = factory.recorder(makeBills(11), Archive.Type.ADD);
        dart.modify(genesis_recorder);
        dart_filename.copy(dart_genesis_filename);

        // In loop fill DART and Add blocks
        enum blocks_count = 10;
        foreach (i; 0 .. blocks_count) {
            const bills_recorder = factory.recorder(makeBills(i), Archive.Type.ADD);
            dart.modify(bills_recorder);

            auto last_block = recorder_chain.getLastBlock;
            auto previous_hash = last_block is null ? Fingerprint.init : last_block.getHash;
            recorder_chain.append(new RecorderChainBlock(bills_recorder.toDoc,
                    previous_hash,
                    Fingerprint(dart.fingerprint), i, net));
        }

        assert(recorder_chain.isValidChain);

        // Find last block with actual DART bullseye
        {
            auto block_last_bullseye = recorder_chain.storage.find(
                    (b) => b.bullseye == dart.fingerprint);
            assert(block_last_bullseye !is null);
            assert(
                    block_last_bullseye.toDoc.serialize == recorder_chain.getLastBlock.toDoc.serialize);
        }

        // Create new empty DART for recovery from saved genesis DART
        dart_genesis_filename.copy(dart_recovered_filename);
        auto dart_recovered = new DART(net, dart_recovered_filename, dart_exception);
        assert(dart_exception is null);

        // Replay blocks
        {
            recorder_chain.replay((RecorderChainBlock block) {
                auto block_recorder = factory.recorder(block.recorder_doc);
                dart_recovered.modify(block_recorder);

                assert(block.bullseye == dart_recovered.fingerprint);
            });
        }

        // Compare bullseyes of result DART and recovered from blocks
        assert(dart.fingerprint == dart_recovered.fingerprint);

        rmdirRecurse(temp_folder);
        remove(dart_filename);
        remove(dart_recovered_filename);
        remove(dart_genesis_filename);
    }

    /// RecorderChain_replayFrom
    {
        // Create empty recorder chain
        RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
        auto recorder_chain = new RecorderChain(storage);

        // Create empty DART
        DART.create(dart_filename, net);
        Exception dart_exception;
        auto dart = new DART(net, dart_filename, dart_exception);
        assert(dart_exception is null);

        // In loop fill DART and Add blocks
        enum blocks_count = 10;
        enum some_block_index = 4;
        foreach (i; 0 .. blocks_count) {
            const bills_recorder = factory.recorder(makeBills(i), Archive.Type.ADD);
            dart.modify(bills_recorder);

            auto last_block = recorder_chain.getLastBlock;
            auto previous_hash = last_block is null ? Fingerprint.init : last_block.getHash;
            recorder_chain.append(new RecorderChainBlock(
                    bills_recorder.toDoc,
                    previous_hash,
                    Fingerprint(dart.fingerprint),
                    i,
                    net));

            // In the middle of the chain copy dart that will be "outdated"
            if (i == some_block_index) {
                dart_filename.copy(dart_recovered_filename);
            }
        }

        auto recorder_chain_new = new RecorderChain(storage);

        assert(recorder_chain.isValidChain);
        assert(recorder_chain_new.isValidChain);

        // Find last block with actual DART bullseye
        {
            auto block_last_bullseye = recorder_chain_new.storage.find(
                    (b) => b.bullseye == dart.fingerprint);
            assert(block_last_bullseye !is null);
            assert(
                    block_last_bullseye.toDoc.serialize == recorder_chain_new
                    .getLastBlock.toDoc.serialize);
        }

        // Open outdated DART for recovery
        auto dart_recovered = new DART(net, dart_recovered_filename, dart_exception);
        assert(dart_exception is null);

        // Replay blocks from the middle of chain
        {
            recorder_chain_new.replayFrom((RecorderChainBlock block) {
                auto block_recorder = factory.recorder(block.recorder_doc);
                dart_recovered.modify(block_recorder);

                assert(block.bullseye == dart_recovered.fingerprint);
            },
                    (b) => (b.bullseye == dart_recovered.fingerprint));
        }

        // Compare bullseyes of result DART and recovered from blocks
        assert(dart.fingerprint == dart_recovered.fingerprint);

        rmdirRecurse(temp_folder);
        remove(dart_filename);
        remove(dart_recovered_filename);
    }

    /// RecorderChain_invalid_chain
    {
        // Create empty recorder chain
        RecorderChainStorage storage = new RecorderChainFileStorage(temp_folder, net);
        auto recorder_chain = new RecorderChain(storage);

        // Create empty DART
        DART.create(dart_filename, net);
        Exception dart_exception;
        auto dart = new DART(net, dart_filename, dart_exception);
        assert(dart_exception is null);

        // In loop fill DART and Add blocks
        enum blocks_count = 10;
        foreach (i; 0 .. blocks_count) {
            const bills_recorder = factory.recorder(makeBills(i), Archive.Type.ADD);
            dart.modify(bills_recorder);

            auto last_block = recorder_chain.getLastBlock;
            auto previous_hash = last_block is null ? Fingerprint.init : last_block.getHash;
            recorder_chain.append(new RecorderChainBlock(
                    bills_recorder.toDoc,
                    previous_hash,
                    Fingerprint(dart.fingerprint),
                    i,
                    net));
        }

        assert(recorder_chain.isValidChain);

        // Remove one block from chain
        {
            auto some_hash = recorder_chain.storage.getHashes[0];
            auto filename = buildPath(temp_folder, some_hash.toHexString.setExtension(
                    FileExtension.recchainblock));
            remove(filename);

            // Chain shouldn't be valid anymore
            assert(!recorder_chain.isValidChain);
        }

        // Create new empty DART for recovery
        DART.create(dart_recovered_filename, net);
        auto dart_recovered = new DART(net, dart_recovered_filename, dart_exception);
        assert(dart_exception is null);

        // Replay blocks
        {
            recorder_chain.replay((RecorderChainBlock block) {
                auto block_recorder = factory.recorder(block.recorder_doc);
                dart_recovered.modify(block_recorder);
            });
        }

        // Bullseyes should not be the same
        assert(dart.fingerprint != dart_recovered.fingerprint);

        rmdirRecurse(temp_folder);
        remove(dart_filename);
        remove(dart_recovered_filename);
    }
}
