module tagion.utils.DList;

import tagion.utils.Result;

@safe struct DList(E) {
    @nogc struct Element {
        E entry;
        protected Element* next;
        protected Element* prev;
        this(E e) pure nothrow {
            entry = e;
        }
    }

    private Element* _head;
    private Element* _tail;
    // Number of element in the DList
    private uint count;
    Element* unshift(E e) nothrow {
        auto element = new Element(e);
        if (_head is null) {
            element.prev = null;
            element.next = null;
            _head = _tail = element;
        }
        else {
            element.next = _head;
            _head.prev = element;
            _head = element;
            _head.prev = null;
        }
        count++;
        return element;
    }

    Result!E shift() nothrow {
        if (_head is null) {
            return Result!E(E.init, this.stringof ~ " is empty");
        }
        scope (success) {
            _head = _head.next;
            _head.prev = null;
            count--;
        }
        return Result!E(_head.entry);
    }

    const(Element*) push(E e) nothrow {
        auto element = new Element(e);
        if (_head is null) {
            _head = _tail = element;
        }
        else {
            _tail.next = element;
            element.prev = _tail;
            _tail = element;
        }
        count++;
        return element;
    }

    Result!E pop() nothrow {
        Element* result;
        if (_tail !is null) {
            result = _tail;
            _tail = _tail.prev;
            if (_tail is null) {
                _head = null;
            }
            else {
                _tail.next = null;
            }
            count--;
            return Result!E(result.entry);

        }
        return Result!E(E.init, "Pop from an empty list");
    }

    /**
       Returns; true if the element was not found
     */
    @nogc
    bool remove(Element* e) nothrow
    in {
        assert(e !is null);
        if (_head is null) {
            assert(count == 0);
        }
        if (e.next is null) {
            assert(e is _tail);
        }
        if (e.prev is null) {
            assert(e is _head);
        }
    }
    do {
        if (_head is null) {
            return true;
            //            throw new UtilException("Remove from an empty list");
        }
        if (_head is e) {
            if (_head.next is null) {
                _head = _tail = null;
            }
            else {
                _head = _head.next;
                _head.prev = null;
                if (_head is _tail) {
                    _tail.prev = null;
                }
            }
        }
        else if (_tail is e) {
            _tail = _tail.prev;
            if (_tail is null) {
                _head = null;
            }
            else {
                _tail.next = null;
            }
        }
        else {
            e.next.prev = e.prev;
            e.prev.next = e.next;
        }
        count--;
        return false;
    }

    @nogc
    void moveToFront(Element* e) nothrow
    in {
        assert(e !is null);
    }
    do {
        if (e !is _head) {
            if (e == _tail) {
                _tail = _tail.prev;
                _tail.next = null;
            }
            else {
                e.next.prev = e.prev;
                e.prev.next = e.next;
            }
            e.next = _head;
            _head.prev = e;
            _head = e;
            _head.prev = null;
        }
    }

    @nogc
    uint length() pure const nothrow {
        return count;
    }

    @nogc inout(Element*) first() inout pure nothrow {
        return _head;
    }

    @nogc inout(Element*) last() inout pure nothrow {
        return _tail;
    }

    @nogc Range!false opSlice() pure nothrow {
        return Range!false(this);
    }

    @nogc Range!true revert() pure nothrow {
        return Range!true(this);
    }

    @nogc struct Range(bool revert) {
        private Element* cursor;
        this(DList l) pure nothrow {
            static if (revert) {
                cursor = l._tail;
            }
            else {
                cursor = l._head;
            }
        }

        bool empty() const pure nothrow {
            return cursor is null;
        }

        void popFront() nothrow {
            if (cursor !is null) {
                static if (revert) {
                    cursor = cursor.prev;
                }
                else {
                    cursor = cursor.next;
                }
            }
        }

        // void popBack() nothrow {
        //     if ( cursor !is null) {
        //         static if (revert) {
        //             cursor = cursor.next;
        //         }
        //         else {
        //             cursor = cursor.prev;
        //         }
        //     }
        // }

