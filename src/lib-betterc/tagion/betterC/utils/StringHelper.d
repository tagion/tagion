module tagion.betterC.utils.StringHelper;

import tagion.betterC.utils.Memory;

string int_to_str(T)(T data) {
    int data_size = decimal_place(data);
    char[] res;
    res.create(data_size);
    auto pos = res.length - 1;
    while(data > 0) {
        res[pos] =  cast(char)(data % 10 + '0');
        data /= 10;
        pos++;
    }
    return cast(string)(res);
}

int decimal_place(T)(T data) {
    int count = 0;
    do {
        data /= 10;
        count++;
    }
    while (data > 0);
    return count;
}