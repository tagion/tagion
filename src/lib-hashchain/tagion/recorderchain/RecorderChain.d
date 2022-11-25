/// \file RecorderChain.d
module tagion.recorderchain.RecorderChain;

import tagion.hashchain.HashChain : HashChain;
import tagion.hashchain.HashChainStorage : HashChainStorage;
import tagion.hashchain.HashChainFileStorage : HashChainFileStorage;
import tagion.recorderchain.RecorderChainBlock : RecorderChainBlock;

/** @brief File contains class RecorderChain
 */

/**
 * \class RecorderChain
 * Class stores info and handles local files of recorder chain
 */

alias RecorderChain = HashChain!(RecorderChainBlock);
alias RecorderChainStorage = HashChainStorage!RecorderChainBlock;
alias RecorderChainFileStorage = HashChainFileStorage!RecorderChainBlock;
