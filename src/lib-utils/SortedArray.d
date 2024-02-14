import std.range;
import core.stdc.string : memcpy;

@safe:

struct SortedArray(T) {
    T[] arr;

    this(T[] arr) pure nothrow {
        this.arr = arr;
    }

    private ptrdiff_t findIndex(T k) pure nothrow @nogc {
        ptrdiff_t start = 0;
        ptrdiff_t end = cast(ptrdiff_t) arr.length - 1;
        while (start <= end) {
            ptrdiff_t mid = (start + end) / 2;
            if (arr[mid] == k) {
                return mid;
            }
            else if (arr[mid] < k) {
                start = mid + 1;
            }
            else {
                end = mid - 1;
            }
        }
        return end + 1;
    }

    @trusted
    void insert(T data) nothrow pure {
        const index = findIndex(data);
        arr.length++;
        if (index < cast(ptrdiff_t) arr.length - 1) {
            const byte_size = (arr.length - index - 1) * T.sizeof;
            memcpy(&arr[index + 1], &arr[index], byte_size);
        }
        arr[index] = data;
    }

    @trusted
    void remove(T data) nothrow pure {
        const index = findIndex(data);
        if (index < arr.length) {
            arr.length--;
            if (index < arr.length) {
                const byte_size = (arr.length - index) * T.sizeof;
                memcpy(&arr[index], &arr[index + 1], byte_size);
            }
        }
    }
}

@safe
unittest {
    import std.stdio;

    assert(SortedArray!int([1, 3, 5, 6]).findIndex(2) == 1);
    int[] empty;
    assert(SortedArray!(int)(empty).findIndex(2) == 0);
    assert(SortedArray!(int)([4]).findIndex(2) == 0);
    assert(SortedArray!(int)([1, 1]).findIndex(1) == 0);
    assert(SortedArray!(int)([1]).findIndex(1) == 0);

    // Test insert
    SortedArray!int insert_arr = SortedArray!int([1, 3, 5, 6]);
    insert_arr.insert(4);
    assert(insert_arr.arr == [1, 3, 4, 5, 6]);
    insert_arr.insert(2);
    assert(insert_arr.arr == [1, 2, 3, 4, 5, 6]);
    insert_arr.insert(7);
    assert(insert_arr.arr == [1, 2, 3, 4, 5, 6, 7]);

    // Test remove
    SortedArray!int remove_arr = SortedArray!int([1, 2, 3, 4, 5, 6, 7]);
    remove_arr.remove(4);
    assert(remove_arr.arr == [1, 2, 3, 5, 6, 7]);
    remove_arr.remove(1);
    assert(remove_arr.arr == [2, 3, 5, 6, 7]);
    remove_arr.remove(7);
    assert(remove_arr.arr == [2, 3, 5, 6]);
    // Test remove last element
    SortedArray!int remove_last = SortedArray!int([1, 2, 3, 4, 5, 6]);
    remove_last.remove(6);
    assert(remove_last.arr == [1, 2, 3, 4, 5]);



    int[] empty_test;

    SortedArray!int same_elements = SortedArray!int(empty_test);
    same_elements.insert(5);
    same_elements.insert(5);
    same_elements.insert(5);
    assert(same_elements.arr.length == 3, "should be 3 long");
    

}
