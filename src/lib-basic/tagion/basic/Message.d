module tagion.basic.Message;

import std.format;
import std.json;
import tagion.basic.Types : FileExtension;
import tagion.basic.Version;
import tagion.basic.basic : EnumText;

enum name_list = [
        "TAGION", /// Name of the tagion environment variable pointing to the tagion directory 
        "TAGION_LANG", /// Tagion language
        "language", /// Language
        "languages", /// Path for the translation language files 
        "tabel", /// Translation table
        "tagion", /// Name of the product
        "en", /// Default language
        "new_en", /// Just a new language name used when the default exists
    ];

mixin(EnumText!("Names", name_list));

/++
 this function works like the std.format except if the language translation table is loaded
 the text is translated via this table
+/
@safe
struct Message {
    immutable(string[string]) translation;
    string opCall(Args...)(string fmt, lazy Args args) pure const {
        if (translation.length is 0) {
            return format(fmt, args);
        }
        version (UPDATE_MESSAGE_TABLE) {
            if (!fmt in translation) {
                translation[fmt] = fmt;
            }
        }
        return format(translation.get(fmt, fmt), args);
    }
}

//__gshared  string[string] translation;

static immutable Message message;

import std.algorithm : each;
import std.file : exists, mkdirRecurse, fread = read, tempDir, fwrite = write;
import std.path;
import std.process : environment;
import std.stdio;

static if (not_unittest) {
    /++
 This generates the message translation table
 If the version flag UPDATE_MESSAGE_TABEL is set then the default translation tabel
 is generated and a json file is written, which then can be edited for other language support
+/

    string get_lang_path() {
        return buildPath(environment.get(Names.TAGION, tempDir), Names.languages);
    }

    version (none) shared static this() {
        immutable lang_file = buildPath(get_lang_path, environment.get(Names.TAGION_LANG, Names.en))
            .setExtension(FileExtension.json);
        if (lang_file.exists) {
            const text = lang_file.fread;
        }
        auto json = lang_file.parseJSON;
        string[string] translation;
        foreach (string from, ref to; json.object) {
            translation[from] = to.get!string;
        }
        message.translation = cast(immutable) translation;
    }

    version (WRITE_MESSAGE_TABLE) {
        shared static ~this() {
            JSONValue result;
            result[Names.language] = Names.en;
            JSONValue tabel;
            message.translation.byKey
                .each!(fmt => tabel[fmt] = fmt);
            result[Names.tabel] = tabel;
            immutable text = result.toPrettyString;
            immutable lang_path = get_lang_path;
            auto lang_file = buildPath(lang_path, Names.en).setExtension(FileExtension.json);
            if (!(Names.TAGION in environment)) {
                stderr.writeln("Environment %s was not defined", Names.TAGION);
            }
            writefln("path '%s'", lang_path);
            writefln("Language file stored in '%s'", lang_file);
            if (!lang_path.exists) {
                lang_path.mkdirRecurse;
            }
            if (lang_file.exists) {
                lang_file = buildPath(lang_path, Names.new_en).setExtension(FileExtension.json);
            }
            lang_file.fwrite(text);
        }
    }
}
