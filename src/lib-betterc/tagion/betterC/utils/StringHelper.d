module tagion.betterC.utils.StringHelper;

import std.traits;
import tagion.betterC.utils.Memory;

string int_to_str(T)(T data) if (isIntegral!T) {
    Unqual!T mut_data = data;
    int data_size = decimal_place(mut_data);
    char[] res;
    res.create(data_size);
    auto pos = res.length - 1;
    while (mut_data > 0) {
        res[pos] = cast(char)(data % 10 + '0');
        mut_data /= 10;
        pos++;
    }
    return cast(string)(res);
}

int decimal_place(T)(T data) {
    auto tmp_data = data;
    int count = 0;
    do {
        tmp_data /= 10;
        count++;
    }
    while (tmp_data > 0);
    return count;
}

int count_pieces(const(char)[] data, char splitter) {
    int res = 1;
    size_t pos = 0;
    while (pos < data.length) {
        if (data[pos] == splitter) {
            res++;
            while (data[pos] == splitter) {
                pos++;
            }
        }
        pos++;
    }
    return res;
}

size_t find_next_char(const(char)[] data, char symbol, size_t start_pos) {
    for (size_t i = start_pos + 1; i < data.length; i++) {
        if (data[i] == symbol) {
            return i;
        }
    }
    return data.length;
}

const(char[])[] split_by_char(const(char)[] data, char splitter) {
    const(char)[][] res;
    auto res_size = count_pieces(data, splitter);
    res.create(res_size);
    if (res_size != 1) {
        size_t start_pos = 0;
        size_t split_pos = find_next_char(data, splitter, start_pos);
        size_t splits_num = 0;
        do {
            if (start_pos < split_pos) {
                res[splits_num] = data[start_pos .. split_pos];
                splits_num++;
            }
            start_pos = split_pos + 1;
            split_pos = find_next_char(data, splitter, split_pos);
        }
        while (start_pos < data.length);
    }
    else {
        res[0] = data[0 .. $];
    }
    return res;
}

void append(T)(ref T[] arr, T value) {
    auto arr_length = arr.length;
    // arr.length += 1;

    T[] tmp_arr;
    tmp_arr.create(arr_length + 1);
    tmp_arr[0 .. $ - 1] = arr[0 .. $];
    arr.dispose;
    arr = tmp_arr;
    // tmp_arr.dispose;
    // arr_length += 1;
    // arr.resize(arr_length);
    arr[$ - 1] = value;
}

T pop_back(T)(ref T[] arr)
in {
    assert(arr.length > 0);
}
do {
    auto result = arr[$ - 1];
    auto arr_length = arr.length;
    arr.resize(arr_length - 1);
    return result;
}

unittest {
    // no need to split
    // {
    //     string test = "123";
    //     auto res = split_by_char(test, ',');
    //     string[] exp_res;
    //     exp_res ~= "123";
    //     // exp_res ~= "321";
    //     assert(res == exp_res);
    // }
    // //find next char pos
    // {
    //     string test = "012,4,6";
    //     size_t pos = find_next_char(test, ',', 0);
    //     auto count = count_pieces(test, ',');

    //     assert(count == 3);

    //     assert(pos == 3);
    //     pos = find_next_char(test, ',', pos);
    //     assert(pos == 5);

    //     pos = find_next_char(test, ',', pos);
    //     assert(pos == test.length);
    // }
    // // one spliter
    // {
    //     string test = "123,321";
    //     auto res = split_by_char(test, ',');
    //     string[] exp_res;
    //     exp_res ~= "123";
    //     exp_res ~= "321";
    //     assert(res == exp_res);
    // }
    // // one spliter many times
    // {
    //     string test = "123,,,,,,321";
    //     auto res = split_by_char(test, ',');
    //     string[] exp_res;
    //     exp_res ~= "123";
    //     exp_res ~= "321";
    //     assert(res == exp_res);
    // }
    // // more spliters
    // {
    //     string test = "12,3,3,,,2,,1";
    //     auto res = split_by_char(test, ',');
    //     string[] exp_res;
    //     exp_res ~= "12";
    //     exp_res ~= "3";
    //     exp_res ~= "3";
    //     exp_res ~= "2";
    //     exp_res ~= "1";
    //     assert(res == exp_res);
    // }
}

// this(Document doc) {
//     Document doc - [ [Pubkey, bool], [] ,[] ]
//     forech(elem; doc) {
//         const tmp = elem.get!Document;
//         tmp[0].get!Buffer;
//         tmp[1].get!bool;
//     }

// }
