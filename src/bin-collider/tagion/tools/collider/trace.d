/// trace for seeing runtime status of collider
module tagion.tools.collider.trace;

import tagion.tools.collider.schedule : Runner;
import std.stdio;
import tagion.utils.Term;
import std.range : repeat;

@safe
interface ScheduleTrace {
    void start(const ref Runner runner);
    void stop(const ref Runner runner);
    void timeout(const ref Runner runner);
    void initTrace(const long number_of_runners);
}

@safe
class TraceCallBacks : ScheduleTrace {

    long number_of_runners;

    void initTrace(const long number_of_runners) {
        this.number_of_runners = number_of_runners;

        CLEARSCREEN.write;
        foreach (i; 0 .. this.number_of_runners) {
            writefln("Runner %s idle", i);
        }
    }

    void goToLine(const ref Runner runner) {
        HOME.write;

        NEXTLINE.repeat(runner.jobid);

        CLEARLINE.write;
    }

    void start(const ref Runner runner) {
        goToLine(runner);
        writefln("Runner %s started %s", runner.jobid, runner.name);
    }

    void stop(const ref Runner runner) {
        goToLine(runner);
        writefln("Runner %s stopped %s", runner.jobid, runner.name);
    }

    void timeout(const ref Runner runner) {
        goToLine(runner);
        writefln("Runner %s timeout %s", runner.jobid, runner.name);
    }

}
