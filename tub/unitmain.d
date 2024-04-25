module tagion.unitmain;

import core.runtime;
import core.atomic;
import core.thread;

shared static this()
{

    Runtime.extendedModuleUnitTester = &customModuleUnitTester;
}

UnitTestResult customModuleUnitTester()
{
    version(UNIT_STOPWATCH) import std.datetime.stopwatch;
    import std.stdio;

    version(UNIT_STOPWATCH) StopWatch sw;

    // Do the same thing as the default moduleUnitTester:
    UnitTestResult result;
    shared uint passed;
    foreach (m; ModuleInfo)
    {
        if (m)
        {
            auto fp = m.unitTest;

            if (fp)
            {
                version(UNIT_STOPWATCH) sw.reset;
                version(UNIT_STOPWATCH) sw.start;
                ++result.executed;
                /* stderr.writefln("Running %s", m.name); */

                new Thread({
                    try
                    {
                        fp();
                        passed.atomicOp!"+="(1);
                        /* ++result.passed; */
                    }
                    catch (Throwable e)
                    {
                        writeln(e);
                    }
                }).start();
                version(UNIT_STOPWATCH) stderr.writefln("%s: %s", m.name, sw.peek);
            }
        }
    }

    thread_joinAll();
    result.passed = passed;


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
