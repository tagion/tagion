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