module tagion.new_services.CollectorActor;

import tagion.actor.Actor;

import tagion.new_services.ServiceException;

struct CollectorOptions {
    string task_name;
}

struct CollectorActor {

    @task void run(immutable(CollectorOptions) opt);

}
