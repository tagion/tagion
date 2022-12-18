module tagion.network.ReceiveBuffer;

struct ReceiveBuffer {
            ubyte[] buffer;
            ubyte[] current;
	size_t size;
alias Receive = ptrdiff_t delegate(scope void[] buf); 
bool append(const Recieve receive) {
            enum LEN_MAX = LEB128.calc_size(uint.max);
static ubyte[LEN_MAX] leb128_led_data;	
if (current is null) {
	current = leb128_leb_data[]; 
}
        immutable(ubyte[]) receive() {
            import std.stdio;
            import tagion.hibon.Document : Document;

            ptrdiff_t rec_data_size;
            // The length of the buffer is in leb128 format
            auto leb128_len_data = new ubyte[LEN_MAX];
            current = leb128_len_data;
            uint leb128_index;
            leb128_loop: for (;;) {
                rec_data_size = client.receive(current);
                if (rec_data_size < 0) {
                    // Not ready yet
                    yield;
                }
                else if (rec_data_size == 0) {
                    // Error
                    return null;
                }
                else {

                    

                        .check(leb128_index < LEN_MAX,
                                message("Invalid size of len128 length field %d", leb128_index));
                    break leb128_loop;
                }
                checkTimeout;
                yield;
            }
            // receive data
            const leb128_len = LEB128.decode!uint(leb128_len_data);
            const buffer_size = leb128_len.value;
            if (buffer_size > opts.max_buffer_size) {
                return null;
            }
            buffer = new ubyte[leb128_len.size + leb128_len.value];
            buffer[0 .. rec_data_size] = leb128_len_data[0 .. rec_data_size];
            current = buffer[rec_data_size .. $];
            while (current.length) {
                rec_data_size = client.receive(current);
                if (rec_data_size < 0) {
                    // Not ready yet
                    writeln("Timeout");
                    checkTimeout;
                }
                else {
                    current = current[rec_data_size .. $];
                }
                yield;
            }
            return buffer.idup;
        }

        /
