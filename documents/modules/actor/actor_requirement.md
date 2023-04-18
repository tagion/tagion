# Requirement for the Actor base multitasking
An actor is a task that is able to send and receive messages from other tasks.
The actors have a hierarchical structure where the owner of an actor is called a supervisor and the actor owned by the supervisor is called a child.

When an actor fails the error should be sent to the supervisor and the supervisor should decide what should be done.

A supervisor should able to stop one or all children and if the actor requested to be stopped then it should safely stop all children owned by this actor.


And actor can have 3 Control stages

| Mode | Stage    | Description                                                        |
| ---- | -------- | ------------------------------------------------------------------ |
|  1.  | STARTING | When actor is starting and initializing the actor                  |
|  2.  | ALIVE    | When the actor has started a LIVE signal is send to the supervisor |
|  4.  | END      | When the actor stops a END signal is send to the supervisor        |


Additionally a FAIL is sent when the running task catches an exception. Containing the taskname and the exception.

child stops when a supervisor sends a STOP signal to the child and the child sends an END when it stops if an error occurs in the child the error (Exception) should be sent to the supervisor.


An actor has a set of received methods and this set of methods should never change as long as the actor is alive.

## Start and Stop of Actor hierarchy 

This diagram shows an example of the startup sequence of the supervisor hierarchy
```mermaid
sequenceDiagram
    participant Main 
    participant Actor1
    participant Actor2
    participant Actor3
    Main->>Actor1: run(Actor1) 
    Actor1->>Actor2: run(Actor2) 
    Actor2->>Actor3: run(Actor3)
	Actor3->>Actor2: Control.LIVE
	Actor2->>Actor1: Control.LIVE
	Actor1->>Main: Control.LIVE
```

This diagram shows the stop sequence.
```mermaid
sequenceDiagram
    participant Main 
    participant Actor1
    participant Actor2
    participant Actor3
    Main->>Actor1: Control.STOP 
    Actor1->>Actor2: Control.STOP
    Actor2->>Actor3: Control.STOP
	Actor3->>Actor2: Control.END
	Actor2->>Actor1: Control.END
	Actor1->>Main: Control.END
```
