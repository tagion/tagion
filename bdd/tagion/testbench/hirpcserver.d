module tagion.testbench.hirpcserver;

import std.algorithm : remove;
import std.conv : to;
import std.format;
import std.socket : InternetAddress, Socket, SocketException, SocketSet, TcpSocket;

// import std.stdio : writeln, writefln;
import std.stdio;
import tagion.Keywords;
import tagion.basic.Types : Buffer;
import tagion.communication.HiRPC;
import tagion.gossip.GossipNet;
import tagion.hibon.HiBON;
import tagion.tools.Basic;
import tagion.utils.Miscellaneous : toHexString;

version (none) class HRPCNet : StdSecureNet {
    import tagion.hashgraph.HashGraph;

    override void request(HashGraph hashgraph, immutable(ubyte[]) fingerprint) {
        assert(0, format("Not implemented %s", __PRETTY_FUNCTION__));
    }

    this(string passphrase) {
        import tagion.crypto.secp256k1.NativeSecp256k1;

        super(new NativeSecp256k1(NativeSecp256k1.Format.AUTO, NativeSecp256k1.Format.COMPACT));
        generateKeyPair(passphrase);
        writefln("Pubkey %s:%d", (cast(Buffer) pubkey).toHexString!true, pubkey.length);
    }
}

import file = std.file;
import std.file : exists, tempDir;
import std.path;
import std.stdio;
import tagion.utils.Miscellaneous : toHexString;

version (none) struct Bank {
    protected enum _transactions = [
            "accountCreate",
            "accountGetHistoryExchange",
            "accountMakeTransfer",
            "accountMakeExchange"
        ];

    import std.traits : EnumMembers;
    import tagion.Base : EnumText;

    mixin(EnumText!("Transactions", _transactions));

    protected enum _params = [
            "account",
            "amount"
        ];

    mixin(EnumText!("Params", _params));

    alias HRPCSender = HRPC.HRPCSender;
    alias HRPCReceiver = HRPC.HRPCReceiver;
    HRPC hrpc;

    static immutable(Buffer) getAccount(ref const(HRPCReceiver) received) {
        HRPC.check_element!Buffer(received.params, Params.account);
        return received.params[Params.account].get!Buffer;
    }

    enum EXT = "bson";
    string filename(immutable(Buffer) account) {
        return tempDir.buildPath(setExtension(account.toHexString, EXT));
    }

    // const(HRPCSender) opDispatch(string method)(ref const(HRPCReceiver) received) isValid!Transactions, method)  {
    //     enum code=format("%s(%s)", method, read_only);
    //     mixin(code);
    // }

    const(HRPCSender) accountCreate(ref const(HRPCReceiver) received) {
        immutable account = getAccount(received);
        immutable filename = filename(account);
        if (filename.exists) {
            auto bson_data = new HBSON;
            bson_data[Params.account] = received.params[Params.account].get!Buffer;
            return hrpc.error(received, format("Account %s already exists", account.toHexString), -17, bson_data);
        }
        auto bson_account = new HBSON;
        // FixMe: CBR amount must be a uint NOT int
        // Standard BSON does not support uint
        //        bson_account[Params.amount]=0u;
        bson_account[Params.amount] = 0;
        file.write(filename, bson_account.serialize);
        return hrpc.result(received, bson_account);
    }

    const(HRPCSender) accountGetHistoryExchange(ref const(HRPCReceiver) received) {
        immutable account = getAccount(received);
        return hrpc.error(received, format("Not implemented yet %s", __PRETTY_FUNCTION__), -17);
    }

    const(HRPCSender) accountMakeTransfer(ref const(HRPCReceiver) received) {
        immutable account = getAccount(received);
        return hrpc.error(received, format("Not implemented yet %s", __PRETTY_FUNCTION__), -17);
    }

    const(HRPCSender) accountMakeExchange(ref const(HRPCReceiver) received) {
        immutable account = getAccount(received);
        return hrpc.error(received, format("Not implemented yet %s", __PRETTY_FUNCTION__), -17);
    }

    /++
     Executes the transaction method

     Params: received contains valid method and a params object
     Returns: Returns a HRPC either an result or an error
     +/
    const(HRPCSender) opCall(ref const(HRPCReceiver) received) {
        if (!received.params.empty) {
            if (received.params.hasElement("id")) {
                immutable message = format("The parameter 'id' should be called 'account' instead", received
                        .message.method);
                return hrpc.error(received, message, 42);
            }
        }
        switch (received.message.method) {
            static foreach (method; EnumMembers!Transactions) {
                mixin(format("case Transactions.%s: return %s(received);", method, method));
            }
        default:
            immutable message = format("Method '%s' not supported", received.message.method);
            return hrpc.error(received, message, 22);
        }
        assert(0);
    }
}

