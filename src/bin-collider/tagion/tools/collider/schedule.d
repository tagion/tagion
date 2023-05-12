module tagion.tools.collider.schedule;

import std.typecons : tuple, Tuple;
import std.algorithm;
import std.process;
import std.datetime.systime;
import std.format;
import core.thread;
import tagion.utils.JSONCommon;

@safe
struct RunUnit {
    string[] stages;
    string[string] envs;
    string[] args;
    double timeout;
    mixin JSONCommon;
}

@safe
struct Schedule {
    RunUnit[string] units;
    mixin JSONCommon;
    mixin JSONConfig;
}

alias Runner = Tuple!(
        ProcessPipes, "pipe",
        RunUnit, "unit",
        string, "name",
        string, "stage",
        SysTime, "time"
);

@safe
interface ScheduleReport {
    void start(const ref Runner);
    void stop(const ref Runner);
    void timeout(const ref Runner);
}

@safe
struct ScheduleRunner {
    Schedule schedule;
    const(string[]) stages;
    const uint jobs;
    ScheduleReport report;
    @disable this();
    this(
            ref Schedule schedule,
            const(string[]) stages,
    const uint jobs,
    ScheduleReport report = null) pure nothrow
    in (jobs > 0)
    in (stages.length > 0)
    do {
        this.schedule = schedule;
        this.stages = stages;
        this.jobs = jobs;
        this.report = report;
    }

    static void sleep(Duration val) nothrow @nogc @trusted {
        Thread.sleep(val);
    }

    void opDispatch(string op, Args...)(Args args) {
        if (report) {
            enum code = format(q{report.%s(args);}, op);
            mixin(code);
        }
    }

    void run(scope const(char[])[] args) {
        import std.stdio;

        schedule.toJSON.toPrettyString.writeln;

        alias Stage = Tuple!(RunUnit, "unit", string, "name", string, "stage");
        auto schedule_list = stages
            .map!(stage => schedule.units
                    .byKeyValue
                    .filter!(unit => unit.value.stages.canFind(stage))
                    .map!(unit => Stage(unit.value, unit.key, stage)))
            .joiner;

        auto runners = new Runner[jobs];
        auto check_running = runners
            .filter!(r => r.pipe !is r.pipe.init)
            .any!(r => !tryWait(r.pipe.pid).terminated);

        while (!schedule_list.empty || check_running) {
            while (!schedule_list.empty && !runners.all!(r => r.pipe !is r.pipe.init)) {
                const index = runners.countUntil!(r => r.pipe is r.pipe.init);
                auto time = Clock.currTime;
                const cmd = args ~ schedule_list.front.stage ~ schedule_list.front.unit.args;
                auto pipe = pipeProcess(cmd);
                runners[index] = Runner(
                        pipe,
                        schedule_list.front.unit,
                        schedule_list.front.name,
                        schedule_list.front.stage,
                        time
                );
                //              time);

                schedule_list.popFront;
            }
            sleep(100.msecs);
            const index = runners
                .filter!(r => r.pipe !is r.pipe.init)
                .countUntil!(r => tryWait(r.pipe.pid).terminated);
            if (index >= 0) {
                this.stop(runners[index]);
                runners[index] = Runner.init;
            }
        }
    }
}
