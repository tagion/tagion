/// \EpochChainBlock.d
module tagion.epochain.EpochChainBlock;

import tagion.hashchain.HashChainBlock : HashChainBlock;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : Label, HiBONRecord, RecordType;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.crypto.SecureInterfaceNet : HashNet;

/** @brief File contains class EpochChainBlock
 */

/**
 * \class EpochChainBlock
 * Class represents epoch block from recorder chain
 */

@RecordType("EpochBlock")
@safe class EpochChainBlock : HashChainBlock {
    /** Fingerprint of this block */
    @Label("") Buffer fingerprint;
    /** Bullseye of DART database */
    @Label("eye") Buffer bullseye;
    /** Fingerprint of the previous block */
    @Label("previous") Buffer previous;
    /** List of the transactions */
    @Label("transactions_list") Document transactions_list;

    mixin JSONString;

    /** Ctor creates block from recorder, previous hash and bullseye.
     *      @param transactions - Document with list of transactions
     *      @param previous - fingerprint of the previous block
     *      @param bullseye - bullseye of database
     *      @param net - hash net
     */
    mixin HiBONRecord!(
            q{
            private this(
                Document transactions,
                Buffer previous,
                Buffer bullseye,
                const(HashNet) net)
            {
                this.transactions_list = transactions;
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

    Buffer getHash() const {
        return this.fingerprint;
    }

    Buffer getPrevious() const {
        return this.previous;
    }
}

unittest {
    import tagion.crypto.SecureNet : StdHashNet;

    /// EpochChainBlock_check_getters
    {
        import tagion.crypto.SecureNet : StdHashNet;

        auto hasher = new StdHashNet;
        Buffer bullseye = [1, 2, 3, 4];
        Buffer prev = null;
        auto doc = Document();
        auto item_one = new EpochChainBlock(doc, prev, bullseye, hasher);

        assert(item_one.bullseye == bullseye);
        assert(item_one.getPrevious() is null);
        assert(hasher.hashOf(item_one.toDoc) == item_one.getHash());
    }

    /// EpochChainBlock_check_hibon_serialization
    {
        auto hasher = new StdHashNet;
        Buffer bullseye = [1, 2, 3, 4];
        Buffer prev = null;
        auto doc = Document();
        auto item_one = new EpochChainBlock(doc, prev, bullseye, hasher);
        const ubyte[] expected_array = [
            56, 1, 2, 36, 64, 10, 69, 112, 111, 99, 104, 66, 108, 111, 99, 107, 3, 3,
            101, 121, 101, 4, 1, 2, 3, 4, 3, 8, 112, 114, 101, 118, 105, 111, 117, 115, 0, 2, 17, 116, 114, 97, 110,
            115, 97, 99, 116, 105, 111, 110, 115, 95, 108, 105, 115, 116, 0
        ];

        assert(item_one.toHiBON().serialize == expected_array);
    }
}
