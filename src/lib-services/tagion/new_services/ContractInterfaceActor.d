/// Handels the validation of a HiRPC smart-contract
module tagion.new_services.ContractInterfaceActor;

import tagion.actor.Actor;
import tagion.new_services.ConsensusActor : ConsensusOptions;
import tagion.utils.JSONCommon;
import tagion.hibon.Document : Document;
import tagion.new_services.ServiceException;

@safe
struct ContractInterfaceOptions {
    string protocol_id;
    string task_name; /// ContractInterface task name
    ushort max;
    version (OLD_TRANSACTION) {
        import tagion.network.SSLServiceOptions;

        SSLServiceOptions service; /// SSL Service used by the transaction service
    }
    mixin JSONCommon;
}

@safe
struct ContractInterfaceActor {

    /**
Receives and validate a HiRPC containing a smart contract
*/
    @method void received(Document doc);

    @task void run(immutable(ContractInterfaceOptions) trans_opts,
            immutable(ConsensusOptions) consensus_opts);

    mixin TaskActor;
}
