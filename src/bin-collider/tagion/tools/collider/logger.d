module tagion.tools.collider.logger;

import std.format;
import std.stdio;
import std.path;
import std.file;
import std.algorithm;

import tagion.behaviour.Behaviour : getBDDErrors, TestCode, testCode, testColor;
import tagion.behaviour.BehaviourFeature : FeatureGroup;
import tagion.tools.Basic;
import tagion.utils.Term;
import tagion.hibon.HiBONFile;
import tagion.hibon.HiBONRecord : isRecord;

int printReport(ref File fout, string[] paths) {

    bool show(const TestCode test_code) nothrow {
        return verbose_switch || test_code == TestCode.error || test_code == TestCode.started;
    }

    void show_report(Args...)(const TestCode test_code, string fmt, Args args) {
        static if (Args.length is 0) {
            const text = fmt;
        }
        else {
            const text = format(fmt, args);
        }
        fout.writefln("%s%s%s", testColor(test_code), text, RESET);
    }

    void report(Args...)(const TestCode test_code, string fmt, Args args) {
        if (show(test_code)) {
            show_report(test_code, fmt, args);
        }
    }

    struct TraceCount {
        uint passed;
        uint errors;
        uint started;
        uint total;
        void update(const TestCode test_code) nothrow pure {
            final switch (test_code) {
            case TestCode.none:
                break;
            case TestCode.passed:
                passed++;
                break;
            case TestCode.error:
                errors++;
                break;
            case TestCode.started:
                started++;

            }
            total++;
        }

        TestCode testCode() nothrow pure const {
            if (passed == total) {
                return TestCode.passed;
            }
            if (errors > 0) {
                return TestCode.error;
            }
            if (started > 0) {
                return TestCode.started;
            }
            return TestCode.none;
        }

        int result() nothrow pure const {
            final switch (testCode) {
            case TestCode.none:
                return 1;
            case TestCode.error:
                return cast(int) errors;
            case TestCode.started:
                return -cast(int)(started);
            case TestCode.passed:
                return 0;
            }
            assert(0);
        }

        void report(string text) {
            const test_code = testCode;
            if (test_code == TestCode.passed) {
                show_report(test_code, "%d test passed BDD-tests", total);
            }
            else {
                writef("%s%s%s: ", BLUE, text, RESET);
                show_report(test_code, " passed %2$s/%1$s, failed %3$s/%1$s, started %4$s/%1$s",
                        total, passed, errors, started);
            }
        }

    }

    TraceCount feature_count;
    TraceCount scenario_count;
    foreach (path; paths) {
        foreach (string report_file; dirEntries(path, "*.hibon", SpanMode.breadth)
                .filter!(f => f.isFile)) {
            try {
                const doc = report_file.fread;
                if (doc.isRecord!FeatureGroup) {
                    const feature_group = FeatureGroup(doc);
                    const feature_test_code = testCode(feature_group);
                    feature_count.update(feature_test_code);
                    if (show(feature_test_code)) {
                        fout.writefln("Trace file %s", report_file);
                    }

                    report(feature_test_code, feature_group.info.property.description);
                    const show_scenario = feature_test_code == TestCode.error
                        || feature_test_code == TestCode.started;
                    foreach (scenario_group; feature_group.scenarios) {
                        const scenario_test_code = testCode(scenario_group);
                        scenario_count.update(scenario_test_code);
                        if (show_scenario) {
                            report(scenario_test_code, "\t%s", scenario_group.info.property
                                    .description);
                            foreach (err; getBDDErrors(scenario_group)) {
                                report(scenario_test_code, "\t\t%s", err.msg);
                            }
                        }
                    }
                }
            }
            catch (Exception e) {
                error("Error: %s in handling report %s", e.msg, report_file);
            }
        }
    }

    feature_count.report("Features ");
    if (feature_count.testCode !is TestCode.passed) {
        scenario_count.report("Scenarios");
    }
    return feature_count.result;
}
