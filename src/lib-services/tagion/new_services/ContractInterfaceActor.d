/// Handels the validation of a HiRPC smart-contract
<<<<<<<< HEAD:src/lib-services/tagion/new_services/ContractInterfaceActor.d
module tagion.new_services.ContractInterfaceActor;
========
module tagion.new_services.CommunicationActor;
>>>>>>>> current-doc1:src/lib-services/tagion/new_services/CommunicationActor.d

import tagion.actor.Actor;
import tagion.new_services.ConsensusActor : ConsensusOptions;
import tagion.utils.JSONCommon;
import tagion.hibon.Document : Document;
import tagion.new_services.ServiceException;

@safe
<<<<<<<< HEAD:src/lib-services/tagion/new_services/ContractInterfaceActor.d
struct ContractInterfaceOptions {
    string protocol_id;
    string task_name; /// ContractInterface task name
========
struct CommunicationOptions {
    string protocol_id;
    string task_name; /// Communication task name
>>>>>>>> current-doc1:src/lib-services/tagion/new_services/CommunicationActor.d
    ushort max;
    version (OLD_TRANSACTION) {
        import tagion.network.SSLServiceOptions;

        SSLServiceOptions service; /// SSL Service used by the transaction service
    }
    mixin JSONCommon;
}

@safe
<<<<<<<< HEAD:src/lib-services/tagion/new_services/ContractInterfaceActor.d
struct ContractInterfaceActor {
========
struct CommunicationActor {
>>>>>>>> current-doc1:src/lib-services/tagion/new_services/CommunicationActor.d

    /**
Receives and validate a HiRPC containing a smart contract
*/
    @method void received(Document doc);

<<<<<<<< HEAD:src/lib-services/tagion/new_services/ContractInterfaceActor.d
    @task void run(immutable(ContractInterfaceOptions) trans_opts,
========
    @task void run(immutable(CommunicationOptions) trans_opts,
>>>>>>>> current-doc1:src/lib-services/tagion/new_services/CommunicationActor.d
            immutable(ConsensusOptions) consensus_opts);

    mixin TaskActor;
}
