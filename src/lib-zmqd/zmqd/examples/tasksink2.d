// Task sink - design 2
// Adds pub-sub flow to send kill signal to workers
import std.datetime, std.stdio;
import zmqd, zhelpers;

import std.datetime.stopwatch;

void main() {
    // Socket to receive messages on
    auto receiver = Socket(SocketType.pull);
    receiver.bind("tcp://*:5558");

    // Socket for worker control
    auto controller = Socket(SocketType.pub);
    controller.bind("tcp://*:5559");

    // Wait for start of batch
    sRecv(receiver);

    // Start our clock now
    StopWatch watch;
    watch.start();

    // Process 100 confirmations
    for (int taskNbr = 0; taskNbr < 100; ++taskNbr) {
        sRecv(receiver);
        if ((taskNbr / 10) * 10 == taskNbr) {
            write(":");
        }
        else {
            write(".");
        }
        stdout.flush();
    }
    watch.stop();
    writefln("Total elapsed time: %s\n", watch.peek);

    // Send kill signal to workers
    controller.send("KILL");
}