mixin Main!_main;

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

        auto listener = new TcpSocket();
        assert(listener.isAlive);
        listener.blocking = false;
        listener.bind(new InternetAddress(port));
        listener.listen(10);

        writefln("Listening on port %d.", port);
        stdout.flush;
        enum MAX_CONNECTIONS = 60;
        // Room for listener.
        auto socketSet = new SocketSet(MAX_CONNECTIONS + 1);
        Socket[] reads;

        HRPC hrpc;
        immutable passphrase = "Very secret password for the server";
        hrpc.net = new HRPCNet(passphrase);
        Bank bank;
        bank.hrpc = hrpc;
        while (true) {
            socketSet.add(listener);

            foreach (sock; reads) {
                socketSet.add(sock);
            }

            Socket.select(socketSet, null, null);

            for (size_t i = 0; i < reads.length; i++) {
                if (socketSet.isSet(reads[i])) {
                    ubyte[BUFFER_SIZE] buf;
                    auto datLength = reads[i].receive(buf[]);

                    if (datLength == Socket.ERROR) {
                        writeln("Connection error.");
                    }
                    else if (datLength != 0) {

                        writefln("\nReceived %d bytes from %s", datLength, reads[i].remoteAddress()
                                .toString());
                        const(HRPC.HRPCReceiver)* ref_received;
                        auto doc = Document(buf[0 .. datLength].idup);
                        writeln(doc.toText);
                        stdout.flush;
                        try {
                            auto received = hrpc.receive(doc);

                            ref_received = &received;
                            if (received.verified) {
                                writeln("Message is verified and signed");
                            }
                            else {
                                writeln("Message is not signed");
                            }
                            version (none) {

                                auto bson_result = new HBSON;
                                bson_result[Keywords.method] = received.message.method;
                                bson_result[Keywords.params] = received.params;
                                bson_result["signed"] = received.verified;
                                auto message_doc = doc[Keywords.message].get!Document;
                                immutable hash = hrpc.net.calcHash(message_doc.data);
                                bson_result["hash"] = hash;
                            }
                            auto sender = bank(received);
                            immutable buffer = hrpc.toBSON(sender).serialize;

                            reads[i].send(buffer);
                            writeln("\nResonse:");
                            auto sender_doc = Document(buffer);
                            writefln(sender_doc.toText);
                            stdout.flush;

                        }
                        catch (Exception e) {
                            auto bson_data = new HBSON;
                            bson_data["stack"] = e.msg;
                            if ((ref_received) && !ref_received.empty) {
                                auto error_sender = hrpc.error(*ref_received, e.msg, 666, bson_data);
                                immutable error_buffer = hrpc.toBSON(error_sender).serialize;
                                reads[i].send(error_buffer);
                                writeln("\nError:");
                                auto error_doc = Document(error_buffer);
                                writeln(error_doc.toText);
                                stdout.flush;
                            }
                            else {
                                auto error_sender = hrpc.error(e.msg, 42);
                                immutable error_buffer = hrpc.toBSON(error_sender).serialize;
                                reads[i].send(error_buffer);
                                writeln("\nError:");
                                auto error_doc = Document(error_buffer);
                                writeln(error_doc.toText);
                                stdout.flush;
                            }
                        }

                        continue;
                    }
                    else {
                        try {
                            // if the connection closed due to an error, remoteAddress() could fail
                            writefln("Connection from %s closed.", reads[i].remoteAddress().toString());
                        }
                        catch (SocketException) {
                            writeln("Connection closed.");
                        }
                    }

                    // release socket resources now
                    reads[i].close();

                    reads = reads.remove(i);
                    // i will be incremented by the for, we don't want it to be.
                    i--;

                    writefln("\tTotal connections: %d", reads.length);
                    stdout.flush;
                }
            }

            if (socketSet.isSet(listener)) { // connection request
                Socket sn = null;
                scope (failure) {
                    writefln("Error accepting");
                    if (sn) {
                        sn.close();
                    }
                }
                sn = listener.accept();
                assert(sn.isAlive);
                assert(listener.isAlive);

                if (reads.length < MAX_CONNECTIONS) {
                    writefln("Connection from %s established.", sn.remoteAddress().toString());
                    reads ~= sn;
                    writefln("\tTotal connections: %d", reads.length);
                }
                else {
                    writefln("Rejected connection from %s; too many connections.", sn.remoteAddress()
                            .toString());
                    sn.close();
                    assert(!sn.isAlive);
                    assert(listener.isAlive);
                }
            }

            socketSet.reset();
        }
        stdout.flush;
    }
    return 0;
}
