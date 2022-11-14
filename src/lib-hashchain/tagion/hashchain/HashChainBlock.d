/// \file HashChainBlock.d
module tagion.hashchain.HashChainBlock;

import tagion.basic.Types : Buffer;
import tagion.hibon.HiBON : HiBON;

/** @brief File contains interface for HashChainBlock
 */

/**
 * \interface HashChainBlock
 * Interface represents block from hash chain
 */
@safe interface HashChainBlock
{
    /** Returns hash of block
     *      \return hash
     */
    Buffer getHash() const;

    /** Returns fingerprint of previous block in chain
     *      \return fingerprint of previous block
     */
    Buffer getPrevious() const;

    /** Converts structure to HiBON
     *      \return HiBON copy of this structure
     */
    @trusted inout(HiBON) toHiBON() inout;
}
