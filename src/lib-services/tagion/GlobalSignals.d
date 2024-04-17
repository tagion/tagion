module tagion.GlobalSignals;

import std.compiler;

import core.stdc.signal;
import core.stdc.stdio;
import core.stdc.stdlib : exit, system;
import core.stdc.string : strlen;
import core.sync.event;
import tagion.basic.Version;
import tagion.logger.Logger;

//import core.internal.execinfo;
// The declaration of the backtrace function in the execinfo.d is not declared @nogc
// so they are declared here with @nogc because signal needs a @nogc function
static if (ver.Posix && not_unittest) {
    extern (C) {
        nothrow @nogc {
            int backtrace(void** buffer, int size);
            char** backtrace_symbols(const(void*)* buffer, int size);
            void backtrace_symbols_fd(const(void*)* buffer, int size, int fd);
        }
    }
}

__gshared Event stopsignal;

// Event.set renamed to setIfInitialized in 2.108
static if (version_minor < 108) {
    void setIfInitialized(ref Event e) {
        e.set();
    }
}

static shared bool abort = false;

private shared bool fault;
// static if (ver.Posix && not_unittest) {
//     private static extern (C) void shutdown(int sig) @nogc nothrow {
//         if (!fault) {
//             if (sig is SIGINT) {
//                 printf("SIGINT=%d SIGTERM=%d\n", SIGINT, SIGTERM);
//                 printf("Shutdown sig %d about=%d\n", sig, abort);
//                 if (abort) {
//                     exit(0);
//                 }
//                 printf("Program will now abort\n");
//                 abort = true;
//             }
//             else {
//                 printf("Ignored sig %d about=%d\n", sig, abort);
//             }
//         }
//     }
// }

//shared char[] call_stack_file;
enum CALL_STACK_FILE_SIZE = 0x100;
version (ONETOOL) {
    import tagion.tools.OneMain : main_name;

}
else {
    private shared static string main_name;
    shared static this() {
        import std.file : thisExePath;

        main_name = thisExePath.idup;

    }
}
alias CallStackFile = char[CALL_STACK_FILE_SIZE + 1];
private const(CallStackFile) call_stack_file() nothrow @nogc {
    CallStackFile filename;
    filename[] = '\0';
    size_t pos; //=main_name.length;
    filename[0 .. main_name.length] = main_name;
    pos += main_name.length;
    filename[pos] = '.';
    pos++;
    filename[pos .. pos + backtrace_ext.length] = backtrace_ext;
    return filename;
}

static if (ver.Posix && not_unittest) {
    import core.sys.posix.signal;
    import core.sys.posix.unistd : STDERR_FILENO;

    enum BACKTRACE_SIZE = 0x80; /// Just big enough to hold the call stack
    static extern (C) void segment_fault(int sig, siginfo_t* ctx, void* ptr) @nogc nothrow {
        if (fault) {
            return;
        }
        abort = true;
        fault = true;
        log.silent = true;

        fprintf(stderr, "Fatal error\n");
        void*[BACKTRACE_SIZE] callstack;
        int size;

        fprintf(stderr, "Got signal %d, faulty address is %p, from pid %d\n",
                sig, ctx.si_addr, ctx.si_pid);

        size = backtrace(callstack.ptr, BACKTRACE_SIZE);
        backtrace_symbols_fd(callstack.ptr, size, STDERR_FILENO);

        scope char** messages;
        messages = backtrace_symbols(callstack.ptr, size);
        const filename = call_stack_file;
        printf("filename %s\n", &filename[0]);
        {
            auto fp = fopen(&filename[0], "w");
            scope (exit) {
                fclose(fp);
            }
            foreach (i, msg; messages[0 .. size]) {
                fprintf(fp, "%s\n", msg);
            }
        }
        fprintf(stderr, "\nSEGMENT FAULT\n");
        fprintf(stderr, "Backtrack file has been written to %.*s\n",
                cast(int) call_stack_file.length, call_stack_file.ptr);
        fprintf(stderr, "Use the callstack to list the backtrace\n");
        exit(-1);
    }
}

import core.stdc.signal;

enum SIGPIPE = 13; // SIGPIPE is not defined in the module core.stdc.signal
static extern (C) void ignore(int sig) @nogc nothrow {
    printf("Ignore sig %d\n", sig);
}

enum backtrace_ext = "callstack";
static if (not_unittest) {
    shared static this() {
        import std.path;

        stopsignal.initialize(true, false);

        //call_stack_file = setExtension(thisExePath, backtrace_ext) ~ '\0';

        signal(SIGPIPE, &ignore);
        version (Posix) {
            import core.sys.posix.signal;

            //        import core.runtime;

            sigaction_t sa = void;
            (cast(byte*)&sa)[0 .. sa.sizeof] = 0;
            /// sigfillset( &action.sa_mask ); // block other signals

            sa.sa_sigaction = &segment_fault;
            sigemptyset(&sa.sa_mask);
            sa.sa_flags = SA_RESTART;
            sigaction(SIGSEGV, &sa, null);
        }

        // signal(SIGINT, &shutdown);
        // signal(SIGTERM, &shutdown);
    }
}
