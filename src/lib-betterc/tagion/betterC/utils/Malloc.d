module tagion.betterC.utils.Malloc;

extern (C) {
    void set_memory(void* ptr, size_t size) {
        free_block_list_head = cast(FreeBlock*)(ptr);
        (*free_block_list_head).size = size - FreeBlock.sizeof;

        //        (size-FreeBlock.sizeof, cast(FreeBlock*)ptr);
        FreeBlock* end_of_memory = free_block_list_head - FreeBlock.sizeof;
        *end_of_memory = FreeBlock.init;
    }
}

@nogc nothrow {

    struct FreeBlock {
        size_t size;
        FreeBlock* next;
    }

    FreeBlock* free_block_list_head;
    enum overhead = size_t.sizeof;
    enum align_to = size_t.sizeof * 2;

    void* malloc(size_t size) {
        size = (size + size_t.sizeof + (align_to - 1)) & ~(align_to - 1);
        FreeBlock* prev_block = free_block_list_head;
        // scope(success) {
        // }
        for (FreeBlock* block = free_block_list_head; block !is null; block = block.next) {
            // FreeBlock* block = free_block_list_head.next;
            // FreeBlock** head = &(free_block_list_head.next);
            // while (block !is null) {
            // writefln("Block size before %d", block.size);
            if (block.size >= size) {
                void* result = cast(void*) block + overhead;
                // scope(exit) {

                // }
                if (block.size > size) {
                    FreeBlock* rest = cast(FreeBlock*)(cast(void*) block + size + overhead);
                    // (*head).next = rest;
                    rest.size = block.size - size - overhead;
                    rest.next = block.next;
                    block.size = size;
                    block.next = rest;
                    // if (block is free_block_list_head) {
                    //     free_block_list_head = block.next;
                    // }
                    // else {
                    //     prev_block.next = block.next;
                    // }
                    // writefln("block.size=%d", block.size);
                    // writefln("size=%d rest.size=%d", size, rest.size);
                }
                // else {
                if (block is free_block_list_head) {
                    free_block_list_head = block.next;
                }
                else {
                    prev_block.next = block.next;
                }
                // (*head) = block.next;
                // }
                //            void* result=block + overhead;
                (cast(size_t*) result)[0 .. size / size_t.sizeof] = 0;
                return result;
            }
            prev_block = block;
            // head = &(block.next);
            // block = block.next;
        }
        //    block = (free_block*)sbrk(size);
        // block->size = size;

        // return ((char*)block) + sizeof(size_t);

        assert(0, "Out of memory");
    }

    void* calloc(size_t nmemb, size_t size) {
        return malloc(nmemb * size);
    }

    void* realloc(void* ptr, size_t size) {
        FreeBlock* block = cast(FreeBlock*)(ptr - overhead);
        if (size <= block.size) {
            return ptr;
        }
        auto result = malloc(size);
        scope (exit) {
            free(ptr);
        }
        (cast(size_t*) result)[0 .. block.size / size_t.sizeof] =
            (cast(size_t*) ptr)[0 .. block.size / size_t.sizeof];
        return result;
    }

    void free(void* ptr) {
        FreeBlock* block = cast(FreeBlock*)(ptr - overhead);
        assert(free_block_list_head !is ptr, "Double free");
        block.next = free_block_list_head;
        free_block_list_head = block;
    }

    bool isFree(void* ptr) {
        FreeBlock* search_ptr = cast(FreeBlock*)(ptr - overhead);
        for (FreeBlock* block = free_block_list_head; block !is null; block = block.next) {
            if (search_ptr is block) {
                return true;
            }
        }
        return false;
    }

    size_t sizeOf(void* ptr) {
        FreeBlock* block = cast(FreeBlock*)(ptr - overhead);
        return block.size;
    }

    size_t avail() {
        size_t result;
        for (FreeBlock* block = free_block_list_head; block !is null; block = block.next) {
            result += block.size;
        }
        return result;
    }

    size_t biggest() {
        import std.algorithm.comparison : max;

        size_t result;
        for (FreeBlock* block = free_block_list_head; block !is null; block = block.next) {
            result = max(result, block.size);
        }
        return result;
    }
}

