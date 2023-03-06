module tagion.new_services.DARTActor;

import tagion.actor.Actor;
import tagion.dart.DARTOptions;
import tagion.new_services.ServiceException;

struct DARTActor {

    @task void run(immutable(DARTOptions) opt);

    mixin TaskActor;
}
