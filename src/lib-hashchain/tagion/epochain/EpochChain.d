/// \file EpochChain.d

module tagion.epochain.EpochChain;

import tagion.epochain.EpochChainBlock;
import tagion.hashchain.HashChain;

/** @brief File contains alias EpochChain (hash chain of epochs)
 */

alias EpochChain = HashChain!(EpochChainBlock);
