module tagion.prior_services.EpochDebugService;

import std.concurrency;
import tagion.basic.Types : Control;
import tagion.basic.TagionExceptions : fatal;
import tagion.hibon.Document : Document;

void epochDebugServiceTask(string task_name) nothrow {
    scope (exit) {
        import std.exception : assumeWontThrow;

        assumeWontThrow(ownerTid.send(Control.END));
    }
    try {
        bool stop;

        void controller(Control control) {
            if (control is Control.STOP) {
                stop = true;
            }
        }

        scope uint[string] epoch_counter;

        void epoch_check(string transcript_task_name, immutable(Document) doc) {
            if (transcript_task_name in epoch_counter) {
                epoch_counter[transcript_task_name] = 0;
            }
            else {
                epoch_counter[transcript_task_name]++;
            }

        }

        ownerTid.send(Control.LIVE);
        while (!stop) {
            receive(&controller, &epoch_check);
        }
    }
    catch (Throwable t) {
        fatal(t);
    }
}
