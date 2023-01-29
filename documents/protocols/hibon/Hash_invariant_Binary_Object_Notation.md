This is something
: This is definition for that thing
: something else

# Hash invariant Binary Object Notation

HiBON is a streamable data format which are able to contain common binary data types.

Pronounced Haibon

 ## Description of the binary package format

The HiBON  binary format describe here in pseudo-BNF format. 

### Basic Types

| Type name | Type description                                         |
| --------- | -------------------------------------------------------- |
| int       | signed 32 integer                                        |
| long      | signed 64 integer                                        |
| uint      | unsigned 32 integer                                      |
| ulong     | unsigned 64 integer                                      |
| float     | 32-bit IEEE 754-2008 binary floating point               |
| double    | 64-bit IEEE 754-2008 binary floating point               |
| utf8*     | is defined as a string of characters in UTF-8 format     |
| char*     | is defined as a string of characters in ASCII format     |
| byte*     | is defined as a string of bytes                          |
| i32       | signed 32 integer in leb128 format                       |
| i64       | signed 32 integer in leb128 format                       |
| u32       | unsigned 32 integer in leb128 format                     |
| u32       | unsigned 64 integer in leb128 format                     |
| f32       | float in little endian format                            |
| f64       | double in little endian format                           |
| len       | is a length file as u32 except the '\x00' is not allowed |
| null      | is defined as '\x00'                                     |



```
document   ::= null | len list        // len in bytes contained in the list
                                      // null value means the the document is empty
list       ::= element list
key        ::= key_index | key_string // Member key either as a u32 or text
element    ::=                        // TYPE key value
      FLOAT64 key f64  
    | FLOAT32 key f32 
 	| STRING key string
 	| DOCUMENT key document
 	| BINARY key binary
 	| BOOLEAN key ('\x00'|'\x01')
 	| SDT key i64              // Standard Time counted as the total 100nsecs from midnight, 
 	                           // January 1st, 1 A.D. UTC.
    | INT32 key i32
    | INT64 key i64
    | BIGINT key ibig
    | UINT32 key u32
    | UINT64 key u64
    | CUSTOM key document       // Used to define none standard costume types
                                // document is array where the first element is
                                // contains the name of the type and the value data
    | HASHDOC key hashdoc       // Is the hash pointer to a HiBON 
    | CRYPTDOC key cryptdoc     // Is the encrypted HiBON document 
    | CREDENTIAL key credentail // Used to store public key and/or signatures
    | VER u32             // This field sets the version
    | RFU
    | ERROR
// Data types
string     ::= len utf8*       // Array of UTF-8 containg len elements
binary     ::= len byte*       // Array of byte containg len elements
// All number types is stored as little endian
u32        ::= leb128!uint     // leb128 decoded to a 32 bits unsigend integer
i32        ::= leb128!int      // leb128 decoded to a 32 bits sigend integer
u64        ::= leb128!ulong    // leb128 decoded to a 64 bits unsigend integer
i32        ::= leb128!long     // leb128 decoded to a 64 bits sigend integer
f32        ::= decode!float    // 32 bits floatingpoint
f64        ::= decode!double   // 64 bits floatingpoint
bigint     ::= len uint[] sign // Contains a big-integer value stored on multible of 4 bytes which represents
                               // unsigned integer in little endian format and the sign
                               // Only valid if ( len % 4 == 1 && len >= 4 )
sign       ::= '\x00' | '\x01' // Set the sign of the bigint (none two complement)
binary     ::= len ubyte*      // Byte array of the length len
string     ::= len char*       // utf-8 array of the length len
hashdoc    ::= datablock
cryptdoc   ::= datablock
credential ::= datablock
datablock  ::= u32 binary      // The first field set the type and binary data
// Length fields
len        ::= leb128!uint     // Same a u32 except null value is accepted
null       ::= '\x00'          // Define as one byte with the value of zero
// key format
key_index  ::= null u32     // Defined the key as an unsigend 32 bits number used for document arrays
key_string ::= len key_text   // Is a key subset of the ascii see rule 1. 
// Type codes
FLOAT64    ::= '\x01'
FLOAT32    ::= '\x21'
STRING     ::= '\x02'
DOCUMENT   ::= '\x03'
BINARY     ::= '\x05'
CRYPTDOC   ::= '\x06'
BOOLEAN    ::= '\x08'
UTC        ::= '\x09'
INT32      ::= '\x10'
INT64      ::= '\x12'
UINT32     ::= '\x20'
UINT64     ::= '\x22'
HASHDOC    ::= '\x23'
BIGINT     ::= '\x1B'
CREDENTIAL ::= '\x1F'
CUSTOM     ::= '\x23'
VER        ::- '\x3F'
// Following types must result in an format error
RFC        ::= '\x40' | '\x7e' | '\x80' | '\xC3' | '\xFE' | '\xC2' | '\x13'
ERROR      ::= others 
```



## Compliment rules

#### A. Rules for key objects and array

1. A HiBON package is defined as complete Document including the first length 'len'.

2. An empty HiBON defined with a size of 1 byte and the value of '\x00'.

3. The member key can be either an index as a u32 number or as a ASCII text.

