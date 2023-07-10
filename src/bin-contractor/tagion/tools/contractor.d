/// Test "wallet" to interact with neuewelle over a Socket
module tagion.tools.contractor;

import std.socket;

import tagion.dart.DARTcrud;
import tagion.communication.HiRPC;
import tagion.tools.Basic;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONBase;
import tagion.services.inputvalidator : contract_sock_path;

mixin Main!(_main);

int _main(string[] _) {
    HiRPC hirpc;
    HiBON hibon = new HiBON();

    hibon["$test"] = 5;

    const sender = hirpc.act(hibon);

    Address addr = new UnixAddress(contract_sock_path);
    Socket sock = new Socket(AddressFamily.UNIX, SocketType.STREAM);

    sock.connect(addr);

    sock.send(sender.toDoc.serialize);

    return 0;
}
