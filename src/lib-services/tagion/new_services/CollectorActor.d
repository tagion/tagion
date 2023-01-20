module tagion.new_services.CollectorActor;

import tagion.actor.Actor;


struct CollectorOptions {
    string task_name;
}


struct CollectorActor {

@tank void run(immutable(CollectorOptions) opt);

}

