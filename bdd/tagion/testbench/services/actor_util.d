module tagion.testbench.services.actor_util;

import std.concurrency : receiveTimeout, MessageMismatch;
import tagion.actor.exceptions;
import core.time;
import std.variant;
import std.format;

/// Exception sent when the actor gets a message that it doesn't handle
@safe class MessageTimeout : ActorException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

T receiveOnlyTimeout(T)() {
    T ret;
    receiveTimeout(
            2.seconds,
            (T val) { ret = val; },
            (Variant val) {
        throw new MessageMismatch(
            format("Unexpected message got %s of type %s, expected %s", val, val.type.toString(), T
            .stringof));
    }
    );

    if (ret is T.init) {
        throw new MessageTimeout(
                format(
                "Timed out never received message expected message type: %s".format(T.stringof))
        );
    }

    return ret;
}
