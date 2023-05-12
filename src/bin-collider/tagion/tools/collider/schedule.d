module tagion.tools.collider.schedule;

import std.typecons : tuple, Tuple;
import std.algorithm;
import std.process;
import core.time;
import tagion.utils.JSONCommon;

@safe
struct RunUnit {
    string[] stages;
    string[string] envs;
    string[] args;
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
        string, "stage", //MonoTimeImpl, "time"

        

);

interface ScheduleReport {
    void start(const Runner);
    void stop(const Runner);
    void timeout(const Runner);
}

@safe
struct ScheduleRunner {
    const Schedule schedule;
    const(string[]) stages;
    const uint jobs;
    ScheduleReport report;
    @disable this();
    this(
            const Schedule schedule,
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

    void run(scope const(char[])[] args) {
        import std.stdio;

        schedule.toJSON.toPrettyString.writeln;
        
        alias Stage=Tuple!(const(RunUnit), "unit", string, "name", string, "stage");     
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
                auto time = MonoTime.currTime;
                pragma(msg, "Time ", typeof(time));
                pragma(msg, "Front ", typeof(schedule_list.front));
            const cmd = args~schedule_list.front.stage~schedule_list.front.unit.args;
                auto pipe=pipeProcess(cmd);
                runners[index] = Runner(
                        pipe,
                        schedule_list.front,
                        stage,
                        time);

                schedule_list.popFront;
            }
            Thread.delay(100.msec);
            const index = runners
                .filter!(r => r.pipe !is r.pipe.init)
                .countUntil!(r => tryWait(p.pipe.pid).terminated);
            if (index >= 0) {
                if (report) {
                    report(schedule_list.front, pipes[index]);
                }
                runners[index] = Runner.init;
            }
        }
    }
}
