/// \file RecorderChainBlock.d
module tagion.dart.RecorderChainBlock;

import std.array;
import std.algorithm : canFind;
import tagion.hibon.HiBONRecord : Label, GetLabel;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.basic.Types : Buffer;
import tagion.dart.Recorder;
import tagion.hibon.Document;
import tagion.crypto.SecureNet : StdHashNet;
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
        RecordFactory.Recorder recorder;
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
    private this(immutable RecordFactory.Recorder recorder, Buffer chain, Buffer bullseye, const(
            StdHashNet) net) immutable
    {
        this.recorder = recorder;
        this.chain = chain;
        this.bullseye = bullseye;

        this.fingerprint = net.hashOf(Document(toHiBON));
    }

    /** Generates \link HiBON from this block
     *      \return HiBON that contains this block
     */
    final const(HiBON) toHiBON() const
    in
    {
        assert(recorder, "recorder can't be empty");
    }
    do
    {
        auto hibon = new HiBON;
        hibon[chainLabel] = chain;
        hibon[bullseyeLabel] = bullseye;
        if (recorder)
        {
            hibon[recorderLabel] = recorder.toDoc;
        }
        return hibon;
    }

    /** Generates \link Document from this block
     *      \return Document that contains this block
     */
    final const(Document) toDoc() const
    {
        auto hibon = toHiBON;
        return Document(hibon);
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
    this(immutable(StdHashNet) net)
    {
        this.net = net;
    }

    /** Ctor creates block from recorder, chain and bullseye.
     *      @param doc - document that conatins recorder, chain and bullseye
     *      \return immutable instance of RecorderChainBlock
     */
    @trusted immutable(RecorderChainBlock) opCall(const(Document) doc)
    {
        auto factory = RecordFactory(net);
        immutable recorder = doc.keys.canFind(RecorderChainBlock.recorderLabel) ? factory.uniqueRecorder(
            doc[RecorderChainBlock.recorderLabel].get!Document) : cast(immutable) factory.recorder;

        Buffer chain = doc[RecorderChainBlock.chainLabel].get!Buffer;
        Buffer bullseye = doc[RecorderChainBlock.bullseyeLabel].get!Buffer;

        return new immutable(RecorderChainBlock)(recorder, chain, bullseye, this.net);
    }

    /** Ctor creates block from recorder, chain and bullseye.
     *      @param recorder - recorder for block
     *      @param chain - fingerprint of previous block
     *      @param bullseye - bullseye of database
     *      \return immutable instance of RecorderChainBlock
     */
    immutable(RecorderChainBlock) opCall(immutable(RecordFactory.Recorder) recorder, immutable(
            Buffer) chain, immutable(
            Buffer) bullseye)
    {
        return new immutable(RecorderChainBlock)(recorder, chain, bullseye, this.net);
    }
}
