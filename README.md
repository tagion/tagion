Ressources:
Short introduction the principles behind actor based concurrency (4:32 min) [Actor Model Explained](https://www.youtube.com/watch?v=ELwEdb_pD0k)
Programming in D (Chapter 85: Message passing concurrency)
A talk about the design and principles of erlang By Joe Armstrong (1 hour) [Erlang - software for a concurrent world](https://www.infoq.com/presentations/erlang-software-for-a-concurrent-world/)

The controlflow is described here https://docs.tagion.org/#/documents/modules/actor/actor_requirement

In general the actor will look something like this

```d
    // State messages send to the supervisor from the children
    enum Ctrl {
        STARTING, // The actors is lively
        ALIVE, /// Send to the ownerTid when the task has been started
        FAIL, /// This if a something failed other than an exception
        END, /// Send for the child to the ownerTid when the task ends
    }

    enum Msg {
    // define the type of message your actor should be able to receive

    }
    void task() {
        stop = false;

        setState(Ctrl.STARTING); // Tell the owner that you are starting.
        scope (exit) setState(Ctrl.END); // Tell the owner that you have finished.

        setState(Ctrl.ALIVE); // Tell the owner that you running
        while (!stop) {
            try {
                receive(
                    // Implement messages
                    (Msg, args..) {
                    }
                    (CtrlMsg ctrl) {
                    // Handle the control messages sent from the children
                    }
                    (ownerTerminated) {
                    // What to do if the owner terminates
                    }
                    (Variant var) {
                    // What to do if you receive an unkown message
                    }
                );
            }
            // If we catch an exception we send it back to owner for them to deal with it.
            catch (shared(Exception) e) {
                // Preferable FAIL would be able to carry the exception with it
                ownerTid.prioritySend(e);
                setState(Ctrl.FAIL);
                stop = true;
            }
        }
    }
```

As a rould the actors themselvs should never use the `receiveOnly!T` function

We have created an actor class that handles most of the control flow so you actor should look somewhat likes
```d
static class MyActor : Actor {
    // Define messages

    void task() {
        stop = false;

        setState(Ctrl.STARTING); // Tell the owner that you are starting.
        scope (exit) setState(Ctrl.END); // Tell the owner that you have finished.

        setState(Ctrl.ALIVE); // Tell the owner that you running
        while (!stop) {
            try {
                actorReceive(
                // Implement messages
                );
            }
            // If we catch an exception we send it back to owner for them to deal with it.
            catch (shared(Exception) e) {
                // Preferable FAIL would be able to carry the exception with it
                ownerTid.prioritySend(e);
                setState(Ctrl.FAIL);
                stop = true;
            }
        }
    }
}
```
