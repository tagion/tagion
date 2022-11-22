/// \EpochDumpService.d
module tagion.services.EpochDumpService;

import std.concurrency;

import tagion.hashchain.HashChainStorage : HashChainStorage;
import tagion.hashchain.HashChainFileStorage : HashChainFileStorage;
import tagion.epochain.EpochChainBlock;
import tagion.epochain.EpochChain;
import tagion.basic.Types : Control, Buffer;
import tagion.basic.Basic : TrustedConcurrency;
import tagion.hibon.Document;
import tagion.tasks.TaskWrapper;
import tagion.crypto.SecureNet : StdHashNet;
import tagion.services.Options : Options;

mixin TrustedConcurrency;

/** @brief File contains service for handling and saving epochs chain blocks
 */

struct EpochDumpTask
{
    mixin TaskBasic;

    alias DumpEpochChainStorage = HashChainStorage!EpochChainBlock;
    alias DumpEpochChainFileStorage = HashChainFileStorage!EpochChainBlock;

    /** Epoch dumps storage */
    DumpEpochChainStorage _storage;

    /** Epoch chain stored for working with blocks */
    EpochChain epoch_chain;

    /** Default hasher */
    const StdHashNet hasher = new StdHashNet;

    @TaskMethod void dumpEpoch(Document transactions_list, Buffer bullseye)
    {
        auto last_block = epoch_chain.getLastBlock();
        auto last_hash = last_block ? last_block.fingerprint : [];
        auto block = new EpochChainBlock(transactions_list, last_hash, bullseye, hasher);
        epoch_chain.append(block);

        version (unittest)
        {
            ownerTid.send(Control.LIVE);
        }
    }

    /** Main service method that runs service
     *      @param opts - options for service
     */
    void opCall(immutable(Options) opts) @trusted
    {
        _storage = new DumpEpochChainFileStorage(opts.transaction_dumps_dirrectory, hasher);
        epoch_chain = new EpochChain(this._storage);

        ownerTid.send(Control.LIVE);
        while (!stop)
        {
            receive(&control, &dumpEpoch);
        }
    }
}