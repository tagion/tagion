/// Handels the validation of a HiRPC smart-contract
module tagion.new_services.TransactionActor;

import tagion.actor.Actor;
import tagion.new_services.ConsensusActor : ConsensusOptions;
import tagion.utils.JSONCommon;
import tagion.hibon.Document : Document;

@safe
struct TransactionOptions {
    string protocol_id;
    string task_name; /// Transaction task name
    ushort max;
    import tagion.network.SSLServiceOptions;

    SSLServiceOptions service; /// SSL Service used by the transaction service
    mixin JSONCommon;
}

@safe
struct TransactionActor {

    /**
Receives and validate a HiRPC containing a smart contract
*/
    @method void received(Document doc);

    @task void run(immutable(TransactionOptions) trans_opts,
            immutable(ConsensusOptions) consensus_opts);

    mixin TaskActor;
}
