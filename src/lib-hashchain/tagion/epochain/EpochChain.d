/// \file EpochChain.d

module tagion.recorder.EpochChain;

import tagion.hashchain.HashChain;
import tagion.hashchain.EpochChainBlock;

/** @brief File contains alias EpochChain (hash chain of epochs)
 */

alias EpochChain = HashChain!(EpochChainBlock);