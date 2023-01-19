/// Actor run the Hashgraph consensus
module tagion.new_services.ConsensusActor;

import tagion.actor.Actor;

@safe
struct ConsensusOptions {
    string task_name;
}

@safe
struct ConsensusActor {


@task void run(immutable(ConsensusOptions) opts);

mixin TaskActor;
}
