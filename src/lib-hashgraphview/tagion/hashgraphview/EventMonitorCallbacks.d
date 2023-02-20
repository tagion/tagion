/// HashGraph basic support functions
module tagion.hashgraphview.EventMonitorCallbacks;

import tagion.basic.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.hibon.HiBONType;
import tagion.hibon.Document : Document;


/// HashGraph monitor call-back interface
@safe
interface EventMonitorCallbacks {
    nothrow {
        void connect(const(Event) e);
        void witness(const(Event) e);
        void witness_mask(const(Event) e);
        void round_seen(const(Event) e);
        void round(const(Event) e);
        void round_decided(const(Round.Rounder) rounder);
        void round_received(const(Event) e);
        void famous(const(Event) e);
        void round(const(Event) e);
        //        void son(const(Event) e);
        //       void daughter(const(Event) e);
        //        void forked(const(Event) e);
        void epoch(const(Event[]) received_event);
        void send(const Pubkey channel, lazy const Document doc);
        final void send(T)(const Pubkey channel, lazy T pack) if (isHiBONType!T) {
            send(channel, pack.toDoc);
        }

        void receive(lazy const Document doc);
        final void receive(T)(lazy const T pack) if (isHiBONType!T) {
            receive(pack.toDoc);
        }
    }
}

