module tagion.new_services.DARTActor;

import tagion.actor.Actor;
import tagion.dart.DARTOptions;

struct DARTActor {

@task void run(immutable(DARTOptions) opt);

mixin TaskActor;
}
