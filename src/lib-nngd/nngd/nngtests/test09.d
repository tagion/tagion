module nngd.nngtests.test09;

import std.stdio;
import std.concurrency;
import std.exception;
import std.json;
import std.format;
import std.conv;
import std.datetime.systime;
import std.algorithm;
import std.string;
import std.uuid;
import std.file;
import std.path;
import std.regex;
import std.process;
import core.thread;
import core.thread.osthread;
import nngd;

version (unittest) {
}
else {
    pragma(msg, "This breakes the unittest so it's disabled")
    const _testclass = "nngd.nngtests.nng_test09_webapp";

    long getmemstatus() {
        long sz = -1;
        auto f = File("/proc/self/status", "rt");
        foreach (line; f.byLine) {
            if (line.startsWith("VmRSS")) {
                sz = to!long(line.split()[1]);
                break;
            }
        }
        f.close();
        return sz;
    }

    @trusted class nng_test09_webapp : NNGTest {

        this(Args...)(auto ref Args args) {
            super(args);
        }

        override string[] run() {
            log("NNG test 09: WebApp");

            int rc;
            auto self_ = self;

            auto wd = nngtest_mkassert();
            enforce(wd !is null && wd.exists, "Error creating assert dir");

            WebApp app = WebApp("myapp", "http://localhost:13009", parseJSON(`{"root_path":"` ~ wd ~ `/webapp","static_path":"static"}`), &self_);

            app.route("/api/v1/test2/*", &api_handler2, ["POST", "GET"]);
            app.route("/api/v1/test1/*", &api_handler1, ["GET"]);
            app.route("/api/v1/memsize", &getmem_handler, ["GET"]);

            app.start();

            {
                auto res = executeShell("curl -k -s http://localhost:13009/static | grep -q 'NNG HTTP TEST'");
                enforce(res.status == 0, "on static file");
            }

            {
                auto res = executeShell("curl -k -s http://localhost:13009/api/v1/test1/a/b/c/?x=y");
                enforce(res.status == 0);
                auto jres = parseJSON(res.output);
                enforce(jres["#TAG"].str == "handler1");
                enforce(jres["path"][2].str == "test1");
                enforce(jres["param"]["x"].str == "y");
            }

            {
                auto res = executeShell("curl -k -s http://localhost:13009/api/v1/test2/a/b/c/?x=y");
                enforce(res.status == 0);
                auto jres = parseJSON(res.output);
                enforce(jres["replyto"]["#TAG"].str == "handler2");
                enforce(jres["replyto"]["path"][2].str == "test2");
                enforce(jres["replyto"]["param"]["x"].str == "y");
            }

            {
                auto fn = wd.buildPath("file.bin");
                auto drc = executeShell("dd if=/dev/urandom of=" ~ fn ~ " count=1 bs=1048576");
                enforce(drc.status == 0);
                auto res = executeShell(
                        "curl -k -s -X POST -H \"Content-Type: application/octet-stream\" --data-bin @" ~ fn ~ " http://localhost:13009/api/v1/test2");
                enforce(res.status == 0);
                auto jres = parseJSON(res.output);
                enforce(jres["datalength"].integer == 1048576);
                enforce(jres["datatype"].str == "application/octet-stream");
            }

            nngtest_rmassert(wd);
            log(_testclass ~ ": Bye!");
            return [];
        }

        static void api_handler1(WebData* req, WebData* rep, void* ctx) {
            try {
                thread_attachThis();
                auto obj = cast(nng_test09_webapp*) ctx;
                obj.log("Handler 1");
                rep.text = to!string((*req).toJSON("handler1"));
                rep.type = "text/plain";
                rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
            }
            catch (Throwable e) {
                nngtest_error(dump_exception_recursive(e, "Handler - 1"));
            }
        }

        static void api_handler2(WebData* req, WebData* rep, void* ctx) {
            try {
                thread_attachThis();
                auto obj = cast(nng_test09_webapp*) ctx;
                obj.log("Handler 2");
                JSONValue data = parseJSON("{}");
                if (req.method == "GET") {
                    data["replyto"] = (*req).toJSON("handler2");
                    rep.json = data;
                    rep.type = "application/json";
                    rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                    return;
                }
                if (req.method == "POST") {
                    if (req.type == "application/octet-stream") {
                        data["datalength"] = req.rawdata.length;
                        data["datatype"] = req.type;
                        rep.json = data,
                        rep.type = "application/json",
                        rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                        return;
                    }
                    else {
                        rep.status = nng_http_status.NNG_HTTP_STATUS_BAD_REQUEST;
                        rep.msg = "Invalid request";
                        return;
                    }
                }
            }
            catch (Throwable e) {
                nngtest_error(dump_exception_recursive(e, "Handler - 2"));
            }
        }

        static void getmem_handler(WebData* req, WebData* rep, void* ctx) {
            try {
                thread_attachThis();
                auto obj = cast(nng_test09_webapp*) ctx;
                obj.log("Handler getmem");
                JSONValue data = parseJSON("{}");
                data["memsize"] = getmemstatus();
                rep.status = nng_http_status.NNG_HTTP_STATUS_OK;
                rep.type = "applicaion/json";
                rep.json = data;
                obj.log(rep.toString());
            }
            catch (Throwable e) {
                nngtest_error(dump_exception_recursive(e, "GetMem handler"));
            }
        }

    }
}