        E front() pure nothrow {
            return cursor.entry;
        }

        // alias back=front;

        inout(Element*) current() inout pure nothrow {
            return cursor;
        }
    }

    invariant {
        if (_head is null) {
            assert(_tail is null);
        }
        else {
            assert(_head.prev is null);
            assert(_tail.next is null);
            if (_head is _tail) {
                assert(_head.next is null);
                assert(_tail.prev is null);
            }
        }

    }
}

unittest {
    { // Empty element test
        DList!int l;
        //        auto e = l.shift;
        //        assert(e is null);
        // bool flag;
        assert(l.length == 0);
        {
            const r = l.pop;
            assert(r.error);
        }
        assert(l.length == 0);
        {
            const r = l.shift;
            assert(r.error);
        }
        assert(l.length == 0);
    }

    { // One element test
        DList!int l;
        l.unshift(7);
        assert(l.length == 1);
        auto first = l.first;
        auto last = l.last;
        assert(first !is null);
        assert(last !is null);
        assert(first is last);
        l.remove(first);
        assert(l.length == 0);
    }
    { // two element test
        DList!int l;
        assert(l.length == 0);
        l.unshift(7);
        assert(l.length == 1);
        l.unshift(4);
        assert(l.length == 2);
        auto first = l.first;
        auto last = l.last;
        assert(first.entry == 4);
        assert(last.entry == 7);
        // moveToFront test
        l.moveToFront(last);
        assert(l.length == 2);
        first = l.first;
        last = l.last;
        assert(first.entry == 7);
        assert(last.entry == 4);
    }
    { // pop
        import std.algorithm.comparison : equal;
        import std.array;

        DList!int l;
        enum amount = 4;
        int[] test;
        foreach (i; 0 .. amount) {
            l.push(i);
            test ~= i;
        }
        auto I = l[];
        // This statement does not work anymore
        // assert(equal(I, test));
        assert(array(I) == test);

        foreach_reverse (i; 0 .. amount) {
            assert(l.pop.value == i);
            assert(l.length == i);
        }
    }
    { // More elements test
        import std.algorithm.comparison : equal;

        DList!int l;
        enum amount = 4;
        foreach (i; 0 .. amount) {
            l.push(i);
        }
        assert(l.length == amount);

        { // Forward iteration test
            auto I = l[];
            uint i;
            for (i = 0; !I.empty; I.popFront, i++) {
                assert(I.front == i);
            }
            assert(i == amount);
            i = 0;
            I = l[];
            foreach (entry; I) {
                assert(entry == i);
                i++;
            }
            assert(i == amount);
        }

        assert(l.length == amount);

        import std.algorithm : map;
        import std.stdio;

        { // Backward iteration test
            auto I = l.revert;
            uint i;
            for (i = amount; !I.empty; I.popFront) {
                i--;
                assert(I.front == i);
            }
            assert(i == 0);
            i = amount;

            foreach (entry; l.revert) {
                i--;
                assert(entry == i);
            }
            assert(i == 0);
        }

        // moveToFront for the second element ( element number 1 )

        {
            import std.array;

            auto I = l[];
            I.popFront;
            auto current = I.current;
            l.moveToFront(current);
            assert(l.length == amount);
            // The element shoud now be ordred as
            // [1, 0, 2, 3]
            I = l[];
            // This statem does not work anymore
            // assert(equal(I, [1, 0, 2, 3]));
            assert(array(I) == [1, 0, 2, 3]);
        }

        {
            import std.array;

            auto I = l[];
            I.popFront;
            I.popFront;
            auto current = I.current;
            l.moveToFront(current);
            assert(l.length == amount);
            // The element shoud now be ordred as
            // [1, 0, 2, 3]
            I = l[];
            // This statem does not work anymore
            // assert(equal(I, [2, 1, 0, 3]));
            assert(array(I) == [2, 1, 0, 3]);
        }

    }
}
