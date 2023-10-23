/// \file RecorderChainBlock.d
module tagion.recorderchain.RecorderChainBlock;

import std.array;

import tagion.basic.Types : Buffer, FileExtension;
import tagion.crypto.Types : Fingerprint;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.dart.Recorder;
import tagion.hashchain.HashChainBlock : HashChainBlock;
import tagion.hibon.HiBONRecord : label, exclude, GetLabel, HiBONRecord, recordType;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.hibon.Document;

/** @brief File contains class RecorderChainBlock and RecorderChainBlockFactory
 */

/**
 * \class RecorderChainBlock
 * Class represents block from recorder chain
 */
@recordType("RCB")
@safe class RecorderChainBlock : HashChainBlock {
    /** Fingerprint of this block */
    @exclude Fingerprint fingerprint;
    /** Bullseye of DART database */
    @label("eye") Fingerprint bullseye;
    /** Epoch number */
    @label("epoch_number") int epoch_number;
    /** Fingerprint of the previous block */
    @label("previous") Fingerprint previous;
    /** Recorder with database changes of this block */
    @label("recorder") Document recorder_doc;

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
                Fingerprint previous,
                Fingerprint bullseye,
                int epoch_number,
                const(HashNet) net)
            {
                this.recorder_doc = recorder_doc;
                this.previous = previous;
                this.bullseye = bullseye;
                this.epoch_number = epoch_number;

                this.fingerprint = net.calcHash(toDoc);
            }

            private this(
                const(Document) doc,
                const(HashNet) net)
            {
                this(doc);
                this.fingerprint = net.calcHash(toDoc);
            }
        });

    Fingerprint getHash() const {
        return fingerprint;
    }

    Fingerprint getPrevious() const {
        return previous;
    }
}

unittest {
    import tagion.basic.tagionexceptions : TagionException;
    import tagion.crypto.SecureNet : StdHashNet;
    import tagion.hibon.HiBON : HiBON;

    HiBON test_hibon = new HiBON;
    test_hibon["dummy1"] = 1;
    test_hibon["dummy2"] = 2;

    const net = new StdHashNet;
    auto factory = RecordFactory(net);
    auto dummy_recorder = factory.recorder;
    dummy_recorder.add(Document(test_hibon));

    auto doc_recorder = dummy_recorder.toDoc;

    Fingerprint bullseye = [1, 2, 3, 4, 5, 6, 7, 8];
    Fingerprint previous = [1, 2, 4, 8, 16, 32, 64, 128];
    int epoch_number = 0;

    /// RecorderChainBlock_create_block
    {
        auto block = new RecorderChainBlock(doc_recorder, previous, bullseye, epoch_number, net);

        assert(block.previous == previous);
        assert(block.bullseye == bullseye);
        assert(block.recorder_doc == doc_recorder);

        assert(block.fingerprint == net.calcHash(block.toDoc));
    }

    /// RecorderChainBlock_toHiBON
    {
        enum previousLabel = GetLabel!(RecorderChainBlock.previous).name;
        enum recorderLabel = GetLabel!(RecorderChainBlock.recorder_doc).name;
        enum bullseyeLabel = GetLabel!(RecorderChainBlock.bullseye).name;

        auto block = new RecorderChainBlock(doc_recorder, previous, bullseye, epoch_number, net);

        assert(block.toHiBON[previousLabel].get!Buffer == previous);
        assert(block.toHiBON[bullseyeLabel].get!Buffer == bullseye);
        assert(block.toHiBON[recorderLabel].get!Document.serialize == doc_recorder.serialize);

        assert(net.calcHash(Document(block.toHiBON)) == block.fingerprint);
    }

    /// RecorderChainBlock_restore_from_doc
    {
        auto block = new RecorderChainBlock(doc_recorder, previous, bullseye, epoch_number, net);
        auto restored_block = new RecorderChainBlock(block.toDoc);

        assert(block.toDoc.serialize == restored_block.toDoc.serialize);
    }

    /// RecorderChainBlock_from_doc_no_member
    {
        auto block = new RecorderChainBlock(doc_recorder, previous, bullseye, epoch_number, net);
        auto block_hibon = block.toHiBON;
        block_hibon.remove(GetLabel!(RecorderChainBlock.bullseye).name);

        try {
            new RecorderChainBlock(Document(block_hibon));
            assert(false);
        }
        catch (TagionException e) {
        }
    }
}