4. If the len of the key has the value '\x00' then the key is u32 number.

5. if then len of the key has a value greater than zero then the key is represented as an ASCII string of the length len.

6. An HiBON is defined as an Array only if all the keys is a number u32 and the keys are defined as indices.  

7. An HiBON all indices most be counting order starting from index 0 to be defined as an Array.

8. If one or more keys is not a u32 number then the HiBON is defined as an Object.

9. If the HiBON is empty the it is defined as both an Object and Array.

10. All keys most be ordered according to the **is_key_ordered** algorithm.

11. All keys most comply with **in_key_valid** algorithm.

12. A keys is defined to be an index according to the **is_index** algorithm.

13. All keys must be unique this means that no key in a HiBON is allowed to have the same value.

14. The VER filed most be the first field in the recorder.

15. The VER of the value '\x00' is not allow. 

16. If the version filed is not available the HiBON version is the same as the parent HiBON.

17. If the VER field is not set the default version is zero.

    

#### B. Rules for types

1. BOOLEAN type must only contain '\x00' for false and '\x01' for true other values are not allowed

2. The size of a BOOLEAN is one byte

3. The size of a STRING can be zero or more

4. The size of a BINARY can be zero or more

5. STD is standard time counted as the total 100nsecs from midnight, January 1st, 1 A.D. UTC. and is stored as i64

6. The size of BIGINT must be a multiple of 4 bytes plus one of the signed

8. The last byte in BIGINT format is the sign byte

9. The sign byte in BIGINT format must only contain '\x00' for positive value and '\x01' for negative value other values are not allowed

10. The UNIQUE contains a cryptographically value such as a hash pointer to a HiBON, a public key or a digital signature the u32 value selects the hash function type (null is sha256)

11. The user time must alway contain a Document.

    

#### C. Algorithm Rules

In the section the rules for the key is describes.

#### is_key_valid

A valid key must comply with following regular expression.

`^[\!\#-\&\(-\+\--\_a-\~]$`     

This includes all ASCII characters from '\x21' until '\x7E' except for white space charters and quotes.

The flowing ASCII chars are not allowed for '\x00' to '\x20' and all ASCII value larger than 'x7E' and `['\x22', '\x27', '\x2C', '\x60' ]`

 *Example code is_key_valid function in D*



```D
/++
 Returns:
 true if the key is a valid HiBON key
+/
@safe bool is_key_valid(const(char[]) a) pure nothrow {
    enum : char {
        SPACE = 0x20,
        DEL = 0x7F,
        DOUBLE_QUOTE = 34,
        QUOTE = 39,
        BACK_QUOTE = 0x60
    }
    if (a.length > 0) {
        foreach(c; a) {
            // Chars between SPACE and DEL is valid
            // except for " ' ` is not valid
            if ( (c <= SPACE) || (c >= DEL) ||
                ( c == DOUBLE_QUOTE ) || ( c == QUOTE ) ||
                ( c == BACK_QUOTE ) ) {
                return false;
            }
        }
        return true;
    }
    return false;
}
```

#### is_index

If the key string can be expressed as 32 bit unsigned integer then the key is defined as an index.

The regular expression of the index key can be expressed as.

`([1-9][0-9]*|0)`

The converted value must be less than or equal to `0xFFFFFFFF`

 *Example code is_index function in D*

```D
/++
 Converts from a text to a index
 Params:
 a = the string to be converted to an index
 result = index value
 Returns:
 true if a is an index
+/
@safe bool is_index(const(char[]) a, out uint result) pure {
    import std.conv : to;
    enum MAX_UINT_SIZE=to!string(uint.max).length;
    if ( a.length <= MAX_UINT_SIZE ) {
        if ( (a[0] is '0') && (a.length > 1) ) {
            return false;
        }
        foreach(c; a) {
            if ( (c < '0') || (c > '9') ) {
                return false;
            }
        }
        immutable number=a.to!ulong;
        if ( number <= uint.max ) {
            result = cast(uint)number;
            return true;
        }
    }
    return false;
}

```

#### is_key_ordered

The key is ordered if the key value is less than next key value. If the key **is_index** the value of the key is the index else the value of the key is the string value. When two keys are compared and both keys **is_index** then value integer value of the keys or else the lexical order of the keys is used.

*Example code is_key_ordered function in D*

```D
/++
 This function decides the order of the HiBON keys
 Returns:
 true if the value of key a is less than the value of key b
+/
@safe bool less_than(string a, string b) pure
    in {
        assert(a.length > 0);
        assert(b.length > 0);
    }
body {
    uint a_index;
    uint b_index;
    if ( is_index(a, a_index) && is_index(b, b_index) ) {
        return a_index < b_index;
    }
    return a < b;
}

/++
 Checks if the keys in the range is ordred
 Returns:
 ture if all keys in the range is ordered
+/
@safe bool is_key_ordered(R)(R range) if (isInputRange!R) {
    string prev_key;
    while(!range.empty) {
        if ((prev_key.length == 0) || (less_than(prev_key, range.front))) {
            prev_key=range.front;
            range.popFront;
        }
        else {
            return false;
        }
    }
    return true;
}

```

