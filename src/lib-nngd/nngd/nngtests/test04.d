module nngd.nngtests.test04;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.conv;
import std.random;
import core.thread;
import core.thread.osthread;
import nngd;

version (unittest) {
}
else {
    pragma(msg, "This breaks the unittest so it's disabled");
    const _testclass = "nngd.nngtests.nng_test04_pubsub";

    @trusted class nng_test04_pubsub : NNGTest {

        this(Args...)(auto ref Args args) {
            super(args);
        }

        override string[] run() {
            log("NNG test 04: pubsub");
            this.uri = "tcp://127.0.0.1:31004";
            workers ~= new Thread(&(this.pub_worker)).start();
            Thread.sleep(msecs(200));
            foreach (t; this.tags) {
                this.tag = t;
                workers ~= new Thread(&(this.sub_worker)).start();
                Thread.sleep(msecs(200));
            }
            foreach (w; workers)
                w.join();
            log(_testclass ~ ": Bye!");
            return [];
        }

        void pub_worker() @trusted {
            const NMSGS = 32;
            uint k = 0;
            int rc;
            try {
                thread_attachThis();
                rt_moduleTlsCtor();
                log("PUB: broadcasting to " ~ uri);
                NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_PUB);
                s.sendtimeout = msecs(1000);
                s.sendbuf = 4096;
                log("PUB: listening");
                rc = s.listen(this.uri);
                if (rc != 0) {
                    error("PUB: errror listening on " ~ this.uri);
                }
                k = 0;
                auto rnd = Random(42);
                while (++k < NMSGS) {
                    auto line = format((this.tags.choice(rnd)) ~ `{"msg": %d, "check": %d, "time": %f}`,
                            k, mkrot3(k), timestamp());
                    if (k == NMSGS - 1) {
                        foreach (t; this.tags) {
                            line = t ~ "END";
                            rc = s.send(line);
                            enforce(rc == 0);
                            log("PUB: sent: " ~ line);
                        }
                        break;
                    }
                    rc = s.send(line);
                    enforce(rc == 0);
                    log("PUB: sent: " ~ line);
                    nng_sleep(msecs(100));
                }
                nng_sleep(msecs(100));
                log("PUB: bye!");
            }
            catch (Throwable e) {
                error(dump_exception_recursive(e, "SS: Sender worker"));
            }
        }

        void sub_worker() @trusted {
            const NDIALS = 32;
            string _tag = this.tag.dup;
            uint k = 0;
            int rc;
            bool _ok = false;
            try {
                thread_attachThis();
                rt_moduleTlsCtor();
                NNGSocket s = NNGSocket(nng_socket_type.NNG_SOCKET_SUB);
                s.recvtimeout = msecs(6000);
                s.subscribe(tag);
                enforce(rc == 0);
                log("SUB(" ~ _tag ~ "): subscribed to " ~ _tag);
                while (1) {
                    if (k++ > NDIALS + 4)
                        break;
                    log("SUB(" ~ _tag ~ "): to dial...");
                    rc = s.dial(this.uri);
                    if (rc == 0) {
                        _ok = true;
                        break;
                    }
                    if (rc == nng_errno.NNG_ECONNREFUSED && k++ < NDIALS) {
                        log("SUB: Connection refused attempt %d", k);
                        nng_sleep(msecs(100));
                        continue;
                    }
                    error("SUB(%s): Dial error: %s", _tag, rc);
                    enforce(rc == 0);
                }
                if (!_ok) {
                    error("SUB(" ~ _tag ~ "): couldn`t dial");
                    return;
                }
                log("SUB(%s): %s", _tag, s.subscriptions());
                k = 0;
                _ok = false;
                while (1) {
                    log("SUB(" ~ _tag ~ "): to receive");
                    auto str = s.receive!string;
                    if (s.errno == 0) {
                        log(format("SUB(" ~ _tag ~ ") recv [%03d]: %s", str.length, str));
                        if (str[$ - 3 .. $] == "END") {
                            log("SUB(" ~ _tag ~ "): to stop");
                            _ok = true;
                            break;
                        }
                    }
                    else {
                        error("SUB(%s): Error string: %s", _tag, s.errno);
                    }
                }
                if (!_ok) {
                    error("Test stopped without normal end.");
                }
                log("SUB(" ~ _tag ~ "): bye!");
            }
            catch (Throwable e) {
                error(dump_exception_recursive(e, "RR: Receiver worker"));
            }
        }

    private:
        immutable string[] tags = ["TAG0", "TAG1", "TAG2", "TAG3"];
        Thread[] workers;
        string uri;
        string tag;

    }

}
