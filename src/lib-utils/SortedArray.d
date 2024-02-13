import std.range;

@safe:

struct SortedArray(T) {

    T[] arr;

    this(T[] arr) pure nothrow {
        this.arr = arr;
    }

    ptrdiff_t findIndex(T k) pure nothrow @nogc {
        // if (arr.empty) { return 0; }
        ptrdiff_t start = 0;
        ptrdiff_t end = cast(ptrdiff_t) arr.length - 1;
        while (start <= end) {
            ptrdiff_t mid = (start + end) / 2;
            if (arr[mid] == k)
                return mid;
            else if (arr[mid] < k)
                start = mid + 1;
            else
                end = mid - 1;
        }
        return end + 1;
    }

    void insert(T data) {
        return;

    }

    void remove(T data) {
        return;

    }
}

unittest {

    assert(SortedArray!int([1, 3, 5, 6]).findIndex(2) == 1);
    int[] empty;
    assert(SortedArray!(int)(empty).findIndex(2) == 0);
    assert(SortedArray!(int)([4]).findIndex(2) == 0);
    assert(SortedArray!(int)([1, 1]).findIndex(1) == 0);
    assert(SortedArray!(int)([1]).findIndex(1) == 0);

}
