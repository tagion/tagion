module logger;

import std.stdio;
import std.format;
import std.typecons;


static task_name = "logger";

alias Subscribed = shared(Flag!"subscribed");
shared struct SubscriptionMask {
    /// task_names[] topic
    private string[][string] _subscribers;
    ///     yes|no     topic
    private Subscribed[string] _registered_topics;

    Subscribed* register(string topic) {
        _registered_topics.update(topic,
            () => Subscribed.no,
            (string) {},
        );
        Subscribed* s = topic in _registered_topics;
        return s;
    }

    version(none)
    void subscribe(string topic) {
        register(topic);
        _registered_topics[topic] = Subscribed.yes;
        _subscribers.update(topic,
            () => [task_name],
            (string[] task_names) => (task_names ~= task_name),
        );
    }
}

static shared SubscriptionMask submask;


struct Logger {
    private Subscribed* subscribed;
    void event(T)(string topic, string id, T t) {
        if(subscribed.yes) {
            writeln();
        }
    }

}

Logger register_topic(string topic) {
    auto subscribed_handle = submask.register(topic);
    return Logger(subscribed_handle);
}

static Logger log;

template L(alias name) {
    void L() {
        log.event("*", __traits(identifier, name), name);
    }
}
