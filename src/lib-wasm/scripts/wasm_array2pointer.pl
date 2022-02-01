#!/usr/bin/perl -i.bak
while(<>) {
    s/const\(wasm_val_t\)\[\]/const\(wasm_val_t\)\*/g;
    s/ wasm_val_t\[\]/ wasm_val_t\*/g;
    print;
}
