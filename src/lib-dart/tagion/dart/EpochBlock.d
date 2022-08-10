/// \file EpochBlock.d
module tagion.dart.EpochBlock;

import std.array;
import std.algorithm : canFind;
import tagion.hibon.HiBONRecord : Label, GetLabel;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.basic.Types : Buffer;
import tagion.dart.Recorder;
import tagion.hibon.Document;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.hibon.HiBON : HiBON;

/** @brief File contains structure EpochBlock and EpochBlockFactory
 */

/**
 * \struct EpochBlock
 * Struct represents block from recorder chain
 */
@safe class EpochBlock
{
    public
    {
        /** Fingerprint of this block */
        @Label("") const Buffer fingerprint;
        /** Bullseye of DART database */
        const Buffer bullseye;
        /** Fingerprint of the chain before this block */
        const Buffer chain;
        /** Recorder with database changes of this block */
        const RecordFactory.Recorder recorder;
    }

    @disable this();

    enum chainLabel = GetLabel!(chain).name;
    enum recorderLabel = GetLabel!(recorder).name;
    enum bullseyeLabel = GetLabel!(bullseye).name;
    mixin JSONString;

    /** Ctor creates block from Document.
     *      @param doc - document that conatins recorder, chain and bullseye
     *      @param net - hash net
     */
    private this(const(Document) doc, const(StdHashNet) net) immutable
    {
        auto doc_keys = doc.keys.array;

        // recorder
        Document doc_recorder;
        if (doc_keys.canFind(recorderLabel))
            doc_recorder = doc[recorderLabel].get!Document;
        auto factory = RecordFactory(net);
        this.recorder = factory.uniqueRecorder(doc_recorder);

        // chain
        this.chain = doc[chainLabel].get!Buffer;

        // bullseye
        if (doc_keys.canFind(bullseyeLabel))
            this.bullseye = doc[bullseyeLabel].get!Buffer;

        // fingerprint
        this.fingerprint = net.hashOf(Document(toHiBON));
    }

    /** Ctor creates block from recorder, chain and bullseye.
     *      @param recorder - recorder for block
     *      @param chain - fingerprint of the chain before this block
     *      @param bullseye - bullseye of database
     *      @param net - hash net
     */
    private this(immutable(RecordFactory.Recorder) recorder, immutable Buffer chain, immutable Buffer bullseye, const(
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
        if (recorder)
        {
            hibon[recorderLabel] = recorder.toDoc;
        }
        if (bullseye)
        {
            hibon[bullseyeLabel] = bullseye;
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
 * \struct EpochBlockFactory
 * Used for creating instance of EpochBlock
 */
@safe struct EpochBlockFactory
{
    /** Hash net stored for creating EpochBlocks */
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
     *      \return immutable instance of EpochBlock
     */
    immutable(EpochBlock) opCall(const(Document) doc)
    {
        return new immutable(EpochBlock)(doc, this.net);
    }

    /** Ctor creates block from recorder, chain and bullseye.
     *      @param recorder - recorder for block
     *      @param chain - fingerprint of previous block
     *      @param bullseye - bullseye of database
     *      \return immutable instance of EpochBlock
     */
    immutable(EpochBlock) opCall(immutable(RecordFactory.Recorder) recorder, immutable(Buffer) chain, immutable(
            Buffer) bullseye)
    {
        return new immutable(EpochBlock)(recorder, chain, bullseye, this.net);
    }
}
