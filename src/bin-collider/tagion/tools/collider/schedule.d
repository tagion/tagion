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
import std.exception : assumeWontThrow;
import std.typecons : Tuple, tuple;
import tagion.hibon.HiBONJSON;
import tagion.hibon.HiBONRecord;
import tagion.tools.Basic : dry_switch, verbose_switch, error;
import tagion.tools.collider.BehaviourOptions;
import tagion.tools.collider.trace : ScheduleTrace;
import tagion.tools.toolsexception;
import tagion.json.JSONRecord;
import tagion.utils.envexpand;
import tagion.basic.basic : isinit;
import tagion.basic.Types : FileExtension;
import tagion.hibon.HiBONFile : fread, fwrite;

import tagion.utils.Term;

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

enum Lap {
    none,
    started,
    paused,
    timedout,
    failed,
    stopped,
}

@recordType("ColliderState")
struct State {
    string name;
    string stage;
    string filename;
    Lap lap;
    mixin HiBONRecord;
}

struct Job {
    RunUnit unit;
    File fout;
    protected State state;
    //mixin HiBONRecord;
    version (none) protected {
        @label("log") string _log_filename;
        @label("lap") Lap _lap;
    }
    this(ref RunUnit unit, string name, string stage) pure nothrow {
        this.unit = unit;
        this.state.name = name;
        this.state.stage = stage;
    }

    void lap(Lap lap_level)
    in (checkLap(lap_level),
        assumeWontThrow(format("Can't change lap from %s to %s", state.lap, lap_level)))
    do {
        state.lap = lap_level;
        state.filename.setExtension(state.stage ~ FileExtension.hibon).fwrite(state);
    }

    pure nothrow {
        string name() const @nogc {
            return state.name;
        }

        string stage() const @nogc {
            return state.stage;
        }

        void log_filename(string filename) @nogc
        in (state.filename is null, "Log filename has already been set")
        do {
            state.filename = filename;
        }

        bool checkLap(const Lap lap_level) const @nogc {
            final switch (state.lap) {
            case Lap.none:
                return lap_level is Lap.started;
            case Lap.started:
                return lap_level > state.lap;
            case Lap.paused:
                return lap_level >= state.lap;
            case Lap.timedout:
            case Lap.failed:
            case Lap.stopped:
                return (state.lap > Lap.none) && (state.lap <= Lap.paused);
            }
        }

        string log_filename() const @nogc {
            return state.filename;
        }

        Lap lap() const @nogc {
            return state.lap;
        }

        bool hasEnded() const @nogc {
            return lap >= Lap.timedout;
        }

        bool isActivated() const @nogc {
            return lap !is Lap.none;
        }

        bool notActiveBackground() const @nogc {
            return (lap is Lap.none) && unit.background;
        }
    }
}

struct Runner {
    Pid pid;
    Job* job;
    SysTime time;
    long jobid;
    void close() {
        if (job) {
            job.fout.close;
        }
    }

    protected void _kill() nothrow @trusted {
        if (pid !is pid.init) {
            try {

                

                    .kill(pid); //.ifThrown!ProcessException;
            }
            catch (Exception e) {
                assumeWontThrow(job.fout.writefln(e.toString));
            }
        }

    }

    void fail(string msg) nothrow {
        assumeWontThrow({ job.fout.writefln("Error: %s", msg); _kill(); job.lap = Lap.failed; job.fout.close; }());
    }

    void stop(string msg) nothrow {
        assumeWontThrow({ job.fout.writeln(msg); _kill(); job.lap = Lap.stopped; job.fout.close; }());
    }
}

struct JobCycle {
    Job*[] jobs;
    size_t index;
    this(Job*[] r) pure nothrow {
        jobs = r;
    }

    bool empty() pure nothrow {
        return front is null;
    }

    Job* front() pure nothrow {
        if ((index < jobs.length) && jobs[index].isActivated) {
            popFront;
        }
        if (index >= jobs.length) { //jobs[index].done) {
            return null;
        }
        return jobs[index];
    }

    void popFront() pure nothrow {
        index++;
        if (index >= jobs.length) {
            index = 0;
        }
        while ((index < jobs.length) && jobs[index].isActivated) {
            index++;
        }
    }
}

