module tagion.tools.collider.schedule;

import std.traits;
import std.array;
import std.typecons : tuple, Tuple;
import std.algorithm;
import std.process;
import std.datetime.systime;
import std.format;
import std.path : buildNormalizedPath, setExtension;
import std.file : mkdirRecurse, exists;
import std.stdio;
import std.range;
import std.algorithm;
import std.array;
import core.thread;
import tagion.utils.JSONCommon;
import tagion.tools.collider.trace : ScheduleTrace;
import tagion.tools.Basic : dry_switch, verbose_switch;
import tagion.utils.envexpand;
import tagion.hibon.HiBONJSON;
import tagion.tools.toolsexception;

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
        //  ProcessPipes, "pipe",
        Pid, "pid",
        File, "fout",
        RunUnit, "unit",
        string, "name",
        string, "stage",
        SysTime, "time",
        long, "jobid",
);

enum TEST_STAGE = "TEST_STAGE";
enum COLLIDER_ROOT = "COLLIDER_ROOT";
enum BDD_LOG = "BDD_LOG";
enum BDD_RESULTS = "BDD_RESULTS";
@safe
struct ScheduleRunner {
    Schedule schedule;
    const(string[]) stages;
    const uint jobs;
    ScheduleTrace report;
    @disable this();
    this(
            ref Schedule schedule,
            const(string[]) stages,
    const uint jobs,
    ScheduleTrace report = null) pure nothrow
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

    static void kill(Pid pid) @trusted {
        try {

            

                .kill(pid); //.ifThown!ProcessException;
        }
        catch (ProcessException e) {
            // ignore
        }
    }

    void showEnv(const(string[string]) env, const(RunUnit) unit) {
        if (verbose_switch) {
            writeln("Environment:");
            env.byKeyValue
                .each!(e => writefln("%s = %s", e.key, e.value));
            return;
        }
        if (dry_switch) {
            writeln("Collider environment:");
            const env_list = [COLLIDER_ROOT, BDD_LOG, BDD_RESULTS, TEST_STAGE] ~ unit.envs.keys;
            env_list
                .each!(name => writefln("%s = %s", name, env.get(name, null)));
        }

    }

    int run(scope const(char[])[] args) {
        import std.stdio;

        //        schedule.toJSON.toPrettyString.writeln;

        alias Stage = Tuple!(RunUnit, "unit", string, "name", string, "stage");
        auto schedule_list = stages
            .map!(stage => schedule.units
                    .byKeyValue
                    .filter!(unit => unit.value.stages.canFind(stage))
                    .map!(unit => Stage(unit.value, unit.key, stage)))
            .joiner;

        if (schedule_list.empty) {
            writefln("None of the stage %s available", stages);
            writefln("Availabale %s", schedule.stages);
            return 1;
        }
        auto runners = new Runner[jobs];
        auto check_running = runners
            .filter!(r => r.pid !is r.pid.init)
            .any!(r => !tryWait(r.pid).terminated);

        while (!schedule_list.empty || check_running) {
            while (!schedule_list.empty && !runners.all!(r => r.pid !is r.pid.init)) {
                const job_index = runners.countUntil!(r => r.pid is r.pid.init);
                try {
                    auto time = Clock.currTime;
                    const cmd = args ~ schedule_list.front.name ~ schedule_list.front.unit
                        .args;
                    auto env = environment.toAA;
                    schedule_list.front.unit.envs.byKeyValue
                        .each!(e => env[e.key] = e.value);
                    setEnv(env, schedule_list.front.stage);
                    //writefln("ENV %s ", env);
                    auto fout = File(buildNormalizedPath(env[BDD_RESULTS],
                    schedule_list.front.name).setExtension("log"), "w");
                    auto _stdin = (() @trusted => stdin)();
                    auto pid = spawnProcess(cmd, _stdin, fout, fout, env);
                    writefln("%d] %-(%s %) # pid=%d", job_index, cmd, pid.processID);
                    runners[job_index] = Runner(
                            pid,
                            fout,
                            schedule_list.front.unit,
                            schedule_list.front.name,
                            schedule_list.front.stage,
                            time,
                            job_index
                    );
                }
                catch (Exception e) {
                    writefln("Error %s", e.msg);
                    runners[job_index].fout.writeln("Error: %s", e.msg);
                    runners[job_index].fout.close;
                    kill(runners[job_index].pid);
                    runners[job_index] = Runner.init;
                }
                //              time);

                schedule_list.popFront;
            }
            for (;;) {
                sleep(100.msecs);
                const job_index = runners
                    .filter!(r => r.pid !is r.pid.init)
                    .countUntil!(r => tryWait(r.pid).terminated);
                //                writefln("job_index=%d", job_index);
                if (job_index >= 0) {
                    this.stop(runners[job_index]);
                    runners[job_index].fout.close;
                    runners[job_index] = Runner.init;
                    writefln("Next job");
                    break;
                }
            }
            //            sleep(3000.msecs);
            //writefln("END %d", jobs);
        }
        return 0;
    }
}
