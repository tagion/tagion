/// Traversal of dartrims
module tagion.dart.DARTRim;

import std.format;
import tagion.basic.Debug;
import tagion.basic.Types;
import tagion.basic.basic : EnumText;
import tagion.hibon.HiBONRecord;

@safe:
enum RIMS_IN_SECTOR = 2;
/** 
     * Sector range 
     */
static struct SectorRange {
    private {
        @exclude ushort _sector;
        @label("from") ushort _from_sector;
        @label("to") ushort _to_sector;
    }
    /**
        * The start start sector
        * Returns: start angle
        */
    @property ushort from_sector() const {
        return _from_sector;
    }

    /**
         * The end sector
         * Returns: end angle 
         */
    @property ushort to_sector() const {
        return _to_sector;
    }

    @exclude protected bool flag;
    mixin HiBONRecord!(q{
                this(const ushort from_sector, const ushort to_sector) pure nothrow @nogc {
                    _from_sector = from_sector;
                    _to_sector = to_sector;
                    _sector = from_sector;
                }
            });

    /**
         * Checks if the range is a full angle dart (0x0000 to 0xFFFF)
         * Returns: true if it a full-range=full-angle
         */
    bool isFullRange() const pure nothrow {
        return _from_sector == _to_sector;
    }

    /** 
         * Checks if the sector is within the sector-range
         * Params:
         *   sector = sector number
         * Returns: true if sector is within the range
         */
    bool inRange(const ushort sector) const pure nothrow {
        return sectorInRange(sector, _from_sector, _to_sector);
    }

    /** 
         * Checks if the sector of a rim is within the sector-range
         * Params:
         *   rims = a rim path 
         * Returns: 
         */
    bool inRange(const Rims rims) const pure nothrow {
        if (rims.path.length == 1) {
            return sectorInRange(rims.path[0] << 8, _from_sector & 0xFF00, _to_sector);
        }
        return (rims.path.length == 0) || sectorInRange(rims.sector, _from_sector, _to_sector);
    }

    /**
         * Checks if sector is within range 
         * Params:
         *   sector = sector number
         *   from_sector = sector start angle
         *   to_sector = sector end angle
         * Returns: true if the sector is within the angle-span 
         */
    static bool sectorInRange(
            const ushort sector,
            const ushort from_sector,
            const ushort to_sector) pure nothrow {
        if (to_sector == from_sector) {
            return true;
        }
        else {
            immutable ushort sector_origin = (sector - from_sector) & ushort.max;
            immutable ushort to_origin = (to_sector - from_sector) & ushort.max;
            return (sector_origin < to_origin);
        }
    }

    /**
         * Check if current sector has reached the end
         * Returns: true of the sector reach the end of the angle-span
         */
    bool empty() const pure nothrow {
        return !inRange(_sector) || flag;
    }

    /** 
         * Progress one sector
         */
    void popFront() {
        if (!empty) {
            _sector++;
            if (_sector == _from_sector) {
                flag = true;
            }
        }
    }

    /**
         * Gets the current sector
         * Returns: current sector
         */
    ushort front() const pure nothrow {
        return _sector;
    }

    /** 
         * Gives an representation of the angle span
         * Returns: text of angle span
         */
    string toString() const pure {
        return format("(%04X, %04X)", _from_sector, _to_sector);
    }

    ///
    unittest {
        enum full_dart_sectors_count = ushort.max + 1;
        { //SectorRange: full sector iterator
            auto sector_range = SectorRange(0, 0);
            auto iteration = 0;
            foreach (sector; sector_range) {
                iteration++;

                if (iteration > full_dart_sectors_count)
                    assert(0, "Range overflow");
            }
            assert(iteration == full_dart_sectors_count);
        }
        { //SectorRange: full sector iterator
            auto sector_range = SectorRange(5, 5);
            auto iteration = 0;
            foreach (sector; sector_range) {
                iteration++;

                if (iteration > full_dart_sectors_count)
                    assert(0, "Range overflow");
            }
            assert(iteration == full_dart_sectors_count);
        }
        { //SectorRange:
            auto sector_range = SectorRange(1, 10);
            auto iteration = 0;
            foreach (sector; sector_range) {
                iteration++;

                if (iteration > 9)
                    assert(0, "Range overflow");
            }
            assert(iteration == 9);
        }
    }
}

/**
     * Rim selecter
     */
@recordType("Rims")
struct Rims {
    Buffer path;
    @label("keys") @optional @(filter.Initialized) Buffer key_leaves;
    protected enum root_rim_path = [];
    static immutable root = Rims(root_rim_path);
    /**
         * Returns: sector of the selected path
         */
    ushort sector() const pure nothrow {
        if (path.length == 0) {
            return ushort.init;
        }
        return .sector(path);
    }

    mixin HiBONRecord!(
            q{
                this(Buffer r, Buffer key_leaves=null) {
                    this.path=r;
                    this.key_leaves=key_leaves;
                }

                this(const ushort sector)
                out {
                    assert(path.length is ushort.sizeof);
                }
                do  {
                    path=[sector >> 8*ubyte.sizeof, sector & ubyte.max];
                    key_leaves=null;
                }

                this(I)(const Rims rim, const I key) if (isIntegral!I) 
                in (key >= 0 && key <= ubyte.max) 
                do {

                    path = rim.path ~ cast(ubyte) key;
                    this.key_leaves= rim.key_leaves.idup; 
                }
            });

    /**
         * rim-path as hex value
         * Returns: hex string
         */
    string toString() const pure nothrow {
        import std.exception : assumeWontThrow;

        if (path.length == 0) {
            return "XXXX";
        }
        return assumeWontThrow(format!"%(%02x%)"(path));
    }
}

/++
 + Sector is the little ending value the first two bytes of an fingerprint
 + Returns:
 +     Sector number of a fingerprint
 +/
@safe
ushort sector(F)(const(F) fingerprint) pure nothrow @nogc if (isBufferType!F)
in (fingerprint.length >= ubyte.sizeof)
do {
    ushort result = ushort(fingerprint[0]) << 8;
    if (fingerprint.length > ubyte.sizeof) {
        result |= fingerprint[1];

    }
    return result;
}

@safe
unittest {
    import std.stdio;
    import tagion.crypto.Types : Fingerprint;

    ubyte[] buf1 = [0xA7];
    assert(sector(buf1) == 0xA700);
    assert(sector(cast(Fingerprint)[0xA7, 0x15]) == 0xA715);
    Buffer buf2 = [0xA7, 0x15, 0xE3];
    assert(sector(buf2) == 0xA715);

}
