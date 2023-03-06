module tagion.testbench.tools.FileName;

import std.random : uniform;

string generateFileName(int file_name_length) {
    string result = "";
    const string characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
    for (int i = 0; i < file_name_length; i++) {
        result ~= characters[uniform(0, characters.length)];
    }
    return result;
}