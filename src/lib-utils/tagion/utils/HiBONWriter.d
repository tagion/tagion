/// \file HiBONWriter.d

module tagion.utils.HiBONWriter;

import tagion.crypto.SecureNet : StdHashNet;
import tagion.hibon.HiBON;
import tagion.basic.Types : FileExtension;
import tagion.basic.Basic : fileExtension;
import tagion.hibon.Document;
import std.file : fwrite = write;
import std.range : empty;
import tagion.hibon.HiBONJSON;
import std.conv : toChars;
import std.ascii : LetterCase;
import std.array;

/** @brief write and hashing hibon data
 */
class HiBONWriter
{
    private string workingDirectory;
    private ubyte[StdHashNet.HASH_SIZE] lastWritedHashData;
    private HiBON writeData;
    private StdHashNet hasher;

    this(ref const string _workingDirectory)
    {
        this.workingDirectory = _workingDirectory;
        this.hasher = new StdHashNet;
    }

    this() 
    {
        this.hasher = new StdHashNet;
    }

    private static string toHexStr(const ubyte[] values)
    {
        string result;
        foreach(num; values)
        {
            string hexrep = toChars!(16, char, LetterCase.upper)(uint(num)).array;
            result = result ~ hexrep;
        }
        return result;
    }

    string lastWritedHash() const
    {
        return this.toHexStr(this.lastWritedHashData);
    }

    void setWriteData(ref const Document document)
    {
        this.writeData = document.toJSON.toHiBON;
    }

    void setWriteData(ref HiBON data)
    {
        this.writeData = data;
    }

    bool performHashedWrite()
    {
        string filename = toHexStr(this.hasher.rawCalcHash(this.writeData.serialize()));
        return performWriteData(filename);
    }

    bool performWriteData(string filename)
    {
        import std.stdio;
        auto fullname = filename~"."~FileExtension.hibon;
        string fullpath = workingDirectory.empty ?  fullname : workingDirectory~"/"~fullname;
        try
        {
            const ubyte[] data = this.writeData.serialize;
            fullpath.fwrite(data);
            this.lastWritedHashData = hasher.rawCalcHash(data);
            writeln("HASH: ", toHexStr(this.lastWritedHashData));
            return true;
        }
        catch(Exception e)
        {
            return false;
        }
    }
}

version(none) unittest
{
    auto hibon = new HiBON;
    hibon["key_A"] = "alpha";
    hibon["key_B"] = "beta";
    hibon["key_G"] = "gamma";
    HiBONWriter writer = new HiBONWriter();
    writer.setWriteData(hibon);
    writer.performWriteData("TestfileWrited");
}