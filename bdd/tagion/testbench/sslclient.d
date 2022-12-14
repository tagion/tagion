module tagion.testbench.sslclient;

import tagion.testbench.network;
import tagion.tools.Basic;

import tagion.network.SSLSocket;
import tagion.network.SSLServiceOptions;

mixin Main!(_main);

int _main(string[] args) {
    version (none) {
        ushort port;
        enum BUFFER_SIZE = 1024;
        if (args.length >= 2) {
            port = to!ushort(args[1]);
        }
        else {
            port = 4444;
        }

        auto addresses = getAddress("localhost", port);
        auto socket = new Socket(AddressFamily.INET, SocketType.STREAM, ProtocolType.TCP);
        scope (exit)
            socket.close();

        socket.connect(addresses[0]);

        //    auto buffer = new ubyte[2056];
        ptrdiff_t amountRead;

        string test = "Hello";
        //immutable buffer=cast(immutable(ubyte[]))(test);

        HRPC hrpc;
        immutable passphrase = "Very secret password for the client";
        hrpc.net = new HRPCNet(passphrase);

        auto randtime = Random!uint(5678);

        foreach (num; 0 .. 10) {
            {
                auto bson = new HBSON;

                bson["test"] = "Hello";
                bson["value"] = randtime.value(1000);
                auto sender = hrpc.action("read", bson);

                immutable buffer = hrpc.toBSON(sender).serialize;
                writefln("\nSend %s bytes", buffer.length);
                socket.send(buffer);

                ubyte[1024] buf;

                auto buf_size = socket.receive(buf);
                if (buf_size > 0) {
                    auto doc_received = Document(buf[0 .. buf_size].idup);
                    auto received = hrpc.receive(doc_received);
                    writeln("Received :");
                    writeln(doc_received.toText);
                    if (received.verified) {
                        writeln("Message is verified and signed");
                    }
                    else {
                        writeln("Message is not signed");
                    }
                }
                else {
                    writefln("Buffer %d", buf_size);
                }
            }
            Thread.sleep(randtime.value(200).msecs);

            {
                auto sender = hrpc.action("noarg", null);

                immutable buffer = hrpc.toBSON(sender).serialize;
                writefln("\nSend %s bytes", buffer.length);
                socket.send(buffer);

                ubyte[1024] buf;

                auto buf_size = socket.receive(buf);
                if (buf_size > 0) {
                    auto doc_received = Document(buf[0 .. buf_size].idup);
                    auto received = hrpc.receive(doc_received);
                    writeln("Received :");
                    writeln(doc_received.toText);
                    if (received.verified) {
                        writeln("Message is verified and signed");
                    }
                    else {
                        writeln("Message is not signed");
                    }
                }
                else {
                    writefln("Biffer %d", buf_size);
                }

            }
            Thread.sleep(randtime.value(200).msecs);
        }
        //buffer[0..test.length]=
        // while((amountRead = socket.receive(buffer)) != 0) {
        //     enforce(amountRead > 0, lastSocketError);

        //     // Do stuff with buffer
        // }
    }
    return 0;
}
