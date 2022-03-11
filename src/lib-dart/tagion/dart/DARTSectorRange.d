module tagion.dart.DARTSectorRange;

import tagion.hibon.HiBONRecord : HiBONRecord, RecordType, GetLabel;
import tagion.basic.Basic : Buffer;
import std.format;

@safe @RecordType("Rims")
struct Rims {
    Buffer rims;
    protected enum root_rim = [];
    static immutable root = Rims(root_rim);
    ushort sector() const pure nothrow
    in {
        assert(rims.length >= ushort.sizeof || rims is root_rim,
                format("Rims size must be %d or more ubytes contain a sector but contains %d", ushort.sizeof, rims
                .length));
    }
    do {
        if (rims is root_rim)
            return ushort.init;
        ushort result = ushort(rims[0]) + ushort(rims[1] << ubyte.sizeof * 8);
        return result;
    }

    string toString() const pure nothrow {
        import tagion.utils.Miscellaneous : hex;

        return rims.hex;
    }

    mixin HiBONRecord!(
            q{
                this(Buffer r) {
                    rims=r;
                }

                this(const ushort sector)
                out {
                    assert(rims.length is ushort.sizeof);
                }
                do  {
                    rims=[sector >> 8*ubyte.sizeof, sector & ubyte.max];
                }
            });
}

@safe
struct SectorRange {
    private ushort _sector;
    private ushort _from_sector;
    private ushort _to_sector;
    @property ushort from_sector() inout {
        return _from_sector;
    }

    @property ushort to_sector() inout {
        return _to_sector;
    }

    protected bool flag;
    this(const ushort from_sector, const ushort to_sector) pure nothrow {
        _from_sector = from_sector;
        _to_sector = to_sector;
        _sector = from_sector;
    }

    bool isFullRange() const pure nothrow {
        return _from_sector == _to_sector;
    }

    bool inRange(const ushort sector) const pure nothrow {
        return sectorInRange(sector, _from_sector, _to_sector);
    }

    bool inRange(const Rims rims) const pure nothrow {
        return sectorInRange(rims.sector, _from_sector, _to_sector);
    }

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

    bool empty() const pure nothrow {
        return !inRange(_sector) || flag;
    }

    void popFront() {
        if (!empty) {
            _sector++;
            if (_sector == _from_sector)
                flag = true;
        }
    }

    ushort front() const pure nothrow {
        return _sector;
    }

    string toString() inout {
        import std.string;

        return format("(%d, %d)", _from_sector, _to_sector);
    }

    @safe
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
