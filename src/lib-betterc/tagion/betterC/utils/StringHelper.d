module tagion.betterC.utils.StringHelper;

import tagion.betterC.utils.Memory;
import std.traits;

string int_to_str(T)(T data) if (isIntegral!T) {
    Unqual!T mut_data = data;
    int data_size = decimal_place(mut_data);
    char[] res;
    res.create(data_size);
    auto pos = res.length - 1;
    while(mut_data > 0) {
        res[pos] =  cast(char)(data % 10 + '0');
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

const (char[])[] split_by_char(const (char)[] data, char splitter) {
    int count_char(const (char)[] data, char splitter) {
        int res = 1;
        size_t pos = 0;
        while (pos < data.length) {
            if (data[pos] == splitter) {
                res++;
                while(data[pos] == splitter) {
                    pos++;
                }
            }
            pos++;
        }
        return res;
    }

    size_t find_char(const (char)[] data, char symbol) {
        foreach(i, letter; data) {
            if (letter == symbol) {
                return i;
            }
        }
        return data.length;
    }

    const (char)[][] res;
    auto res_size = count_char(data, splitter);
    res.create(res_size);
    if (res_size != 1) {
        size_t split_pos = find_char(data, splitter);
        size_t start_pos = 0;
        size_t splits_num = 0;
        do {
            if(start_pos != split_pos) {
                res[splits_num] = data[start_pos .. split_pos];
                splits_num++;
            }
            start_pos = split_pos + 1;
            split_pos = split_pos + find_char(data[start_pos .. $], splitter);
        } while(split_pos < data.length);
    }
    else {
        res[0] = data[0 .. $];
    }
    return res;
}

//dummy function for test
extern(C) int foo(int a) {
    a = 1;
    return a;
}

// this(Document doc) {
//     Document doc - [ [Pubkey, bool], [] ,[] ]
//     forech(elem; doc) {
//         const tmp = elem.get!Document;
//         tmp[0].get!Buffer;
//         tmp[1].get!bool;
//     }


// }