unittest {
    import std.algorithm : filter;

    Job*[] jobs;
    {
        auto c = JobCycle(jobs);
        assert(c.empty);
        c.popFront;
        assert(c.empty);

    }
    RunUnit unit;
    {
        jobs = [
            new Job(unit, "A", null),
        ];
        auto c = JobCycle(jobs);
        assert(!c.empty);

        jobs[0].lap = Lap.started;
        assert(c.empty);
        c.popFront;
        assert(c.empty);
    }
    {
        jobs = [
            new Job(unit, "A", null),
            new Job(unit, "B", null),
            new Job(unit, "C", null),
            new Job(unit, "D", null)
        ];
        auto c = JobCycle(jobs);
        const repeat_task = 2 * jobs.length;
        assert(c.take(repeat_task).walkLength == repeat_task);
        c.take(repeat_task).filter!(s => s.name == "C")
            .each!(s => s.lap = Lap.started);
        assert(equal(c.take(repeat_task).map!(s => s.name).array.sort.uniq, ["A", "B", "D"]));
        c.take(repeat_task).filter!(s => s.name == "A")
            .each!(s => s.lap = Lap.started);
        assert(equal(c.take(repeat_task).map!(s => s.name).array.sort.uniq, ["B", "D"]));
        c.take(repeat_task).filter!(s => s.name == "B")
            .each!(s => s.lap = Lap.started);
        assert(!c.empty);
        auto last_job = c.front;
        last_job.lap = Lap.started;
        last_job.lap = Lap.paused;
        assert(c.empty);
        assert(c.front is null);
    }
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
        import std.algorithm : filter;

        auto job_list = stages
            .map!(stage => schedule.units
                    .byKeyValue
                    .filter!(unit => unit.value.stages.canFind(stage))
                    .map!(unit => new Job(unit.value, unit.key, stage)))
            .joiner
            .array;

        if (job_list.empty) {
            error("None of the stage %s available", stages);
            error("Available stages %s", schedule.stages);
            return 1;
        }
        auto runners = new Runner[jobs];
        Runner[] background_runners;
        void batch(
                Job* stage,
                const ptrdiff_t job_index,
                const SysTime time,
                const(char[][]) cmd,
        const(string[string]) env) {
            static uint job_count;
            scope (exit) {
                showEnv(env, stage.unit);
                job_count++;
            }
            if (dry_switch) {
                const line_length = cmd.map!(c => c.length).sum;
                writefln("%-(%s%)", '#'.repeat(max(min(line_length, 30), 80)));
                writefln("%d] %-(%s %)", job_count, cmd);
                writefln("Log file %s", stage.log_filename);
                writefln("Unit = %s", stage.unit.toJSON.toPrettyString);
                return;
            }
            stage.fout = File(stage.log_filename, "w");
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
            pid = spawnShell(cmd.join(" ") ~ cov_flags, _stdin, stage.fout, stage.fout, env);
            stage.lap = Lap.started;
            auto runner = Runner(
                    pid, //fout,
                    stage,
                    time,
                    job_index
            );

            if (stage.notActiveBackground) {
                writefln("%s%d] %-(%s %) # background_runners pid=%d%s",
                        BLUE, background_runners.length, cmd,
                        pid.processID, RESET);
                background_runners ~= runner;
            }
            else {
                writefln("%d] %-(%s %) # pid=%d", job_index, cmd,
                        pid.processID);
                if (runners[job_index]!is Runner.init) {
                    runners[job_index].close;
                }
                runners[job_index] = runner;
            }
        }

        void terminate(ref Runner runner) {
            this.stopped(runner);
            runner.job.lap = Lap.stopped;
            runner = Runner.init;
        }

        uint tick;
        static immutable progress_meter = [
            "🕐",
            "🕑",
            "🕒",
            "🕓",
            "🕔",
            "🕕",
            "🕖",
            "🕗",
            "🕘",
            "🕙",
            "🕚",
            "🕛",
        ];

        auto job_queue = JobCycle(job_list);
        while (!job_queue.empty || runners.any!(r => r.pid !is r.pid.init)) {
            if (!job_queue.empty) {
                const job_index = runners.countUntil!(r => r.pid is r.pid.init);
                if ((job_index >= 0) || job_queue.front.notActiveBackground) {
                    try {
                        auto time = Clock.currTime;
                        auto env = environment.toAA;
                        job_queue.front.unit.envs.byKeyValue
                            .each!(e => env[e.key] = envExpand(e.value, env));
                        string[] unit_args =
                            job_queue.front.unit.args.dup;
                        const extend = job_queue.front.unit.extend
                            .get(job_queue.front.stage, RunState.init);
                        if (!extend.isinit) {
                            if (!extend.args.empty) {
                                unit_args = extend.args.dup;
                            }
                            extend.envs.byKeyValue
                                .each!(e => env[e.key] = envExpand(e.value, env));
                        }
                        const(char[])[] cmd = args ~
                            job_queue.front.name ~
                            unit_args
                                .map!(arg => envExpand(arg, env))
                                .array;
                        setEnv(env, job_queue.front.stage);
                        check((BDD_RESULTS in env) !is null,
                                format("Environment variable %s or %s must be defined", BDD_RESULTS, COLLIDER_ROOT));

                        const unshare_net = (UNSHARE_NET in env) !is null;
                        if (unshare_net) {
                            cmd = ["bwrap", "--unshare-net", "--dev-bind", "/", "/"] ~ cmd;
                        }

                        job_queue.front.log_filename = buildNormalizedPath(env[BDD_RESULTS],
                        job_queue.front.name).setExtension("log");
                        batch(job_queue.front, job_index, time, cmd, env);
                        job_queue.popFront;
                    }
                    catch (Exception e) {
                        error(e);
                        runners[job_index].fail(e.msg);
                        runners[job_index] = Runner.init;
                    }
                }
            }

            runners
                .filter!(r => r.pid !is r.pid.init)
                .filter!(r => tryWait(r.pid).terminated)
                .each!((ref r) => terminate(r));
            progress("%-(%s %) Running jobs %s",
                    runners
                    .filter!(r => r.pid !is r.pid.init)
                    .count
                    .iota
                    .map!(i => progress_meter[(tick + i) % progress_meter.length]),
            runners
                .enumerate
                .filter!(r => r.value.pid !is r.value.pid.init)
                .map!(r => r.index),
            );
            tick++;
            sleep(100.msecs);
        }
        foreach (r; background_runners.filter!(j => j.pid !is j.pid.init)) {
            r.stop("Background");
            terminate(r);
        }
        progress("Done");
        return 0;
    }
}
