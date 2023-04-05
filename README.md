Resources:  
Short introduction the principles behind actor based concurrency (4:32 min) [Actor Model Explained](https://www.youtube.com/watch?v=ELwEdb_pD0k)  
Programming in D (Chapter 85: Message passing concurrency)  
A talk about the design and principles of erlang By Joe Armstrong, 
it also makes clear the nuance between implementing actors as a language feature (erlang/BEAM) versus implementing it as a library (this/std.concurrency)
(1 hour) [Erlang - software for a concurrent world](https://www.infoq.com/presentations/erlang-software-for-a-concurrent-world/)  

The controlflow is described here https://docs.tagion.org/#/documents/modules/actor/actor_requirement  

In general the flow of the actor will look something like this

```d
    // State messages send to the supervisor from the children
    enum Ctrl {
        STARTING, // The actors is lively
        ALIVE, /// Send to the ownerTid when the task has been started
        FAIL, /// This if a something failed other than an exception
        END, /// Send for the child to the ownerTid when the task ends
    }

    enum Msg {
        // define the type of message your actor should be able to receive..

    }
    void someSpawnableTask() {
        stop = false; // To begin, the should be running.

        setState(Ctrl.STARTING); // Tell the owner that you are starting.
        scope (exit) setState(Ctrl.END); // Tell the owner that you have finished.

        setState(Ctrl.ALIVE); // Tell the owner that you running
        while (!stop) {
            try {
                receive(
                    // If it's one of our defined messages
                    (Msg.SomeMsg, args..) {
                        // Implement messages..
                    }

                    // Control messages sent from the children.
                    (CtrlMsg ctrl) {
                        // Handle the control messages sent from the children
                    }

                    // If the owner terminates
                    (ownerTerminated) {
                        // Stop itsef
                    }

                    // If it's an unknown message
                    (Variant var) {
                        // Send a fail to the owner.
                    }
                );
            }

            // If we catch an exception we send it back to owner for them to deal with it.
            catch (shared(Exception) e) {
                // Send the fail state along with the exception to the supervisour
                setState(Ctrl.FAIL, e);
            }
        }
    }
```

As a rule the actors themselves should never use the `receiveOnly!T` function.
Then you might aswell be using async/await except kindof worse.

We have created an actor class that handles most of the control flow so you actor should look somewhat likes
```d
static class MyActor : Actor {
    // Define messages

    void task() {
        actorTask(
        // Implement messages
        );
    }
}
```
