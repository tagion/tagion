module hibon.utils.Basic;

template suffix(string name, size_t index) {
    static if ( index is 0 ) {
        alias suffix=name;
    }
    else static if ( name[index-1] !is '.' ) {
        alias suffix=suffix!(name, index-1);
    }
    else {
        enum cut_name=name[index..$];
        alias suffix=cut_name;
    }
}

/++
  + Template function returns the suffux name after the last '.'
  +/
template basename(alias K) {
    static if ( is(K==string) ) {
        enum name=K;
    }
    else {
        enum name=K.stringof;
    }
    enum basename=suffix!(name, name.length);
}


/**
   Finds the type in the TList which T can be typecast to
   Returns:
   void if not type is found
 */
template CastTo(T, TList...) {
    static if(TList.length is 0) {
        alias CastTo=void;
    }
    else {
        alias castT=TList[0];
        static if (is(T:castT)) {
            alias CastTo=castT;
        }
        else {
            alias CastTo=CastTo!(T, TList[1..$]);
        }
    }
}
