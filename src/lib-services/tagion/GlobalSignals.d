module tagion.GlobalSignals;

import core.stdc.signal;
import core.stdc.stdio;
import core.stdc.stdlib : exit, system;
import core.stdc.string : strlen;
import tagion.basic.Logger;

//import core.internal.execinfo;
// The declaration of the backtrace function in the execinfo.d is not declared @nogc
// so they are declared here with @nogc because signal needs a @nogc function
version (linux) {
    extern (C) {
        nothrow @nogc {
            int backtrace(void** buffer, int size);
            char** backtrace_symbols(const(void*)* buffer, int size);
            void backtrace_symbols_fd(const(void*)* buffer, int size, int fd);
        }
    }
}

shared bool abort = false;
private shared bool fault;
static extern (C) void shutdown(int sig) @nogc nothrow {
    if (!fault) {
        printf("Shutdown sig %d about=%d\n", sig, abort);
        if (sig is SIGINT || sig is SIGTERM) {
            if (abort) {
                exit(0);
            }
            abort = true;
        }
    }
}

shared string call_stack_file;

version (linux) {
    import core.sys.posix.unistd : STDERR_FILENO;
    import core.sys.posix.signal;

    enum BACKTRACE_SIZE = 0x80; /// Just big enough to hold the call stack
    static extern (C) void segment_fault(int sig, siginfo_t* ctx, void* ptr) @nogc nothrow {
        if (fault) {
            return;
        }
        abort = true;
        fault = true;
        log.silent = true;

        fprintf(stderr, "Segment Fault\n");
        void*[BACKTRACE_SIZE] callstack;
        int size;

        if (sig == SIGSEGV) {
            fprintf(stderr, "Got signal %d, faulty address is %p, from pid %d\n",
                    sig, ctx.si_addr, ctx.si_pid);
        }
        else {
            fprintf(stderr, "Got signal %d\n", sig);
        }

        size = backtrace(callstack.ptr, BACKTRACE_SIZE);
        backtrace_symbols_fd(callstack.ptr, size, STDERR_FILENO);

        scope char** messages;
        messages = backtrace_symbols(callstack.ptr, size);

        {
            auto fp = fopen(call_stack_file.ptr, "w");
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
shared static this() {
    import std.path;
    import std.file : thisExePath;

    call_stack_file = setExtension(thisExePath, backtrace_ext);

    signal(SIGPIPE, &ignore);
    version (linux) {
        import core.sys.posix.signal;

        //        import core.runtime;

        sigaction_t sa = void;
        (cast(byte*)&sa)[0 .. sa.sizeof] = 0;
        /// sigfillset( &action.sa_mask ); // block other signals

        sa.sa_sigaction = &segment_fault;
        sigemptyset(&sa.sa_mask);
        sa.sa_flags = SA_RESTART;
        // sa.sa_flags = SA_SIGINFO | SA_RESETHAND;
        sigaction(SIGSEGV, &sa, null);
        //signal(SIGSEGV, &segment_fault);   // Segment fault handler
    }

    signal(SIGINT, &shutdown);
    signal(SIGTERM, &shutdown);
}
