#!/usr/bin/env -S perl -i.bak 
#  Correct numbers

while (<>) {
    s/enum\s+(wasm_\w+\s+=)/alias $1/;
    s/(\bwasm_byte_vec\b)/$1_t/g;
    print;
    if (m/_Anonymous_0 of;/) {
        print "    mixin wasm_val_this;\n";
    }
    if (m/wasm_val_t\* data;/) {
        print "    mixin wasm_val_vec_this;\n";
    }
}


