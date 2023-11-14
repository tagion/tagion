/// \EpochChainBlock.d
module tagion.epochain.EpochChainBlock;

import tagion.basic.Types : Buffer, FileExtension;
import tagion.crypto.SecureInterfaceNet : HashNet;
import tagion.crypto.Types : Fingerprint;
import tagion.hashchain.HashChainBlock : HashChainBlock;
import tagion.hibon.Document;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.hibon.HiBONRecord : HiBONRecord, exclude, label, recordType;

/** @brief File contains class EpochChainBlock
 */

/**
 * \class EpochChainBlock
 * Class represents epoch block from recorder chain
 */

@recordType("EpochBlock")
@safe class EpochChainBlock : HashChainBlock {
    /** Fingerprint of this block */
    @exclude Fingerprint fingerprint;
    /** Bullseye of DART database */
    @label("eye") Fingerprint bullseye;
    /** Fingerprint of the previous block */
    @label("previous") Fingerprint previous;
    /** List of the transactions */
    @label("transactions_list") Document transactions_list;

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
                Fingerprint previous,
                Fingerprint bullseye,
                const(HashNet) net)
            {
                this.transactions_list = transactions;
                this.previous = previous;
                this.bullseye = bullseye;

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
        return this.fingerprint;
    }

    Fingerprint getPrevious() const {
        return this.previous;
    }
}

unittest {
    import std.range : empty;
    import tagion.crypto.SecureNet : StdHashNet;

    /// EpochChainBlock_check_getters
    {
        import tagion.crypto.SecureNet : StdHashNet;

        auto hasher = new StdHashNet;
        Fingerprint bullseye = [1, 2, 3, 4];
        Fingerprint prev;
        auto doc = Document();
        auto item_one = new EpochChainBlock(doc, prev, bullseye, hasher);

        assert(item_one.bullseye == bullseye);
        assert(item_one.getPrevious.empty);
        assert(hasher.calcHash(item_one.toDoc) == item_one.getHash());
    }

}
