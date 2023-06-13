/// Test "wallet" to interact with neuewelle over a Socket
module tagion.tools.contracter;

import std.socket;
import tagion.dart.DARTcrud;
import tagion.communication.HiRPC;
import tagion.tools.neuewelle : contract_socket_path;
import tagion.hibon.HiBON;
import tagion.hibon.HiBONBase;

mixin Main!(_main);

int _main(void) {
    HiRPC hirpc;
    HiBON hibon = new HiBON();

    hibon["$test"] = 5;

    const sender = hirpc.action("action", hibon);

    Address addr = UnixAddress(contract_socket_path);
    Socket sock = new Socket(AddressFamily.UNIX, SocketType.STREAM);

    sock.connect(addr);

    sock.send(sender.toDoc.serialize);
}
