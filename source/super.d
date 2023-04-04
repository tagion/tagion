version(none)
struct Supervisor {

    // The primary off messages that an Supervisor takes in extension of the control messages
    enum Msg {
        HEALTH,
        NONE,
    }

    void msgDelegate(Msg msg) {
        final switch(msg) {
        case Msg.HEALTH:
            assert(0, not_impl);
        case Msg.NONE:
            assert(0, not_impl);
        }
    }

    void task() {
        bool stop = false;

        sendOwner(Control.STARTING); // Tell the owner that you have started.
        scope(exit) sendOwner(Control.END); // Tell the owner that you have finished.

        while(!stop) {
            try {
                receive(
                    &msgDelegate,
                    /* &exceptionHandler, */

                    /* (OwnerTerminated _e) { */
                    /*     writeln("Owner stopped... nothing to life for... stopping self"); */
                    /*     stop = true; */
                    /* }, */
                    // Default
                    (Variant other) {
                        // For unkown messages we assert,
                        // basically so we don't accidentally fill up our messagebox with garbage
                        assert(0, "No delegate to deal with message: %s".format(other));
                    }
                );
            }
            catch (OwnerTerminated _e) {
                        writeln("Owner stopped... nothing to life for... stopping self");
                        stop = true;
            }
            // If we catch an exception we send it back to supervisor for them to deal with it.
            catch (shared(Exception) e) {
                sendOwner(e);
                stop = true;
            }
        }
    }
}
