/// \file RecorderChainBlock.d
module tagion.recorderchain.RecorderChainBlock;

import std.array;

import tagion.basic.Types : Buffer, FileExtension;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.dart.Recorder;
import tagion.hashchain.HashChainBlock : IHashChainBlock, IHashChainBlockFactory;
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
@safe class RecorderChainBlock : IHashChainBlock
{
    /** Fingerprint of this block */
    @Label("") Buffer fingerprint;
    /** Bullseye of DART database */
    @Label("eye") Buffer bullseye;
    /** Fingerprint of the chain before this block */
    @Label("chain") Buffer chain;
    /** Recorder with database changes of this block */
    @Label("recorder") Document recorder_doc;

    mixin JSONString;

    /** Ctor creates block from recorder, chain and bullseye.
     *      @param recorder_doc - Document with recorder for block
     *      @param chain - fingerprint of the chain before this block
     *      @param bullseye - bullseye of database
     *      @param net - hash net
     */
    mixin HiBONRecord!(
        q{
            private this(
                Document recorder_doc,
                Buffer chain,
                Buffer bullseye,
                const(StdHashNet) net)
            {
                this.recorder_doc = recorder_doc;
                this.chain = chain;
                this.bullseye = bullseye;

                this.fingerprint = net.hashOf(toDoc);
            }

            private this(
                const(Document) doc,
                const(StdHashNet) net)
            {
                this(doc);
                this.fingerprint = net.hashOf(toDoc);
            }
        });

    const RecordFactory.Recorder getRecorder(const(StdHashNet) net)
    {
        auto factory = RecordFactory(net);
        return factory.recorder(recorder_doc);
    }

    Buffer getFingerprint() const
    {
        return fingerprint;
    }

    Buffer getPrevious() const
    {
        return chain;
    }

    static FileExtension getExtension()
    {
        return FileExtension.recchainblock;
    }
}

/**
 * \class RecorderChainBlockFactory
 * Used for creating instance of RecorderChainBlock
 */
@safe class RecorderChainBlockFactory : IHashChainBlockFactory!RecorderChainBlock
{
    /** Hash net stored for creating RecorderChainBlocks */
    const StdHashNet net;

    @disable this();

    /** Ctor passes hash net to factory.
     *      @param net - hash net
     */
    this(const StdHashNet net)
    {
        this.net = net;
    }

    /** Ctor creates block from recorder, chain and bullseye.
     *      @param doc - document that conatins recorder, chain and bullseye
     *      \return instance of RecorderChainBlock
     */
    @trusted RecorderChainBlock opCall(const(Document) doc)
    {
        return new RecorderChainBlock(doc, net);
    }

    /** Ctor creates block from recorder, chain and bullseye.
     *      @param recorder - recorder for block
     *      @param chain - fingerprint of previous block
     *      @param bullseye - bullseye of database
     *      \return instance of RecorderChainBlock
     */
    RecorderChainBlock opCall(immutable(RecordFactory.Recorder) recorder, Buffer chain, Buffer bullseye)
    {
        return new RecorderChainBlock(recorder.toDoc, chain, bullseye, net);
    }
}

unittest
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
    Buffer chain = [1, 2, 4, 8, 16, 32, 64, 128];

    auto block_factory = new RecorderChainBlockFactory(net);

    /// RecorderChainBlock_create_block
    {
        auto block = block_factory(imm_recorder, chain, bullseye);

        assert(block.chain == chain);
        assert(block.bullseye == bullseye);
        assert(block.recorder_doc == imm_recorder.toDoc);
        assert(block.getRecorder(net).toDoc.serialize == imm_recorder.toDoc.serialize);

        assert(block.fingerprint == net.hashOf(block.toDoc));
    }

    /// RecorderChainBlock_toHiBON
    {
        enum chainLabel = GetLabel!(RecorderChainBlock.chain).name;
        enum recorderLabel = GetLabel!(RecorderChainBlock.recorder_doc).name;
        enum bullseyeLabel = GetLabel!(RecorderChainBlock.bullseye).name;

        auto block = block_factory(imm_recorder, chain, bullseye);

        assert(block.toHiBON[chainLabel].get!Buffer == chain);
        assert(block.toHiBON[bullseyeLabel].get!Buffer == bullseye);
        assert(block.toHiBON[recorderLabel].get!Document.serialize == imm_recorder.toDoc.serialize);

        assert(net.hashOf(Document(block.toHiBON)) == block.fingerprint);
    }

    /// RecorderChainBlock_restore_from_doc
    {
        auto block = block_factory(imm_recorder, chain, bullseye);
        auto block_doc = block.toDoc;

        auto restored_block = block_factory(block_doc);

        assert(block.toDoc.serialize == restored_block.toDoc.serialize);
    }

    /// RecorderChainBlock_from_doc_no_member
    {
        auto block = block_factory(imm_recorder, chain, bullseye);
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
