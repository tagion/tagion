module tagion.basic.range;
import std.range.primitives : isInputRange;
import std.traits : ForeachType;

/**
* Tries to do a front but it is empty it return T.init 
* Returns:
* If the range is not empty the first element is return
* else the .init value of the range element type is return
* The first element is returned
*/
template doFront(Range) if (isInputRange!Range) {
    alias T = ForeachType!Range;
    import std.range;

    T doFront(Range r) @safe {
        if (r.empty || r is Range.init) {
            return T.init;
        }
        return r.front;
    }
}

///
@safe
unittest {
    {
        int[] a;
        static assert(isInputRange!(typeof(a)));
        assert(a.doFront is int.init);
    }
    {
        const a = [1, 2, 3];
        assert(a.doFront is a[0]);
    }

}

/**
 * Returns the first element in the range r and pops then next
 * Params:
 *   r =range
 * Returns: r.front
 */
auto eatOne(R)(ref R r) if (isInputRange!R) {
    import std.range;

    scope (exit) {
        if (!r.empty) {
            r.popFront;
        }
    }
    return r.front;
}

///
unittest {
    const(int)[] a = [1, 2, 3];
    assert(eatOne(a) == 1);
    assert(eatOne(a) == 2);
    assert(eatOne(a) == 3);
}

/** 
 * Returns the first element in the range r and pops the element. 
 * If the range is empty then it returns T.init.
 * Params:
 *   Range = range 
 */
template doEatFront(Range) if (isInputRange!Range) {
    alias T = ForeachType!Range;
    import std.range;

    T doEatFront(ref Range r) @safe {
        if (r.empty) {
            return T.init;
        }
        scope (exit) {
            r.popFront;
        }
        return r.front;
    }

}

@safe
unittest {
    {
        int[] a;
        static assert(isInputRange!(typeof(a)));
        assert(a.doEatFront is int.init);
    }
    {
        int[] a = [1, 2, 3];

        assert(a.doEatFront == 1);
        assert(a.length == 2);
        assert(a.doEatFront == 2);
        assert(a.length == 1);
        assert(a.doEatFront == 3);
        assert(a.length == 0);
        assert(a.doEatFront is int.init);
    }
}
