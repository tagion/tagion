module tagion.mobile.Recycle;

struct Recycle(T) {
    pragma(msg, "fixme(cbr): Why is it offset by one with (START_INDEX = 1) ?");
    enum START_INDEX = 1;

    enum to_index = (uint i) => cast(const(uint))(i + START_INDEX);
    enum to_doc_id = (uint i) => cast(const(uint))(i - START_INDEX);

    private {
        T[] _active;
        const(uint)[] _reuse;
    }

    /// Create an object of T and return it's index in '_active'
    const(uint) create(T x) {
        if (_reuse.length > 0) {
            const reuse_id = _reuse[$ - 1];
            _reuse.length--;
            _active[reuse_id] = x;
            return to_index(reuse_id);
        }
        _active ~= x;
        return to_index(cast(uint) _active.length - 1);
    }

    bool put(T x, const uint id) {
        if (exists(id)) {
            const doc_id = to_doc_id(id);
            _active[doc_id] = x;
            return true;
        }
        return false;
    }

    /// Erase by index
    void erase(const uint id)
    in {
        const doc_id = to_doc_id(id);
        assert(doc_id >= 0);
        assert(doc_id < _active.length);
    }
    do {
        const doc_id = to_doc_id(id);
        import std.algorithm.searching : count;

        _active[doc_id] = T.init;
        // Check for avoiding the multiple append the same id
        if (_reuse.count(doc_id) is 0) {
            _reuse ~= doc_id;
        }
    }

    /// overloading function call operator
    T opCall(const uint id)
    in {
        const doc_id = to_doc_id(id);
        assert(doc_id < _active.length);
        assert(_active[doc_id]!is T.init);
    }
    do {
        const doc_id = to_doc_id(id);
        return _active[doc_id];
    }

    /// Checking for existence by id
    bool exists(const uint id) const pure nothrow {
        const doc_id = to_doc_id(id);
        if (doc_id < _active.length) {
            return _active[doc_id]!is T.init;
        }
        return false;
    }
}

pragma(msg, "fixme(cbr): This unittest does not pass (", __FILE__, ":", __LINE__, ")");
version (none) unittest {
    import std.stdio;
    import tagion.hibon.Document : Document;

    // import std.stdio : writeln;
    /**
     * create Documents' recycler;
     * get the indexes with calling 'create()' method
     * of the Recycle object
    */
    Recycle!Document recycler;
    immutable(ubyte[]) doc1_data = [1, 2, 3];
    auto doc1 = Document(doc1_data);

    const doc_id = recycler.create(doc1);
    assert(doc_id is 0);

    recycler.erase(doc_id);
    assert(!recycler.exists(doc_id));

    const doc1_id = recycler.create(doc1);

    immutable(ubyte[]) doc2_data = [2, 3, 4];
    auto doc2 = Document(doc2_data);
    const doc2_id = recycler.create(doc2);

    immutable(ubyte[]) doc3_data = [3, 4, 5];
    auto doc3 = Document(doc3_data);
    const doc3_id = recycler.create(doc3);

    // test for calling Documents by id's
    assert(doc1 is recycler(doc1_id));
    assert(doc2 is recycler(doc2_id));
    assert(doc3 is recycler(doc3_id));

    // test for calling exists() method
    assert(recycler.exists(doc1_id));
    assert(recycler.exists(doc2_id));
    assert(recycler.exists(doc3_id));

    // test for calling erase() method
    recycler.erase(doc2_id);
    assert(!recycler.exists(doc2_id));
    recycler.erase(doc1_id);
    assert(!recycler.exists(doc1_id));

    // create a new Documents doc4 and doc5
    immutable(ubyte[]) doc4_data = [5, 6, 7];
    auto doc4 = Document(doc4_data);
    const doc4_id = recycler.create(doc4);

    immutable(ubyte[]) doc5_data = [6, 7, 8];
    auto doc5 = Document(doc5_data);
    const doc5_id = recycler.create(doc5);

    /**
     * And check indexes for equality with
     * created before doc1 and doc2
    */
    assert(doc1_id is doc4_id);
    assert(doc2_id is doc5_id);

    /**
     * Check ref changes
    */
    import std.algorithm;

    immutable(ubyte)[] doc6_data = [5, 6, 7];
    auto doc6 = Document(doc6_data);
    const doc6_id = recycler.create(doc6);
    doc6_data ~= 8;
    auto same_doc = recycler(doc6_id);
    assert(equal(doc6.serialize, same_doc.serialize));
}
