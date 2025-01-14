module tagion.unitmain;

import core.runtime;
import std.process : environment;

shared static this()
{

    Runtime.extendedModuleUnitTester = &customModuleUnitTester;
}

UnitTestResult customModuleUnitTester()
{
    import std.stdio;
    import std.algorithm.searching : canFind;
    import std.array : split;
    import std.datetime.stopwatch;
    StopWatch sw;

    string UNIT_MODULE = environment.get("UNIT_MODULE");

    // Do the same thing as the default moduleUnitTester:
    UnitTestResult result;
    const unit_module_list=UNIT_MODULE.split(" ");
    version(UINT_STOPWATCH) {
        enum unit_verbose = true;
    }
    else {
        const unit_verbose = environment.get("UNIT_STOPWATCH") !is string.init;
    }
    foreach (m; ModuleInfo)
    {
        if (m)
        {
            auto fp = m.unitTest;

            if (UNIT_MODULE !is string.init && !unit_module_list.canFind(m.name)) {
                continue;
            }

            if (fp)
            {
                if (unit_verbose) {
                    sw.reset;
                    sw.start;
                }
                ++result.executed;

                try
                {
                    fp();
                    ++result.passed;
                }
                catch (Throwable e)
                {
                    writeln(e);
                }
                if (unit_verbose) {
                    stderr.writefln("%s: %s", m.name, sw.peek);
                }
            }
        }
    }
    if (result.executed != result.passed)
    {
        result.runMain = false;  // don't run main
        result.summarize = true; // print failure
    }
    else
    {
        result.runMain = true;    // all UT passed
        result.summarize = true; // be quiet about it.
    }
    return result;
}

void main();
