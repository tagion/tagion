module tagion.dart.BlockSegmentAllocator;

import tagion.basic.Types : Buffer;
import tagion.hibon.HiBONRecord : HiBONRecord, recordType, label;
import tagion.hibon.Document;

import tagion.hibon.HiBON : HiBON;
import tagion.dart.BlockFile : Index;
import tagion.basic.Version : not_unittest;

enum random = not_unittest;

/++
     + This object handles the allocation data-buffer.
     + By splitting the data buffer into a chain of blocks
     + If possible it recycling old deleted blocks
     +/
version(none)
@safe
class AllocatedChain {
    @recordType("ACHAIN") struct Chain {
        Buffer data;
        Index begin_index;
        mixin HiBONRecord;
    }

    protected Chain chain;
    this(const Document doc) {
        chain = Chain(doc);
    }

    inout(HiBON) toHiBON() inout {
        return chain.toHiBON;
    }

    final immutable(Buffer) data() const pure nothrow {
        return chain.data;
    }
    // This function reserves blocks and recycles blocks if possible
    protected void reserve(bool random_block)()
    in {
        assert(chain.begin_index == 0, "Block is already reserved");
    }
    do {
        immutable size = number_of_blocks(chain.data.length);
        chain.begin_index = Index(recycler.reserve_segment!random_block(size));
        _statistic(size);
    }

    this(immutable(Buffer) buffer, immutable bool random_block = random)
    in {
        assert(buffer.length > 0, "Buffer size can not be zero");
    }
    do {
        chain.data = buffer;
        if (random_block) {
            reserve!true;
        }
        else {
            reserve!false;
        }
    }

    string toInfo() const {
        return format("[%d..%d] blocks=%s size=%5d", chain.begin_index, end_index, number_of_blocks(
                size), size);
    }

final:

    Index begin_index() pure const nothrow {
        return chain.begin_index;
    }

    Index end_index() pure const nothrow {
        return Index(chain.begin_index + number_of_blocks(chain.data.length));
    }

    uint size() pure const nothrow {
        import LEB128 = tagion.utils.LEB128;

        const leb128_size = LEB128.decode!ulong(chain.data);
        return cast(uint)(leb128_size.size);
    }

}
