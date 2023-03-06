import std.stdio;
import core.runtime;

/// Used for describing the d-runtime status
enum drtStatus
{
    DEFAULT_STS,
    STARTED,
    TERMINATED
}
/// Variable, which repsresents the d-runtime status
__gshared drtStatus __runtimeStatus = drtStatus.DEFAULT_STS;

static int num = 0;

extern (C)
{
    /// Staritng d-runtime
    export static int start_rt()
    {
        if (__runtimeStatus is drtStatus.DEFAULT_STS)
        {
            __runtimeStatus = drtStatus.STARTED;
            return rt_init;
        }
        return -1;
    }

    /// Terminating d-runtime
    export static int stop_rt()
    {
        if (__runtimeStatus is drtStatus.STARTED)
        {
            __runtimeStatus = drtStatus.TERMINATED;   
            return rt_term;
        }
        return -1;
    }

    export static int increment()
    {
        num = num + 1;
        return num;
    }

    export static int result()
    {
        return num;
    }
}
