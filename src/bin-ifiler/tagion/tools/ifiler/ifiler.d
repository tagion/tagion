module tagion.tools.ifiler.ifiler;
import std.process;

import tagion.tools.Basic;
mixin Main!_main;

version(linux) {
import std.stdio: writeln, writefln;
import core.stdc.stdio;
import core.stdc.stdlib;
import std.algorithm;
import std.stdio;
import tools = tagion.tools.toolsexception;
import std.string : representation;
import std.getopt;
import tagion.tools.revision;
import std.format;
import std.array;

import core.sys.linux.sys.inotify;
import core.sys.posix.unistd;

struct Inotify {
    protected {
        ubyte[] buffer;
        int fd;
        int wd;
        inotify_event* event;
        bool _empty;
    }
    enum EVENT_BUF_LEN = 0x100 * (inotify_event.sizeof + size_t.sizeof);
    this(string file_name, uint mask, const size_t buf_size = EVENT_BUF_LEN) nothrow @trusted {
        buffer.length = EVENT_BUF_LEN;
        file_name ~= '\0';
        fd = inotify_init();
        wd = inotify_add_watch(fd, &file_name[0], mask);
        event = cast(inotify_event*)&buffer[0];
    }

    const(inotify_event*) wait() nothrow {
        const length = read(fd, &buffer[0], cast(int) buffer.length);
        /*checking for error*/
        if (length < 0) {
            enum error_text = "# inotify error #".representation;
            event.len = cast(uint) error_text.length;
            auto error = buffer[inotify_event.sizeof .. $];
            error[0 .. error_text.length] = error_text;
        }
        return event;
    }

    void close() nothrow @nogc {
        inotify_rm_watch(fd, wd);

        

        .close(fd);
    }

    const pure {
        const(char[]) name() const pure @trusted @nogc {

            const result = (cast(char*) event.name.ptr)[0 .. event.len];
            const len = result.countUntil(0);
            return result[0 .. len];
        }
    }
}

import tagion.dart.BlockFile : truncate;

void icopy(string src, string dest, const size_t block_size) {
    import std.file;
    import std.path;

    tools.check(src.exists, format("%s should exist", src));
    tools.check(src.isFile, format("%s should be a file", src));
    tools.check(dest.extension.empty && dest.exists && dest.isDir,
            format("%s path does not exists", dest));
    if (dest.exists && dest.isDir) {
        dest = buildPath(dest, src.baseName);
    }
    File fin, fout;
    scope (exit) {
        fout.flush;
        fout.close;
        fin.close;
    }
    enum one_MiB = 1 << 20;

    size_t block_count;
    ubyte[] fin_buf;
    ubyte[] fout_buf;
    fin_buf.length = fout_buf.length = block_size;
    fin = File(src, "r");
    if (dest.exists) {

        fout = File(dest, "r+");
        while (!fin.eof) {
            verbose("Verify block %d %f.6MiB", block_count, double(fin.tell) / one_MiB);
            const fin_tell = fin.tell;
            const fin_current = fin.rawRead(fin_buf);
            const fout_tell = fout.tell;
            const fout_current = fout.rawRead(fout_buf);
            if (fin_current != fout_current) {
                fin.seek(fin_tell);
                fout.seek(fin_tell);
                break;
            }
            block_count++;
        }
    }
    else {
        fout = File(dest, "w");
    }
    while (!fin.eof) {
        verbose("Update block %d %f.6MiB", block_count, double(fin.tell) / one_MiB);
        const fin_tell = fin.tell;
        const fout_tell = fout.tell;
        const fin_current = fin.rawRead(fin_buf);
        fout.rawWrite(fin_current);
        block_count++;
    }
    fout.flush;
    auto inotify = Inotify(src, IN_CLOSE_WRITE | IN_MODIFY);
    for (;;) {
        const event = inotify.wait;
        const fin_tell = fin.tell;
        fin.reopen(null, "r");
        fin.seek(fin_tell);
        verbose("Reopen %s %d", src, fin.tell);
        while (!fin.eof) {
            verbose("Copy block %d %f.6MiB", block_count, double(fin.tell) / one_MiB);
            const fout_tell = fout.tell;
            const fin_current = fin.rawRead(fin_buf);
            fout.rawWrite(fin_current);
            fout.flush;
            block_count++;
        }
        if ((event.mask & IN_MODIFY) == 0) {
            verbose("CLosed");
            break;
        }
    }

}

int _main(string[] args) {
    immutable program = args[0];
    bool version_switch;
    size_t block_size = 0x400;
    //    auto logo = import("logo.txt");
    GetoptResult main_args;
    try {
        main_args = getopt(args,
                std.getopt.config.caseSensitive,
                std.getopt.config.bundling,
                "version", "display the version", &version_switch,
                "v|verbose", "Prints more debug information", &__verbose_switch,
                "b|block", "Set the block size (Default %s)", &block_size,
        );
        if (version_switch) {
            revision_text.writeln;
            return 0;
        }

        if (main_args.helpWanted) {
            //            writeln(logo);
            defaultGetoptPrinter(
                    [
                    "Documentation: https://docs.tagion.org/",
                    "",
                    "Usage:",
                    format("%s [<option>...] <src-file> <dst-file> ", program),
                    "",

                    "<option>:",

                    ].join("\n"),
                    main_args.options);
            return 0;
        }
        tools.check(args.length == 3, format("%s should have two arguments", program));
        icopy(args[1], args[2], block_size);
    }
    catch (Exception e) {
        error(e);
        return 1;
    }
    return 0;
}
}
else {
int _main(string[] args) {
    import std.stdio;
    stderr.writefln("%s Not supported on this platform", args[0]);
    return -1;
}
}
