module tagion.services.locator;

import core.thread;
import core.time;
import tagion.utils.pretend_safe_concurrency;
import tagion.logger.Logger;
import tagion.basic.tagionexceptions;
import std.format;

/++
+/
@safe
class LocatorException : TagionException {
    this(string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
    }
}

@safe
struct LocatorOptions {
    uint max_attempts = 10; // The number of times we try to locate the thread.
    uint delay = 5; // Delay in msecs between next time we try to locate.
}

public shared static immutable(LocatorOptions)* locator_options;

/** 
 * Tries to locate the the thread id. If it is not found we try until max_attempts. 
 * Throws if no thread id was found.
 * Params:
 *   task_name = task name to locate
 * Returns: Tid
 */
Tid tryLocate(const(string) task_name) @trusted {
    import std.stdio;

    assert(locator_options !is null, "The locator option was not set");

    uint tries;

    do {
        auto task_id = locate(task_name);
        if (task_id !is Tid.init) {
            return task_id;
        }
        log.trace("trying to locate %s", task_name);
        Thread.sleep(locator_options.delay.msecs);
        tries++;
    }
    while (tries < locator_options.max_attempts);

    log.error("Thread with name: %s not found", task_name);
    throw new LocatorException(format("task_name %s could not be located", task_name));
    assert(0);
}
