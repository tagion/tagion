/// \file RecorderChainBlock.d
module tagion.dart.RecorderChainBlock;

import std.array;
import std.algorithm : canFind;

import tagion.basic.TagionExceptions : TagionException;
import tagion.basic.Types : Buffer;
import tagion.dart.Recorder;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.hibon.HiBONRecord : Label, GetLabel;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.hibon.Document;
import tagion.hibon.HiBON : HiBON;

/** @brief File contains structure RecorderChainBlock and RecorderChainBlockFactory
 */

/**
 * \struct RecorderChainBlock
 * Struct represents block from recorder chain
 */
@safe class RecorderChainBlock
{
    public
    {
        /** Fingerprint of this block */
        @Label("") Buffer fingerprint;
        /** Bullseye of DART database */
        Buffer bullseye;
        /** Fingerprint of the chain before this block */
        Buffer chain;
        /** Recorder with database changes of this block */
        immutable(RecordFactory.Recorder) recorder;
    }

    @disable this();

    enum chainLabel = GetLabel!(chain).name;
    enum recorderLabel = GetLabel!(recorder).name;
    enum bullseyeLabel = GetLabel!(bullseye).name;
    mixin JSONString;

    /** Ctor creates block from recorder, chain and bullseye.
     *      @param recorder - recorder for block
     *      @param chain - fingerprint of the chain before this block
     *      @param bullseye - bullseye of database
     *      @param net - hash net
     */
    private this(
        immutable(RecordFactory.Recorder) recorder,
        Buffer chain,
        Buffer bullseye,
        const(StdHashNet) net)
    {
        this.recorder = recorder;
        this.chain = chain;
        this.bullseye = bullseye;

        this.fingerprint = net.hashOf(toDoc);
    }

    /** Generates \link HiBON from this block
     *      \return HiBON that contains this block
     */
    final const(HiBON) toHiBON() const
    {
        auto hibon = new HiBON;
        hibon[chainLabel] = chain;
        hibon[bullseyeLabel] = bullseye;
        hibon[recorderLabel] = recorder.toDoc;

        return hibon;
    }

    /** Generates \link Document from this block
     *      \return Document that contains this block
     */
    final const(Document) toDoc() const
    {
        return Document(toHiBON);
    }
}

/**
 * \struct RecorderChainBlockFactory
 * Used for creating instance of RecorderChainBlock
 */
@safe struct RecorderChainBlockFactory
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
        auto factory = RecordFactory(net);

        if (!doc.keys.canFind(RecorderChainBlock.recorderLabel))
        {
            throw new TagionException("Document must contain recorder for recorder chain block");
        }

        immutable recorder = factory.uniqueRecorder(
            doc[RecorderChainBlock.recorderLabel].get!Document);

        Buffer chain = doc[RecorderChainBlock.chainLabel].get!Buffer;
        Buffer bullseye = doc[RecorderChainBlock.bullseyeLabel].get!Buffer;

        return new RecorderChainBlock(recorder, chain, bullseye, net);
    }

    /** Ctor creates block from recorder, chain and bullseye.
     *      @param recorder - recorder for block
     *      @param chain - fingerprint of previous block
     *      @param bullseye - bullseye of database
     *      \return instance of RecorderChainBlock
     */
    RecorderChainBlock opCall(immutable(RecordFactory.Recorder) recorder, Buffer chain, Buffer bullseye)
    {
        return new RecorderChainBlock(recorder, chain, bullseye, net);
    }
}
