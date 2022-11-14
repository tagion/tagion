/// \file HashChainBlock.d
module tagion.hashchain.HashChainBlock;

import tagion.basic.Types : Buffer;

/** @brief File contains interface for HashChainBlock
 */

/**
 * \interface HashChainBlock
 * Interface represents block from hash chain
 */
interface HashChainBlock
{
    /** Returns hash of block
     *      \return hash
     */
    Buffer getHash() const;

    /** Returns fingerprint of previous block in chain
     *      \return fingerprint of previous block
     */
    Buffer getPrevious() const;
}
