module proton.parser.bson.JSBSON;

import dmdscript.dobject;
import dmdscript.darray;
import dmdscript.script;
import dmdscript.text;
import dmdscript.value;
import dmdscript.extending;
import dmdscript.property;
import dmdscript.dnative;

import std.typetuple;
import std.conv;

import proton.ProtonException;
import proton.parser.bson.BSON;


static extender!(JSBSON, "BSON") jsbson_keeper;

//version(none)
/*
static this() {
    JSBSON.init;
}
*/

class JSBSON : Dobject {
    protected BSON _bson;
    // Suppoted array base types
    alias TypeTuple!(bool, int, uint, long, float, double) BaseTypes;

    this(Dobject prototype) {
        super(prototype);
    }
    BSON bson() {
        return _bson;
    }
    void assign(BSON bson) {
        this._bson=bson;
        _bson.no_duble=true;
        _bson.typedarray=true;
    }

    this(BSON bson) {
        this._bson=bson;
        _bson.no_duble=true;
        _bson.typedarray=true;
        super(Dobject.getPrototype);
    }
    override Value* get(Value* key, hash_t hash=0) {
        Value* result=new Value;
        if (_bson !is null) {
            BSON e=_bson[key.get!string];
            if ( e ) {
                with(Type) final switch(e.type) {
                    case NONE:
                        break;
                    case DOUBLE:
                        *result=e.value.number;
                        break;
                    case FLOAT:
                        *result=e.value.number32;
                        break;
                    case STRING:
                    case SYMBOL:
                    case JS_CODE:
                        *result=e.value.text;
                        break;
                    case DOCUMENT:
                        result.putVobject(new JSBSON(e.value.document));
                        break;
                    case ARRAY:
                        // Todo
                        break;
                    case BINARY:
                        // Todo
                        break;
                    case UNDEFINED:
                    case NULL:
                    case MAX:
                    case MIN:
                        break;
                    case OID:
                        *result=e.value.oid.toString;
                        break;
                    case BOOLEAN:
                        *result=e.value.boolean;
                        break;
                    case DATE:
                        // Todo
                        break;
                    case REGEX:
                        // Todo
                        break;
                    case DBPOINTER:
                        break;
                    case JS_CODE_W_SCOPE:
                        // Todo
                        break;
                    case INT32:
                        *result=e.value.int32;
                        break;
                    case UINT32:
                        *result=e.value.uint32;
                        break;
                    case TIMESTAMP:
                    case INT64:
                        *result=to!d_string(e.value.int64);
                        break;
                    case UINT64:
                        *result=to!d_string(e.value.uint64);
                        break;

                    }
            }
        }
        return result;
    }

    static BSON build_bson(Dobject o) {
        BSON result=new BSON;
        foreach(jk, prop; o) {
            if ( (prop.attributes & DontEnum) == 0 ) {
                auto k=to!string(jk.toText);
                with(vtype_t) final switch ( prop.value.vtype ) {
                    case V_REF_ERROR:
                    case V_UNDEFINED:
                        break;
                    case V_NULL:
                        result.append(Type.NULL, k, 0);
                        break;
                    case V_BOOLEAN:
                        result[k]=prop.value.get!bool;
                        break;
                    case V_NUMBER:
                        result[k]=prop.value.get!double;
                        break;
                    case V_INTEGER:
                        result[k]=prop.value.get!int;
                        break;
                    case V_STRING:
                        result[k]=prop.value.get!string;
                        break;
                    case V_OBJECT:
                        auto arr=cast(Darray)o;
                        auto native = cast(DnativeType)arr;
                        if ( native ) {
                            switch (native.type()) {
                                foreach(T;BaseTypes) {
                                case const(T).stringof:
                                    auto a=cast(DarrayNative!(const(T)))arr;
                                    result[k]=a.array;
                                    break;
                                }
                                break;
                                foreach(T;BaseTypes) {
                                case immutable(T).stringof:
                                    auto a=cast(DarrayNative!(immutable(T)))arr;
                                    result[k]=a.array;
                                    break;
                                }
                            default:
                                throw new ProtonException("Unsupported type "~native.type);
                            }
                        }
                        else {
                            result[k]=build_bson(o);
                        }
                        break;
                    case V_ITER:
                        break;
                    case V_ACCESSOR:
                        break;
                    }
            }
        }
        return result;
    }

