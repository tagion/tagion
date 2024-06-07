#!/usr/bin/env -S perl -i.bak 
#  Correct numbers

while (<>) {
    s/enum\s+(wasm_\w+\s+=)/alias $1/;
    s/(\bwasm_byte_vec\b)/$1_t/g;
    s/^(struct wasm_val_t)/version(none) $1/;
    s/^(struct wasm_val_vec_t)/version(none) $1/;
    print;
}


