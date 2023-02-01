module tagion.betterC.mobile.Recycle;

import tagion.betterC.utils.Memory;
import tagion.betterC.utils.StringHelper;

struct Recycle(T) {
    private {
        T[] _active;
        uint[] _reuse;
    }

    /// Create an object of T and return it's index in '_active'
    const(uint) create(T x) {
        import core.stdc.stdio;

        if (_reuse.length > 0) {
            const reuse_id = _reuse.pop_back();
            _active[reuse_id] = x;
            return reuse_id;
        }
        // _active ~= x;
        pragma(msg, "create ", T);
        _active.append(x);
        return cast(uint) _active.length - 1;
    }

    bool put(T x, const uint id) {
        bool result = false;

        if (exists(id)) {
            _active[id] = x;
            result = true;
        }
        return result;
    }

    /// Erase by index
    void erase(const uint id)
    in {
        assert(id >= 0);
        assert(id < _active.length);
    }
    do {
        import std.algorithm.searching : count;

        _active[id] = T.init;
        // Check for avoiding the multiple append the same id
        if (_reuse.count(id) is 0) {
            _reuse.append(id);
        }
    }

    /// overloading function call operator
    T opCall(const uint id)
    in {
        assert(id < _active.length);
        assert(_active[id]!is T.init);
    }
    do {
        return _active[id];
    }

    /// Checking for existence by id
    bool exists(const uint id) const nothrow {
        if (id < _active.length) {
            return _active[id]!is T.init;
        }
        return false;
    }
}

// unittest {
//     import tagion.betterC.hibon.HiBON;
//     import tagion.betterC.hibon.Document;

//     import core.stdc.stdio;

//     auto hibon = HiBON();
//     Document doc = Document(hibon.serialize);
//     Recycle!Document recycler;
//     auto doc_id = recycler.create(doc);
//     // printf("%u\n", res);

//     assert(recycler.exists(doc_id));
//     assert(doc == recycler(doc_id));

//     Document doc1 = Document(hibon.serialize);
//     auto doc1_id = recycler.create(doc1);

//     assert(doc1_id != doc_id);
//     assert(recycler.exists(doc1_id));
//     assert(doc == recycler(doc1_id));

//     recycler.erase(doc1_id);
//     assert(!recycler.exists(doc1_id));
// }
