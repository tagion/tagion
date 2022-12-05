/// \file EpochChain.d

module tagion.epochain.EpochChain;

import tagion.hashchain.HashChain;
import tagion.epochain.EpochChainBlock;

/** @brief File contains alias EpochChain (hash chain of epochs)
 */

alias EpochChain = HashChain!(EpochChainBlock);
