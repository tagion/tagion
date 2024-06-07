/** 
 * Provides simple getters for XDG base directories and FHS
 * Appropriate directories a chosen based on whether the program is run as root or not.
 * All directories are namespaced with tagion.
**/
module tagion.basic.dir;

@safe:

import core.sys.posix.unistd;

import std.process : environment;
import std.path;
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

    /// the home directory
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
        }
    }

    private string _data;
    /// Site specific data
    string data() {
        set_val(_data, root_dir("srv"), xdg_dir("XDG_DATA_HOME", ".local/share"));
        return _data;
    }

    private string _config;
    /// static program config files
    string config() {
        set_val(_config, root_dir("etc"), xdg_dir("XDG_CONFIG_HOME", ".config/"));
        return _config;
    }

    private string _cache;
    /// Cached data, data that is a result expensive computation or I/O. 
    /// The cached files can be deleted without loss of data. 
    string cache() {
        set_val(_cache, root_dir("/var/cache"), xdg_dir("XDG_CACHE_HOME", ".cache"));
        return _cache;
    }

    private string _run;
    /// This directory contains system information data describing the system since it was booted
    string run() {
        set_val(_run,
                root_dir("run"),
                environment.get("XDG_RUNTIME_DIR", buildPath("/run", "user", euid.to!string, program_name)
        ));
        return _run;
    }

    private string _log;
    /// Log files
    string log() {
        set_val(_log, root_dir("/var/log"), xdg_dir("XDG_STATE_HOME", ".local/state"));
        return _log;
    }
}

static Dir base_dir;
static this() {
    base_dir = Dir(geteuid);
}

unittest {
    auto my_dirs = Dir(1000); // A normal user
    enum homeless = "/home/less/";
    environment["HOME"] = homeless;
    environment["XDG_CACHE_HOME"] = homeless ~ ".cache";
    assert(my_dirs.cache == "/home/less/.cache/tagion", my_dirs.cache);

    environment.remove("XDG_RUNTIME_DIR");
    assert(my_dirs.run == "/run/user/1000/tagion", my_dirs.run);

    environment.remove("XDG_DATA_HOME");
    assert(my_dirs.data == buildPath(homeless ~ ".local/share/tagion"), my_dirs.data);

    auto root_dirs = Dir(0);
    assert(root_dirs.run == "/run/tagion", root_dirs.run);
}
