module bakery.hashgraph.Frame;

import bakery.hashgraph.Root;
import bakery.hashgraph.Event;

struct Frame(H) {
    Root[H] Roots;
    Event[] Events;
}
