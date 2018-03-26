module tagion.hashgraph.Frame;

import tagion.hashgraph.Root;
import tagion.hashgraph.Event;

struct Frame(H) {
    Root[H] Roots;
    Event[] Events;
}
