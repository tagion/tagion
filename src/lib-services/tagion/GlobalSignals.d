module tagion.GlobalSignals;
import core.stdc.signal;
import core.stdc.stdio;
import core.stdc.stdlib: exit, system;
import core.stdc.string : strlen;

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

shared bool abort=false;

static extern(C) void shutdown(int sig) @nogc nothrow {

    printf("Shutdown sig %d about=%d\n\0".ptr, sig, abort);
    if (sig is SIGINT || sig is SIGTERM) {
        if(abort){
            exit(0);
        }
        abort=true;
    }
//    printf("Shutdown sig %d\n\0".ptr, sig);
}

version (linux) {
    import core.sys.posix.unistd : STDERR_FILENO;
    import core.sys.posix.signal;
    enum BACKTRACE_SIZE=0x80; /// Just big enough to hold the call stack
    static extern(C) void segment_fault(int sig, siginfo_t* ctx, void* ptr) @nogc nothrow {
        abort=true;
        static void addr2line(const(void*) trace, const(char[]) msg) @nogc nothrow {
            enum MSG_SIZE = 0x100;
            scope char[MSG_SIZE] buffer;
            // foreach(i, msg; messages[0..size]) {
            //     scope  _msg=msg[0..strlen(msg)];
            const(char)[] info;
            foreach(i, c; msg) {
                if ((c == '(') || (c == ' ')) {
                    info=msg[0..i];
                    break;
                }
            }
            fprintf(stderr, "info=%.*s\n", cast(int)(info.length), info.ptr);
            // foreach_reverse(i, c; info) {
            //     if (c == ')') {
            //         info=info[0..i-1];
            //         break;
            //     }
            // }
            // fprintf(stderr, "after info=%.*s", cast(int)(info.length), info.ptr);
            const ret=snprintf(buffer.ptr, MSG_SIZE, "addr2line -p %p -e %.*s", trace, cast(int)(info.length), info.ptr);
            if (ret > 0) {
                fprintf(stderr, "%s\n", buffer.ptr);
                system(buffer.ptr);
            }
            else {
                fprintf(stderr, "Message exceeds the buffer %.*s", cast(int)(msg.length), msg.ptr);
            }
            // int snprintf(char *str, size_t size, const char *format, ...);

            // int snprintf(char *str, size_t size, const char *format, ...);

        }

        fprintf(stderr, "Segment Fault\n");
        void*[BACKTRACE_SIZE] callstack;
        int size;

        if (sig == SIGSEGV) {
            fprintf(stderr, "Got signal %d, faulty address is %p, from pid %d\n", sig, ctx.si_addr, ctx.si_pid);
        }
        else {
            fprintf(stderr, "Got signal %d\n", sig);
        }


        // get void*'s for all entries on the stack
        size = backtrace(callstack.ptr, BACKTRACE_SIZE);
        /* overwrite sigaction with caller's address */
        // callstack[1] = ctx.si_addr;

        backtrace_symbols_fd(callstack.ptr, size, STDERR_FILENO);

        scope char** messages;
        messages = backtrace_symbols(callstack.ptr, size);

        {

        }
        foreach(i, msg; messages[0..size]) {
            fprintf(stderr, "%s\n", msg);
            fprintf(stderr, "callstack %p\n", callstack[i]);
//            fprintf(stderr, "          %x\n", *callstack[i]);
//            scope  _msg=msg[0..strlen(msg)];
            addr2line(callstack[i], msg[0..strlen(msg)]);
            // const(char)[] file;
            // foreach(j, c; _msg) {
            //     if ((c == '(') || (c == ' ')) {
            //         file=_msg[j..$];
            //         break;
            //     }
            // }
            // while((_message.length > 0) && (_message[0] != '(') && (_message[0] != ' ')) {
        //     _message=_message[1..$];
        // }
        }

        {
            auto fp = fopen ("/tmp/file.txt", "w");
            scope(exit) {
                fclose(fp);
            }
            foreach(i, msg; messages[0..size]) {
                fprintf(fp, "%s\n", msg);
            }
        }
//q        fprintf(stderr, "%.*s\n", cast(int)(file.length), file.ptr);
//    }

        exit(-1);
}
}

/+
int main() {

  /* Install our signal handler */
  struct sigaction sa;

  sa.sa_handler = (void *)bt_sighandler;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;

  sigaction(SIGSEGV, &sa, NULL);
  sigaction(SIGUSR1, &sa, NULL);
  /* ... add any other signal here */

  /* Do something */
  printf("%d\n", func_b());
}
+/

import core.stdc.signal;
enum SIGPIPE=13; // SIGPIPE is not defined in the module core.stdc.signal
static extern(C) void ignore(int sig) @nogc nothrow {
    printf("Ignore sig %d\n\0".ptr, sig);
}

shared static this() {
    signal(SIGPIPE, &ignore);
    version (linux) {
        import core.sys.posix.signal;
//        import core.runtime;

         sigaction_t sa = void;
         (cast(byte*) &sa)[0 .. sa.sizeof] = 0;
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
