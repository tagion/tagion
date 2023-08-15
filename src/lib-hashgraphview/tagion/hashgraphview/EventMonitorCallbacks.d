/// HashGraph basic support functions
module tagion.hashgraphview.EventMonitorCallbacks;

import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.hibon.HiBONRecord;
import tagion.hibon.Document : Document;

/// HashGraph monitor call-back interface
@safe
interface EventMonitorCallbacks {
    nothrow {
        void connect(const(Event) e);
        void witness(const(Event) e);
        // void round_seen(const(Event) e);
        void round(const(Event) e);
        void round_decided(const(Round.Rounder) rounder);
        void round_received(const(Event) e);
        void famous(const(Event) e);
        void round(const(Event) e);
        void remove(const(Event) e);
        //        void son(const(Event) e);
        //       void daughter(const(Event) e);
        //        void forked(const(Event) e);
        void epoch(const(Event[]) received_event);
        void send(const Pubkey channel, lazy const Document doc);
        final void send(T)(const Pubkey channel, lazy T pack) if (isHiBONRecord!T) {
            send(channel, pack.toDoc);
        }

        void receive(lazy const Document doc);
        final void receive(T)(lazy const T pack) if (isHiBONRecord!T) {
            receive(pack.toDoc);
        }
    }
}
