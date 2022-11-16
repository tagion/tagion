/// \EpochChainBlock.d
module tagion.hashchain.EpochChainBlock;

import tagion.hashchain.HashChainBlock : HashChainBlock;
import tagion.hibon.HiBONJSON : JSONString;
import tagion.hibon.Document;
import tagion.hibon.HiBONRecord : Label,/* GetLabel,*/ HiBONRecord, RecordType;
import tagion.basic.Types : Buffer, FileExtension;
import tagion.crypto.SecureInterfaceNet : HashNet;

/** @brief File contains class EpochChainBlock
 */

/**
 * \class EpochChainBlock
 * Class represents epoch block from recorder chain
 */

@RecordType("HIBON")
@safe class EpochChainBlock : HashChainBlock
{
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

    Buffer getHash() const
    {
        return fingerprint;
    }

    Buffer getPrevious() const
    {
        return previous;
    }
}