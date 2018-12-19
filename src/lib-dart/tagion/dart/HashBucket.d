module tagion.vault.HashBucket;

import tagion.utils.BSON : Document, HBSON;

class HashBucket(Block) {
    private Buffer[] _buffers;
    private RequestNet _reguest_net;
    this(RequestNet reguest_net, Document[] documents) {
        _reguest_net=reguest_net;
        _documents=documents;
    }
    this(RequestNet reguest_net,  ref File fin) {
        _reguest_net=reguest_net;
        _documents=documents;
    }
    private void load(ref File fin) {
        while ( !fin.eof ) {

        }
    }

    HBSON toBSON() const {
        auto bson=new HBSON[_document.length];
        foreach(i, d; _documents) {
            bson[i]=d;
        }
        return bson;
    }

    immutable(ubyte[]) serialize() const {
        return toBSON(use_event).serialize;
    }

}