unittest {
    import std.stdio;

    void dump() {
        for (FreeBlock* block = free_block_list_head; block !is null; block = block.next) {
            writefln("%s : %2d 0x%02x", block, block.size, block.size);
        }
    }
    // writeln("------------- ---------------");
    const mem_size = FreeBlock.sizeof * 32;
    auto mem = new ubyte[mem_size];
    set_memory(mem.ptr, mem_size);

    // writefln("%s", *free_block_list_head);
    // writefln("free_block_list_head.size=%s", free_block_list_head.size);
    auto _avail = avail;
    // writefln("%s", avail);

    auto ptr1 = malloc(33);
    assert(!isFree(ptr1));
    // writefln("%s", *free_block_list_head);
    // writefln("ptr1=%s %s", ptr1, ptr1.sizeOf);
    // writefln("avail=%d _avail=%d %d %d", avail, _avail, ptr1.sizeOf,overhead);
    _avail -= ptr1.sizeOf + overhead;

    assert(avail == _avail);

    // writefln("%s", *free_block_list_head);
    auto ptr2 = malloc(100);
    assert(!isFree(ptr2));
    // writefln("ptr2=%s %s", ptr2, ptr2.sizeOf);
    // writefln("%s", *free_block_list_head);
    _avail -= ptr2.sizeOf + overhead;

    assert(avail == _avail);

    // writefln("%s", *free_block_list_head);
    // writefln("avail=%s", avail);
    auto ptr3 = malloc(48);
    assert(!isFree(ptr3));
    // writefln("ptr3=%s %s", ptr3, ptr3.sizeOf);
    // writefln("%s", *free_block_list_head);
    // writefln("%s", avail);
    _avail -= ptr3.sizeOf + overhead;

    assert(avail == _avail);

    auto ptr4 = malloc(48);
    assert(!isFree(ptr4));
    // writefln("ptr3=%s %s", ptr3, ptr3.sizeOf);
    // writefln("%s", *free_block_list_head);
    // writefln("%s", avail);
    _avail -= ptr4.sizeOf + overhead;

    assert(avail == _avail);
    _avail += ptr3.sizeOf;
    // dump;

    // writefln("Before free avail=%d ptr3.sizeOf=%d", avail, ptr3.sizeOf);
    free(ptr3);
    assert(isFree(ptr3));
    // writefln("%s", *free_block_list_head);
    // writefln("%s", avail);
    // writefln("avail=%d _avail=%d", avail, _avail);
    assert(avail == _avail);
    // dump;

    auto ptr5 = malloc(58);
    assert(!isFree(ptr5));
    _avail -= ptr5.sizeOf + overhead;
    // writefln("ptr5 avail=%d _avail=%d", avail, _avail);
    // dump;
    assert(avail == _avail);

    auto ptr6 = malloc(70);
    assert(!ptr6.isFree);
    _avail -= ptr6.sizeOf + overhead;
    // writefln("ptr6 avail=%d _avail=%d", avail, _avail);
    assert(avail == _avail);
    _avail += ptr5.sizeOf;

    free(ptr5);
    assert(ptr5.isFree);
    // writefln("avail=%d _avail=%d", avail, _avail);
    assert(avail == _avail);
    // foreach(i;0..4) {
    //     malloc(20);
    // }

    // writefln("ptr5 %s ", ptr5);
    // dump;
    auto ptr7 = malloc(52);
    assert(!ptr7.isFree);
    _avail -= ptr7.sizeOf + overhead;

    // writefln("avail=%d _avail=%d", avail, _avail);

    // dump;
    auto ptr8 = malloc(30);
    _avail -= ptr8.sizeOf + overhead;
    // writefln("avail=%d _avail=%d", avail, _avail);

    // dump;

    // Reuse ptr2

    // auto ptr4 = malloc(54);
    // writefln("avail=%d ptr4.sizeOf=%d", avail, ptr4.sizeOf);
    // writefln("ptr2=%s ptr4=%s", ptr2, ptr4);

}

unittest { /// calloc
    import std.stdio;

    const mem_size = FreeBlock.sizeof * 32;
    auto mem = new ubyte[mem_size];
    set_memory(mem.ptr, mem_size);

    auto ptr1 = malloc(64);
    auto array_ptr1 = cast(byte*) ptr1;
    array_ptr1[0] = -42;
    array_ptr1[63] = 42;

    // writefln("%d", ptr1.sizeOf);
    assert(ptr1.sizeOf == 80);

    auto ptr2 = realloc(ptr1, 100);
    // writefln("%d", ptr2.sizeOf);
    // writefln("%s", isFree(ptr1));
    auto array_ptr2 = cast(byte*) ptr2;

    assert(ptr1.isFree);
    assert(!ptr2.isFree);
    assert(ptr2.sizeOf == 112);
    assert(array_ptr2[0] == -42);
    assert(array_ptr2[63] == 42);
}
