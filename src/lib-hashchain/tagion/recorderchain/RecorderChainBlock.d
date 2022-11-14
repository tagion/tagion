/// \file RecorderChainBlock.d
module tagion.recorderchain.RecorderChainBlock;

import std.array;

import tagion.basic.Types : Buffer, FileExtension;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.dart.Recorder;
import tagion.hashchain.HashChainBlock : HashChainBlock;
import tagion.hibon.HiBONRecord : Label, GetLabel, HiBONRecord, RecordType;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.hibon.Document;

/** @brief File contains class RecorderChainBlock and RecorderChainBlockFactory
 */

/**
 * \class RecorderChainBlock
 * Class represents block from recorder chain
 */
@RecordType("RCB")
@safe class RecorderChainBlock : HashChainBlock
{
    /** Fingerprint of this block */
    @Label("fingerprint") Buffer fingerprint;
    /** Bullseye of DART database */
    @Label("eye") Buffer bullseye;
    /** Fingerprint of the previous block */
    @Label("previous") Buffer previous;
    /** Recorder with database changes of this block */
    @Label("recorder") Document recorder_doc;

    mixin JSONString;

    /** Ctor creates block from recorder, previous hash and bullseye.
     *      @param recorder_doc - Document with recorder for block
     *      @param previous - fingerprint of the previous block
     *      @param bullseye - bullseye of database
     *      @param net - hash net
     */
    mixin HiBONRecord!(
        q{
            private this(
                Document recorder_doc,
                Buffer previous,
                Buffer bullseye,
                const(HashNet) net)
            {
                this.recorder_doc = recorder_doc;
                this.previous = previous;
                this.bullseye = bullseye;

                this.fingerprint = net.hashOf(toDoc);
            }

            private this(
                const(Document) doc,
                const(HashNet) net)
            {
                this(doc);
                this.fingerprint = net.hashOf(toDoc);
            }
        });

    Buffer getHash() const
    {
        return fingerprint;
    }

    Buffer getPrevious() const
    {
        return previous;
    }
}

version (none) unittest
{
    import tagion.basic.TagionExceptions : TagionException;
    import tagion.hibon.HiBON : HiBON;

    HiBON test_hibon = new HiBON;
    test_hibon["dummy1"] = 1;
    test_hibon["dummy2"] = 2;

    const net = new StdHashNet;
    auto factory = RecordFactory(net);
    auto dummy_recorder = factory.recorder;
    dummy_recorder.add(Document(test_hibon));

    immutable imm_recorder = factory.uniqueRecorder(dummy_recorder);

    Buffer bullseye = [1, 2, 3, 4, 5, 6, 7, 8];
    Buffer previous = [1, 2, 4, 8, 16, 32, 64, 128];

    auto block_factory = new RecorderChainBlockFactory(net);

    /// RecorderChainBlock_create_block
    {
        auto block = block_factory(imm_recorder, previous, bullseye);

        assert(block.previous == previous);
        assert(block.bullseye == bullseye);
        assert(block.recorder_doc == imm_recorder.toDoc);

        assert(block.fingerprint == net.hashOf(block.toDoc));
    }

    /// RecorderChainBlock_toHiBON
    {
        enum previousLabel = GetLabel!(RecorderChainBlock.previous).name;
        enum recorderLabel = GetLabel!(RecorderChainBlock.recorder_doc).name;
        enum bullseyeLabel = GetLabel!(RecorderChainBlock.bullseye).name;

        auto block = block_factory(imm_recorder, previous, bullseye);

        assert(block.toHiBON[previousLabel].get!Buffer == previous);
        assert(block.toHiBON[bullseyeLabel].get!Buffer == bullseye);
        assert(block.toHiBON[recorderLabel].get!Document.serialize == imm_recorder.toDoc.serialize);

        assert(net.hashOf(Document(block.toHiBON)) == block.fingerprint);
    }

    /// RecorderChainBlock_restore_from_doc
    {
        auto block = block_factory(imm_recorder, previous, bullseye);
        auto block_doc = block.toDoc;

        auto restored_block = block_factory(block_doc);

        assert(block.toDoc.serialize == restored_block.toDoc.serialize);
    }

    /// RecorderChainBlock_from_doc_no_member
    {
        auto block = block_factory(imm_recorder, previous, bullseye);
        auto block_hibon = block.toHiBON;
        block_hibon.remove(GetLabel!(RecorderChainBlock.bullseye).name);

        try
        {
            block_factory(Document(block_hibon));
            assert(false);
        }
        catch (TagionException e)
        {
        }
    }
}
