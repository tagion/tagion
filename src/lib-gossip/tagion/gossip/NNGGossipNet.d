module tagion.gossip.NNGGossipNet;

import std.random;
import nngd;

import tagion.gossip.InterfaceNet;
import tagion.crypto.Types;
import tagion.utils.StdTime;
import tagion.communication.HiRPC;

@safe
class NNGGossipNet : GossipNet {
    private string[Pubkey] addresses;
    private Pubkey[] _pkeys;
    immutable(Pubkey) mypk;
    Random random;
    NNGSocket sock;

    this(const Pubkey mypk) @trusted {
        this.random = Random(unpredictableSeed);
        this.mypk = mypk;
        this.sock = NNGSocket(nng_socket_type.NNG_SOCKET_BUS);
    }

    void add_channel(const Pubkey channel) {
        import tagion.gossip.AddressBook : addressbook;

        const address = addressbook.getAddress(channel);

        _pkeys ~= channel;
        addresses[channel] = address;
    }

    void remove_channel(const Pubkey channel) {
        import std.algorithm.searching;

        const channel_index = countUntil(_pkeys, channel);
        _pkeys = _pkeys[0 .. channel_index] ~ _pkeys[channel_index + 1 .. $];
        addresses.remove(channel);
    }

    void close() @trusted {
        sock.close;
    }

    @property
    const(sdt_t) time() pure const nothrow {
        return sdt_t(0);
    }

    bool isValidChannel(const(Pubkey) channel) const pure nothrow {
        return (channel in addresses) !is null;
    }

    const(Pubkey) select_channel(const(ChannelFilter) channel_filter) {
        Pubkey send_channel;

        do {
            send_channel = choice(_pkeys, random);
        }
        while (send_channel !is mypk && channel_filter);

        return send_channel;
    }

    const(Pubkey) gossip(
            const(ChannelFilter) channel_filter,
            const(SenderCallBack) sender) {
        const send_channel = select_channel(channel_filter);
        if (send_channel.length) {
            send(send_channel, sender());
        }
        return send_channel;
    }

    @trusted
    void send(const Pubkey channel, const(HiRPC.Sender) sender) {
        // TODO encrypt
        // TODO: retry dial?
        sock.dial(addresses[channel]);
        sock.send(sender.toDoc.serialize, true);
    }

    void start_listening() {
        // NO IMPLEMENTATION NEEDED
    }
}
