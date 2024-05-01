module tagion.testbench.actor.util;

import core.time;
import std.traits;
import std.meta;
import std.variant;
import tagion.actor.exceptions;
import tagion.utils.pretend_safe_concurrency : MessageMismatch, receiveTimeout;


private string format(Args...)(Args args) @trusted {
    import f = std.format;

    return f.format(args);
}

/// Exception sent when the actor gets a message that it doesn't handle
@safe class MessageTimeout : ActorException {
    this(immutable(char)[] msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

private template receiveOnlyRet(T...) {
    static if (T.length == 1) {
        alias receiveOnlyRet = T[0];
    }
    else {
        import std.typecons : Tuple;

        alias receiveOnlyRet = Tuple!(T);
    }
}

/**
* Throws: MessageTimeout, if no message is received before Duration
* Throws: WrongMessage, if incorrect message was received
*/
T receiveOnlyTimeout(T)(Duration d = 1.seconds)
@safe if(isType!T) {
    T ret;
    const received = receiveTimeout(
            d,
            (T val) { ret = val; },
            (Variant val) @trusted {
        throw new MessageMismatch(
            format("Unexpected message got \n\t%s \nof type \n\t%s \nexpected %s", val, val.type.toString(), T
            .stringof));
    }
    );

    if (!received) {
        throw new MessageTimeout(
                format(
                "Timed out never received message expected message type: \n\t%s".format(T.stringof))
        );
    }

    return ret;
}


void receiveOnlyTimeout(Args...)(Args handlers, Duration dur = 1.seconds)
@safe if(allSatisfy!(isCallable, Args) && allSatisfy!(isSafe, Args)) {
    bool received = receiveTimeout(dur, 
            handlers,
            (Variant var) @trusted {
                throw new Exception(format("Unknown msg: %s", var));
            }
        );
    assert(received, "Timed out");
}

import std.typecons : Tuple;

/// ditto
Tuple!(T) receiveOnlyTimeout(T...)(Duration d = 1.seconds) @safe
if (T.length > 1 && allSatisfy!(isType, T)) {

    Tuple!(T) ret;
    const received = receiveTimeout(
            d,
            (T val) @safe {
        static if (allSatisfy!(isAssignable, T)) {
            ret.field = val;
        }
        else {
            import core.lifetime : emplace;

            emplace(&ret, val);
        }
    },
            (Variant val) @trusted {
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
