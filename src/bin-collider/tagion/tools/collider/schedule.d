module tagion.tools.collider.schedule;

import core.thread;
import std.algorithm;
import std.array;
import std.datetime.systime;
import std.file : exists, mkdirRecurse;
import std.format;
import std.path : buildNormalizedPath, setExtension;
import std.process;
import std.range;
import std.stdio;
import std.traits;
import std.path;
import std.typecons : Tuple, tuple;
import tagion.hibon.HiBONJSON;
import tagion.tools.Basic : dry_switch, verbose_switch;
import tagion.tools.collider.BehaviourOptions;
import tagion.tools.collider.trace : ScheduleTrace;
import tagion.tools.toolsexception;
import tagion.utils.JSONCommon;
import tagion.utils.envexpand;

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
    const BehaviourOptions opts;
    const bool cov_enable;
    @disable this();
    this(
            ref Schedule schedule,
            const(string[]) stages,
            const uint jobs,
            const BehaviourOptions opts,
            const bool cov_enable,
            ScheduleTrace report = null) pure nothrow
    in (jobs > 0)
    in (stages.length > 0)
    do {
        this.schedule = schedule;
        this.stages = stages;
        this.jobs = jobs;
        this.opts = opts;
        this.report = report;
        this.cov_enable = cov_enable;
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

    void progress(Args...)(const string fmt, Args args) @trusted {
        if (!opts.silent) {
            import tagion.utils.Term;

            writef(CLEAREOL ~ fmt ~ "\r", args);
            stdout.flush;
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
        alias Stage = Tuple!(RunUnit, "unit", string, "name", string, "stage");
        auto schedule_list = stages
            .map!(stage => schedule.units
                    .byKeyValue
                    .filter!(unit => unit.value.stages.canFind(stage))
                    .map!(unit => Stage(unit.value, unit.key, stage)))
            .joiner;
        if (schedule_list.empty) {
            writefln("None of the stage %s available", stages);
            writefln("Available stages %s", schedule.stages);
            return 1;
        }
        auto runners = new Runner[jobs];

        void batch(
                const ptrdiff_t job_index,
                const SysTime time,
                const(char[][]) cmd,
                const(string) log_filename,
                const(string[string]) env) {
            static uint job_count;
            scope (exit) {
                job_count++;
            }
            if (dry_switch) {
                const line_length = cmd.map!(c => c.length).sum;
                writefln("%-(%s%)", '#'.repeat(max(min(line_length, 30), 80)));
                writefln("%d] %-(%s %)", job_count, cmd);
                writefln("Log file %s", log_filename);
                writefln("Unit = %s", schedule_list.front.unit.toJSON.toPrettyString);
            }
            else {
                auto fout = File(log_filename, "w");
                auto _stdin = (() @trusted => stdin)();

                Pid pid;
                if (!cov_enable) {
                    pid = spawnProcess(cmd, _stdin, fout, fout, env);
                }
                else {
                    const cov_path = buildPath(environment.get(BDD_LOG, "logs"), "cov").relativePath;
                    const cov_flags = format(" --DRT-covopt=\"dstpath:%s merge:1\"", cov_path);
                    mkdirRecurse(cov_path);
                    // For some reason the drt cov flags don't work when spawned as a process 
                    // so we just run it in a shell
                    pid = spawnShell(cmd.join(" ") ~ cov_flags, _stdin, fout, fout, env);
                }

                writefln("%d] %-(%s %) # pid=%d", job_index, cmd,
                        pid.processID);
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
            showEnv(env, schedule_list.front.unit);
        }

        void teminate(ref Runner runner) {
            this.stopped(runner);
            runner = Runner.init;
        }

        uint count;
        static immutable progress_meter = [
            "|",
            "/",
            "-",
            "\\",
        ];

        while (!schedule_list.empty || runners.any!(r => r.pid !is r.pid.init)) {
            if (!schedule_list.empty) {
                const job_index = runners.countUntil!(r => r.pid is r.pid.init);
                if (job_index >= 0) {
                    try {
                        auto time = Clock.currTime;
                        auto env = environment.toAA;
                        schedule_list.front.unit.envs.byKeyValue
                            .each!(e => env[e.key] = envExpand(e.value, env));
                        const cmd = args ~
                            schedule_list.front.name ~
                            schedule_list.front.unit.args
                                .map!(arg => envExpand(arg, env))
                                .array;
                        setEnv(env, schedule_list.front.stage);
                        //showEnv(env); //writefln("ENV %s ", env);
                        check((BDD_RESULTS in env) !is null,
                                format("Environment variable %s or %s must be defined", BDD_RESULTS, COLLIDER_ROOT));
                        const log_filename = buildNormalizedPath(env[BDD_RESULTS],
                                schedule_list.front.name).setExtension("log");
                        batch(job_index, time, cmd, log_filename, env);
                        schedule_list.popFront;
                    }
                    catch (Exception e) {
                        writefln("Error %s", e.msg);
                        runners[job_index].fout.writeln("Error: %s", e.msg);
                        runners[job_index].fout.close;
                        kill(runners[job_index].pid);
                        runners[job_index] = Runner.init;
                    }
                }
            }

            runners
                .filter!(r => r.pid !is r.pid.init)
                .filter!(r => tryWait(r.pid).terminated)
                .each!((ref r) => teminate(r));
            progress("%s Running jobs %s",
                    progress_meter[count % progress_meter.length],
                    runners
                    .enumerate
                    .filter!(r => r.value.pid !is r.value.pid.init)
                    .map!(r => r.index),
            );
            count++;
            sleep(100.msecs);
        }
        progress("Done");
        return 0;
    }
}
