/// \file BigNumber.d

module tagion.betterC.hibon.BigNumber;

import LEB128 = tagion.betterC.utils.LEB128;

/***
 * @brief Is is a wrapper of the std.bigint
 */

@nogc:
/**
 * BigNumber used in the HiBON format
 */
struct BigNumber {
@nogc:
    /**
     * Store actual number, which is split into array
     */
    const(ubyte)[] data;

    /**
     * Constructor for BigNumber
     * @param data - input data about number
     */
    this(const(ubyte)[] data) {
        this.data = data[0 .. LEB128.calc_size(data)];
    }

    /**
     * Used for calculating size in LEB128 format
     * @return size of data
     */
    size_t calc_size() const {
        return LEB128.calc_size(data);
    }

    /**
     * Serialize data
     * @return serialized data
     */
    const(ubyte[]) serialize() const {
        return data;
    }
}
