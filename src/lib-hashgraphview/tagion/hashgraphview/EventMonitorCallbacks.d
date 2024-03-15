/// HashGraph basic support functions
module tagion.hashgraphview.EventMonitorCallbacks;

import tagion.crypto.Types : Pubkey;
import tagion.hashgraph.Event;
import tagion.hashgraph.Round;
import tagion.hibon.Document : Document;
import tagion.hibon.HiBONRecord;

/// HashGraph monitor call-back interface
@safe
interface EventMonitorCallbacks {
    nothrow {
        void connect(const(Event) e);
        void witness(const(Event) e);
        void round(const(Event) e);
        void famous(const(Event) e);
        void remove(const(Event) e);

        // Unused callbacks, will they be used in the future? - Lucas
        /* void round_decided(const(Round.Rounder) rounder); */
        /* void round_received(const(Event) e); */
        /* void epoch(const(Event[]) received_event); */
    }
}
