import std.range;

@safe:

struct SortedArray(T) {

    T[] arr;

    this(T[] arr) pure nothrow {
        this.arr = arr;
    }

    ptrdiff_t findIndex(T k) pure nothrow @nogc {
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

    
    void insert(T data) {
        const index = findIndex(data);
        arr = arr[0..index] ~ [data] ~ arr[index..$];
    }

    void remove(T data) {
        const index = findIndex(data);
        if (index < arr.length && arr[index] == data) {
            arr = arr[0..index] ~ arr[index+1..$];
        }
    }
}


@safe 
unittest {
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
}
