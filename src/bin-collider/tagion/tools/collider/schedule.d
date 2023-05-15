module tagion.tools.collider.schedule;

import std.traits;
import std.array;
import std.typecons : tuple, Tuple;
import std.algorithm;
import std.process;
import std.datetime.systime;
import std.format;
import std.path : buildNormalizedPath;
import std.file : mkdirRecurse, exists;
import core.thread;
import tagion.utils.JSONCommon;
import tagion.tools.collider.reporter : ScheduleReport;

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
    auto stages() const pure nothrow {
        return units
            .byValue
            .map!(u => u.stages)
            .join
            .dup
            .sort
            .uniq;

    }
}

alias Runner = Tuple!(
        ProcessPipes, "pipe",
        RunUnit, "unit",
        string, "name",
        string, "stage",
        SysTime, "time",
        long, "jobid",
);

@safe
struct ScheduleOption {
    string dlog;
    string test_stage;
    void setDefault() {
        import std.ascii : toUpper;

        static foreach (name; FieldNameTuple!ScheduleOption) {
            {
                pragma(msg, "NAME ", name);
                /*
                enum name = name.map!(a => cast(char) a.toupper).array;
                try {
                    __traits(getmember, temp, name) = environment[name];
                }
                catch (exception e) {
                    // Ignore
                    // writeln(e.msg);
                    // errors++;
                }
        */
            }
        }
    }
}

enum TEST_STAGE = "TEST_STAGE";
enum COLLIDER_ROOT = "COLLIDER_ROOT";
enum BDD_LOG = "BDD_LOG";
enum BDD_RESULTS = "BDD_RESULTS";

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

    void setEnv(ref string[string] env, string stage) {
        if (stage) {
            env[TEST_STAGE] = stage;
        }
        if (COLLIDER_ROOT in env) {
            env[BDD_LOG] = buildNormalizedPath(env[COLLIDER_ROOT], stage);
            env[BDD_RESULTS] = buildNormalizedPath(env[COLLIDER_ROOT], stage, "results");
            if (!env[BDD_LOG].exists) {
                env[BDD_LOG].mkdirRecurse;
            }
            if (!env[BDD_RESULTS].exists) {
                env[BDD_RESULTS].mkdirRecurse;
            }
        }
    }

    int run(scope const(char[])[] args) {
        import std.stdio;

        schedule.toJSON.toPrettyString.writeln;

        alias Stage = Tuple!(RunUnit, "unit", string, "name", string, "stage");
        auto schedule_list = stages
            .map!(stage => schedule.units
                    .byKeyValue
                    .filter!(unit => unit.value.stages.canFind(stage))
                    .map!(unit => Stage(unit.value, unit.key, stage)))
            .joiner;

        writefln("list %s", schedule_list);
        writefln("stages %s", schedule_list.map!(u => u.stage));
        if (schedule_list.empty) {
            writefln("None of the stage %s available", stages);
            writefln("Avalibale %s", schedule.stages);
            return 1;
        }
        auto runners = new Runner[jobs];
        auto check_running = runners
            .filter!(r => r.pipe !is r.pipe.init)
            .any!(r => !tryWait(r.pipe.pid).terminated);

        writefln("Before start %s", check_running);
        writefln("Before start %s", schedule_list.empty);
        while (!schedule_list.empty || check_running) {
            writefln("name %s", schedule_list.front.name);
            while (!schedule_list.empty && !runners.all!(r => r.pipe !is r.pipe.init)) {
                try {
                    const runner_index = runners.countUntil!(r => r.pipe is r.pipe.init);
                    auto time = Clock.currTime;
                    const cmd = args ~ schedule_list.front.name ~ schedule_list.front.unit
                        .args;
                    writefln("cmd=%s", cmd);
                    auto env = environment.toAA;
                    schedule_list.front.unit.envs.byKeyValue
                        .each!(e => env[e.key] = e.value);
                    setEnv(env, schedule_list.front.stage);
                    //writefln("ENV %s ", env);
                    auto pipe = pipeProcess(cmd, Redirect.all, env);
                    writefln("--- %s start", cmd);
                    runners[runner_index] = Runner(
                            pipe,
                            schedule_list.front.unit,
                            schedule_list.front.name,
                            schedule_list.front.stage,
                            time,
                            runner_index
                    );
                }
                catch (Exception e) {
                    writefln("----Error %s", e.msg);
                }
                //              time);

                schedule_list.popFront;
            }
            for (;;) {
                sleep(100.msecs);
                const job_index = runners
                    .filter!(r => r.pipe !is r.pipe.init)
                    .countUntil!(r => tryWait(r.pipe.pid).terminated);
                writefln("job_index=%d", job_index);
                if (job_index >= 0) {
                    this.stop(runners[job_index]);
                    writefln("Dump job %d", job_index);
                    runners[job_index].pipe.stdout.writeln;
                    runners[job_index].pipe.stderr.writeln;

                    runners[job_index] = Runner.init;
                    writefln("Next job");
                    break;
                }
            }
            sleep(3000.msecs);
            writefln("END %d", jobs);
        }
        return 0;
    }
}
