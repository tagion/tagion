module tagion.basic.range;
import std.range;

@safe:
/**
* Tries to do a front but it is empty it return T.init 
* Returns:
* If the range is not empty the first element is return
* else the .init value of the range element type is return
* The first element is returned
*/
T doFront(Range, T = ElementType!Range)(Range r, T default_value = T.init) if (isInputRange!Range) {
    if (r.empty || r is Range.init) {
        return default_value;
    }
    return r.front;
}

///
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
T eatOne(Range, T = ElementType!Range)(ref Range r, T default_value = T.init) if (isInputRange!Range) {

    if (r.empty) {
        return default_value;
    }
    scope (exit) {
        if (!r.empty) {
            r.popFront;
        }
    }
    return r.front;
}

////
unittest {
    const(int)[] a = [1, 2, 3];
    assert(eatOne(a) == 1);
    assert(eatOne(a) == 2);
    assert(eatOne(a) == 3);
    assert(a.empty);
    assert(eatOne(a, -1) == -1);
    assert(eatOne(a) == int.init);
}
