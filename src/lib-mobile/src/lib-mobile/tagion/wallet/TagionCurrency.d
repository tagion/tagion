module tagion.wallet.TagionCurrency;

import std.format;

enum ulong AXION_UNIT=1_000_000;
enum ulong AXION_MAX=1_000_000*AXION_UNIT;

@safe
struct TagionCurency{
    protected double _amount;

    this(double amount){
        this._amount = amount;
    }

    this(ulong amount){
        this._amount = toTagion(amount);
    }

    ulong axios() nothrow{
        return TagionCurency.toAxion(this._amount);
    }

    double value() nothrow{ 
        return this._amount;
    }

    string toString(){
        return TagionCurency.TGN(axios);
    }

    private{
        static ulong toAxion(const double amount) pure nothrow {
            auto result=AXION_UNIT*amount;
            if (result > AXION_MAX) {
                result=AXION_MAX;
            }
            return cast(ulong)result;
        }

        static double toTagion(const ulong amount) pure nothrow {
            return (cast(real)amount)/AXION_UNIT;
        }

        string TGN(const ulong amount) pure {
            const ulong tagions=amount/AXION_UNIT;
            const ulong axions=amount % AXION_UNIT;
            return format("%d.%d TGN", tagions, axions);
        }
    }
}