    override Value* put(Value* key, Value* value, ushort attributes, Setter set, bool define, hash_t hash=0)
    in {
        if (hash) assert(hash==key.toHash);
    }
    body {
        if ( _bson is null ) {
            _bson = new BSON;
            _bson.no_duble=true;
            _bson.typedarray=true;
        }
//        assert(bson !is null); // BSON object must be assigned first
        Value* assign(in string key, Value* value) {
            with(vtype_t) final switch(value.vtype) {
                case V_REF_ERROR:
                case V_UNDEFINED:
                    break;
                case V_NULL:
                    _bson.append(Type.NULL, key, 0);
                    break;
                case V_BOOLEAN:
                    _bson[key]=value.get!bool;
                    break;
                case V_NUMBER:
                    _bson[key]=value.get!double;
                    break;
                case V_INTEGER:
                    _bson[key]=value.get!int;
                    break;
                case V_STRING:
                    _bson[key]=value.get!string;
                    break;
                case V_OBJECT:
                    Dobject obj=value.toObject;
                    Darray arr=cast(Darray)obj;
                    auto tarr=cast(DnativeType)obj;
                    if ( arr ) {
                        auto native = cast(DnativeType)arr;
                        if ( native ) {
                            switch (native.type()) {
                                foreach(T;BaseTypes) {
                                case const(T).stringof:
                                    auto a=cast(DarrayNative!(const(T)))arr;
                                    _bson[key]=a.array;
                                    break;
                                }
                                break;
                                foreach(T;BaseTypes) {
                                case immutable(T).stringof:
                                    auto a=cast(DarrayNative!(immutable(T)))arr;
                                    _bson[key]=a.array;
                                    break;
                                }
                            default:
                                throw new ProtonException("Unsupported type "~native.type);
                            }
                        }
                        else { // JS ARRAY
                            _bson[key]=build_bson(arr);
                        }
                    }
                    else { // JS Object
                        _bson[key]=build_bson(obj);
                    }
                    break;
                case V_ITER:
                case V_ACCESSOR:
                    break;
                }
            return null;
        }
        if (key.isObject) {
            scope Value vname;
            Value* result=key.toPrimitive(&vname, TEXT_valueOf);
            if (result) return result;
            return assign(vname.get!string, value);
        } else if (key.isAccessor) {
            assert(0, "dobject.put for accessor not implemented yet");
        } else {
            return assign(key.get!string, value);
        }
        return null;
    }

    override d_string toSource(Dobject root) {
        if ( _bson is null )  {
            return "{}";
        }
        else {
            return _bson.toText!d_string();
        }
    }

    static Value* expand(Dobject pthis, CallContext *cc, Dobject othis, Value* ret, Value[] arglist){
        if ( arglist.length >= 1 ) {
            auto argobj = arglist[0].toObject;
            auto jsbson = cast(JSBSON)argobj;
            if ( jsbson ) {
                ret.putVobject(dArray(jsbson._bson.expand));
                return null;
            }
            auto error=Dobject.TypeError(cc.errorInfo, "First argument must be BSON object");
            *ret=error;
            return error;
        }
        ret.putVundefined;
        return Dobject.TypeError(cc.errorInfo, "Missing argument");
    };

    static init_this() {

        Value* vexpand=new Value;
        static enum NativeFunctionData nfd[] =
            [
                { "expand", &expand, 1 }
                ];

        DnativeFunction.init(jsbson_keeper.constructor,nfd, DontEnum);
    }

}
