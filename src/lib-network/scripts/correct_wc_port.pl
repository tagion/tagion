#!/usr/bin/env perl -i.bak 
#  Correct numbers

my $c_std_funcs = join("|",
    "fopen",
    "fdopen",
    "fseek",
    "ftell",
    "rewind",
    "fread",
    "fwrite",
    "fclose",
    "fprint",
    "fflush",
    "write",
    "read",
    "close",
    "fget",
    "vfprintf",
    "fput",
    "sprintf",
    "vsnprintf",
    "stat",
);

while (<>) {
    s/^(\s*)enum(\s+\w+\s+=\s+($c_std_funcs))/$1alias$2/;
    s/^(\s*enum\s+\w+\s*=\s*)NULL(;)/$1null$2/;
    # Hack for linux/posix systems
    s/^(alias\s+wolfSSL_Mutex\s+=\s+)[\w_\d]+(;)/$1pthread_mutex_t$2/;
    s/(^alias\s+(XFDOPEN|XVALIDATE_DATE)\s*=)/\/\/ DSTEP: $1/;
    print;
}


