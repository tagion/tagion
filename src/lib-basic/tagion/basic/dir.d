module tagion.basic.dir;

@safe:
nothrow:

import core.sys.posix.unistd;

import std.process : environment;
import std.path;
import std.file : mkdirRecurse;
import std.conv;

import tagion.basic.basic : isinit;

struct Dir {
    enum program_name = "tagion";

    /// The effective user permissions, so running with sudo or doas counts as well
    const bool isRoot;
    const uint euid;
    this(uint _euid) nothrow {
        euid = _euid;
        isRoot = (_euid == 0);
    }

    string _home;
    string home() {
        if (_home.isinit) {
            _home = environment.get("HOME");
            // '/' is set if user is 'nobody'
            assert(_home !is string.init && _home != "/", "This system is not for homeless users");
        }
        return _home;
    }

    private string xdg_dir(const(string) XDG_SPEC, lazy string fallback)
    out (dir; dir.isValidPath)
    out (dir; dir.isRooted) {
        const dir = environment.get(XDG_SPEC, buildPath(home, fallback));
        return buildPath(dir, program_name);
    }

    private string root_dir(lazy string name)
    out (dir; dir.isValidPath)
    out (dir; dir.isRooted) {
        return buildPath("/", name, program_name);
    }

    private void set_val(ref string var, lazy string root_val, lazy string user_val) {
        if (var.isinit) {
            if (isRoot) {
                var = root_val;
            }
            else {
                var = user_val;
            }
            // mkdirRecurse(var);
        }
    }

    private string _data;
    string data() {
        set_val(_data, root_dir("srv"), xdg_dir("XDG_DATA_HOME", ".local/share"));
        return _data;
    }

    private string _config;
    string config() {
        set_val(_config, root_dir("etc"), xdg_dir("XDG_DATA_HOME", ".local/share"));
        return _config;
    }

    private string _cache;
    string cache() {
        set_val(_cache, root_dir(buildPath("var", "cache")), xdg_dir("XDG_CACHE_HOME", ".local/cache"));
        return _cache;
    }

    private string _run;
    string run() {
        set_val(_run,
                root_dir("run"),
                xdg_dir("XDG_RUNTIME_DIR", buildPath("run", euid.to!string, program_name)
        ));
        return _run;
    }

    private string _log;
    string log() {
        set_val(_log, root_dir(buildPath("var", "log")), xdg_dir("XDG_STATE_HOME", ".local/state"));
        return _log;
    }
}

static Dir base_dir;
static this() {
    base_dir = Dir(geteuid);
}
