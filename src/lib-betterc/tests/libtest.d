/**
 * HiBON Document
 *
 */
module libtest;

extern(C):

@nogc:

import core.stdc.stdio;
int test_func(int x) {
    printf("x=%d\n", x);
    return 3*x;
}
