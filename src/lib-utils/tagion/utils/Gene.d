module tagion.utils.Gene;

@safe
uint gene_count(const ulong bitstring) {
     //enum BIT_TABLE_SIZE=ubyte.max+1;
     static count_ones(const ulong x) pure {
          if ( x == 0 ) {
               return 0
                   }
          else {
               return (x & 1) + count_ones(x >> 1);
          }
     }
     static build_bit_count_table(uint BIT_TABLE_SIZE)() pure {
          uint[BIT_TABLE_SIZE] table;
          foreach(i; table) {
               immutable bit_string=cast(ulong)i;
               table[i]=count_ones(bit_string);
          }
     }
     enum BIT_COUNT_TABLE=build_bit_count_table!(ubyte.max+1);
     static uint count_ones(size_t BITS=ulong.size*8)(const ulong x) pure {
          if ( x == 0 ) {
               return 0;
          }
          else if (x <= BIT_COUNT_TABLE.length) {
               return BIT_COUNT_TABLE[x];
          }
          else {
               enum HALF_BITS=BITS/2;
               enum MASK=(1 << (HALF_BITS))-1;
               return count_ones!(HALF_BITS)(x & MASK) + count_ones!(HALF_BITS)((x >> HALF_BITS) & MASK);
          }
     }
     return count_ones(bitstream);
}

@safe
uint gene_count(const(ulong[]) bitstream) pure {
     uint result;
     foreach(x; bitstream) {
          result+=gene_count(x);
     }
}

@trusted
immutable(ulong[]) gene_xor(const(ulong[]) a, const(ulong[]) b) pure
in {
     assert(a.length == b.length);
}
do {
     ulong[] result;
     result.length=a.length;
     // NoBound check
     foreach(i; 0..a.length) {
          *(result.ptr+i) = *(a.ptr+i)^*(b.ptr+i);
     }
     return result;
}
