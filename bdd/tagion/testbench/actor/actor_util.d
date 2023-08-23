module tagion.testbench.services.actor_util;

import tagion.utils.pretend_safe_concurrency : receiveTimeout, MessageMismatch;
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

private template receiveOnlyRet(T...)
{
    static if ( T.length == 1 )
    {
        alias receiveOnlyRet = T[0];
    }
    else
    {
        import std.typecons : Tuple;
        alias receiveOnlyRet = Tuple!(T);
    }
}

/**
* Throws: MessageTimeout, if no message is received before Duration
* Throws: MessageMismatch, if incorrect message was received
*/
T receiveOnlyTimeout(T)(Duration d = 1.seconds) @safe {
    T ret;
    const received = receiveTimeout(
            d,
            (T val) { ret = val; },
            (Variant val) {
        throw new MessageMismatch(
            format("Unexpected message got %s of type %s, expected %s", val, val.type.toString(), T
            .stringof));
    }
    );

    if (!received) {
        throw new MessageTimeout(
                format(
                "Timed out never received message expected message type: %s".format(T.stringof))
        );
    }

    return ret;
}

import std.typecons : Tuple;
/// ditto
Tuple!(T) receiveOnlyTimeout(T...)(Duration d = 1.seconds) @safe if (T.length > 1) {
    import std.meta : allSatisfy;
    import std.traits : isAssignable;

    Tuple!(T) ret;
    const received = receiveTimeout(
        d,
        (T val) {
            static if (allSatisfy!(isAssignable, T))
            {
                ret.field = val;
            }
            else
            {
                import core.lifetime : emplace;
                emplace(&ret, val);
            }
        },
        (Variant val) {
            throw new MessageMismatch(
                format("Unexpected message got %s of type %s, expected %s", val, val.type.toString(), T
                .stringof));
        }
    );

    if (!received) {
        throw new MessageTimeout(
                format(
                "Timed out never received message expected message type: %s".format(T.stringof))
        );
    }

    return ret;
}
