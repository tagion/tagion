module tagion.basic.Message;

import std.format;
import std.json;

/++
 Controls the language used by the message function
+/
struct Language
{
    protected string _name;
    void set(string name)
    {
        _name = name;
    }

    immutable(string) name() pure const nothrow
    {
        return _name;
    }
}

__gshared Language language;

/++
 This generates the message translation table
 If the version flag UPDATE_MESSAGE_TABEL is set then the default translation tabel
 is generated and a json file is written, which then can be edited for other language support
+/
version (UPDATE_MESSAGE_TABEL)
{
    @safe
    synchronized struct Message
    {
        private static shared string[string] translation;
        static JSONValue toJSON()
        {
            //JSONValue language;
            result[language.stringof] = "en";
            JSONValue tabel;
            foreach (from, to; tabel)
            {
                tabel[from] = to;
            }
            result[translation.stringof] = tabel;
        }
    }
}
else
{
    private static __gshared string[string] __translation;
    static immutable(string[string]*) translation;
    shared static this()
    {
        translation = cast(immutable)(&__translation);
    }

    synchronized struct Message
    {
        static void set(string from, string to)
        {
            __translation[from] = to;
        }

        static void load(JSONValue json)
        {
            auto trans = json[translation.stringof].object;
            foreach (from, to; trans)
            {
                __translation[from] = to.str;
            }
        }
    }
}

/++
 this function works like the std.format except if the language translation table is loaded
 the text is translated via this table
+/
@trusted
string message(Args...)(string fmt, lazy Args args)
{
    if (language.name == "")
    {
        version (UPDATE_MESSAGE_TABEL)
        {
            if (!(fmt in translation))
            {
                Message.set(fmt, fmt);
            }
        }
        return format(fmt, args);
    }
    else
    {
        immutable translate_fmt = translation.get(fmt, fmt);
        return format(translate_fmt, args);
    }
}
