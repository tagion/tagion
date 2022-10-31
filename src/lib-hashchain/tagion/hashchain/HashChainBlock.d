/// \file HashChainBlock.d
module tagion.hashchain.HashChainBlock;

import tagion.basic.Types : Buffer, FileExtension;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord : isHiBONRecord;

/** @brief File contains interfaces for HashChainBlock and HashChainBlockFactory
 */

/**
 * \interface IHashChainBlock
 * Interface represents block from hash chain
 */
interface IHashChainBlock
{
    /** Returns fingerprint of block
     *      \return hash fingerprint
     */
    Buffer getFingerprint() const;

    /** Returns fingerprint of previous block in chain
     *      \return fingerprint of previous block
     */
    Buffer getPrevious() const;

    /** Returns extension for block files
     *      \return file extension
     */
    static FileExtension getExtension();
}

/**
 * \interface IHashChainBlockFactory
 * Interface represents class for creating instance of block from hash chain
 */
interface IHashChainBlockFactory(Block : IHashChainBlock) if (isHiBONRecord!Block)
{
    /** Returns fingerprint of block
     *      @param Document that contains block from hash chain
     *      \return created block from document
     */
    Block opCall(const(Document));
}
