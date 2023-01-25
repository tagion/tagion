/// Actor run the Hashgraph consensus
module tagion.new_services.ConsensusActor;

import tagion.actor.Actor;
import tagion.new_services.ServiceException;
import tagion.utils.JSONCommon;

@safe
struct ConsensusOptions {
    string task_name;
    mixin JSONCommon;
}

@safe
struct ConsensusActor {

    @task void run(immutable(ConsensusOptions) opts);

    mixin TaskActor;
}
