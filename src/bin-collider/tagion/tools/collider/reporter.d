/// Reporter for seeing runtime status of collider
module tagion.tools.collider.reporter;

import tagion.tools.collider.schedule : Runner;
import std.stdio;
import tagion.utils.Term;
import std.range : repeat;

@safe
interface ScheduleReport {
    void start(const ref Runner runner);
    void stop(const ref Runner runner);
    void timeout(const ref Runner runner);
    void initReport(const long number_of_runners);
}

@safe
class ReportCallBacks : ScheduleReport {

    long number_of_runners;

    void initReport(const long number_of_runners) {
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
