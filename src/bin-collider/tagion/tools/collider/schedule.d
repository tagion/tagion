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
import tagion.tools.Basic : dry_switch, verbose_switch, error;
import tagion.tools.collider.BehaviourOptions;
import tagion.tools.collider.trace : ScheduleTrace;
import tagion.tools.toolsexception;
import tagion.json.JSONRecord;
import tagion.utils.envexpand;
import tagion.basic.basic : isinit;

@safe:

struct Depend {
    @optional string[] started;
    @optional string[] ended;
    mixin JSONRecord;
}

struct RunState {
    @optional string[string] envs;
    @optional string[] args;
    @optional double timeout;
    mixin JSONRecord;
}

struct RunUnit {
    string[] stages;
    @optional string[string] envs;
    @optional string[] args;
    @optional double timeout;
    @optional Depend depend;
    @optional bool background;
    @optional RunState[string] extend;
    mixin JSONRecord;
}

struct Schedule {
    RunUnit[string] units;
    mixin JSONRecord;
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

struct Stage {
    RunUnit unit;
    string name;
    string stage;
    bool done;
}

struct Runner {
    Pid pid;
    File fout;
    RunUnit unit;
    string name;
    string stage;
    SysTime time;
    long jobid;
}

auto cycle(R)(R r) if (isInputRange!R && is(ElementType!R == Stage*)) {
    static struct Range {
        Stage*[] stages;
        size_t index;
        this(R r) {
            this.stages= r.array;
        }

        bool empty() pure nothrow {
            return front is null;
        }

        Stage* front() {
            if ((index < stages.length) && stages[index].done) {
                popFront;
            }
            if (index >= stages.length) {//stages[index].done) {
                return null;
            }
            return stages[index];
        }

        void popFront() {
            index++; 
            if (index >= stages.length) {
                index = 0;
            }
            while ((index < stages.length) && stages[index].done) {
                    index++;
            }
        }
    }

    return Range(r);
}

unittest {
    auto stages = [
        new Stage(RunUnit.init, "A"),
        new Stage(RunUnit.init, "B"),
        new Stage(RunUnit.init, "C"),
        new Stage(RunUnit.init, "D")
    ];

    auto c = cycle(stages);
    const repeat_task=2*stages.length;
    assert(c.take(repeat_task).walkLength == repeat_task);
        c.take(repeat_task).filter!(s => s.name == "C").each!(s => s.done=true);
    assert(equal(c.take(repeat_task).map!(s => s.name).array.sort.uniq, ["A", "B","D"]));
        c.take(repeat_task).filter!(s => s.name == "A").each!(s => s.done=true);
    assert(equal(c.take(repeat_task).map!(s => s.name).array.sort.uniq, ["B","D"]));
        c.take(repeat_task).filter!(s => s.name == "B" ).each!(s => s.done=true);
    assert(!c.empty); 
    c.front.done=true;
    assert(c.empty); 
}

enum TEST_STAGE = "TEST_STAGE";
enum COLLIDER_ROOT = "COLLIDER_ROOT";
enum BDD_LOG = "BDD_LOG";
enum BDD_RESULTS = "BDD_RESULTS";
enum UNSHARE_NET = "UNSHARE_NET";

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

            

                .kill(pid); //.ifThrown!ProcessException;
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
        //alias Stage = Tuple!(RunUnit, "unit", string, "name", string, "stage", bool, "done");
        auto schedule_list = stages
            .map!(stage => schedule.units
                    .byKeyValue
                    .filter!(unit => unit.value.stages.canFind(stage))
                    .map!(unit => new Stage(unit.value, unit.key, stage)))
            .joiner
            .array;

        if (schedule_list.empty) {
            error("None of the stage %s available", stages);
            error("Available stages %s", schedule.stages);
            return 1;
        }
        auto runners = new Runner[jobs];
        Runner[] background;
        auto schedule_queue = schedule_list.filter!(r => !r.done).cycle;
        void batch(
                const ptrdiff_t job_index,
                const SysTime time,
                const(char[][]) cmd,
        const(string) log_filename,
        const(string[string]) env) {
            static uint job_count;
            scope (exit) {
                showEnv(env, schedule_queue.front.unit);
                schedule_queue.front.done = true;
                job_count++;
            }
            if (dry_switch) {
                const line_length = cmd.map!(c => c.length).sum;
                writefln("%-(%s%)", '#'.repeat(max(min(line_length, 30), 80)));
                writefln("%d] %-(%s %)", job_count, cmd);
                writefln("Log file %s", log_filename);
                writefln("Unit = %s", schedule_queue.front.unit.toJSON.toPrettyString);
                return;
            }
            auto fout = File(log_filename, "w");
            auto _stdin = (() @trusted => stdin)();

            Pid pid;
            import std.conv;

            string cov_flags;
            if (cov_enable) {
                const cov_path
                    = buildPath(environment.get(BDD_LOG, "logs"), "cov", job_index.to!string).relativePath;
                cov_flags = format(` --DRT-covopt="dstpath:%s merge:1"`, cov_path);
                mkdirRecurse(cov_path);
            }
            // For some reason the drt cov flags don't work when spawned as a process 
            // so we just run it in a shell
            pid = spawnShell(cmd.join(" ") ~ cov_flags, _stdin, fout, fout, env);
            auto runner = Runner(
                    pid,
                    fout,
                    schedule_queue.front.unit,
                    schedule_queue.front.name,
                    schedule_queue.front.stage,
                    time,
                    job_index
            );

            writefln("%d] %-(%s %) # pid=%d", job_index, cmd,
                    pid.processID);
            runners[job_index] = runner;
        }

        void terminate(ref Runner runner) {
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

        while (!schedule_queue.empty || runners.any!(r => r.pid !is r.pid.init)) {
            if (!schedule_queue.empty) {
                const job_index = runners.countUntil!(r => r.pid is r.pid.init);
                if (job_index >= 0) {
                    scope (exit) {
                        runners[job_index].fout.close;
                    }
                    try {
                        auto time = Clock.currTime;
                        auto env = environment.toAA;
                        schedule_queue.front.unit.envs.byKeyValue
                            .each!(e => env[e.key] = envExpand(e.value, env));
                        string[] unit_args =
                            schedule_queue.front.unit.args.dup;
                        const extend = schedule_queue.front.unit.extend
                            .get(schedule_queue.front.stage, RunState.init);
                        if (!extend.isinit) {
                            if (!extend.args.empty) {
                                unit_args = extend.args.dup;
                            }
                            extend.envs.byKeyValue
                                .each!(e => env[e.key] = envExpand(e.value, env));
                        }
                        const(char[])[] cmd = args ~
                            schedule_queue.front.name ~
                            unit_args
                                .map!(arg => envExpand(arg, env))
                                .array;
                        setEnv(env, schedule_queue.front.stage);
                        check((BDD_RESULTS in env) !is null,
                                format("Environment variable %s or %s must be defined", BDD_RESULTS, COLLIDER_ROOT));

                        const unshare_net = (UNSHARE_NET in env) !is null;
                        if (unshare_net) {
                            cmd = ["bwrap", "--unshare-net", "--dev-bind", "/", "/"] ~ cmd;
                        }

                        const log_filename = buildNormalizedPath(env[BDD_RESULTS],
                        schedule_queue.front.name).setExtension("log");
                        batch(job_index, time, cmd, log_filename, env);
                        writefln("name %s done=%s", schedule_queue.front.name, schedule_queue.front.done);
                        schedule_queue.popFront;
                    }
                    catch (Exception e) {
                        error(e);
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
                .each!((ref r) => terminate(r));
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
