module tagion.dart.gdbm;

import std.string;
import std.conv;

@safe
class GDBMException : Exception {
    this(GDBM_ERROR error_code, string msg, string file = __FILE__, size_t line = __LINE__) pure {
        super(msg, file, line);
        this.error_code = error_code;
    }
    GDBM_ERROR error_code;
}

void gdbm_enforce(bool predicate, int error_code, lazy string msg = null) {
    if(!predicate) throw new GDBMException(cast(GDBM_ERROR)error_code, msg);
}

alias GDBM_FILE = void*;
alias gdbm_count_t = size_t;

enum GDBM_FLAG {
    READER	= 0,	/* A reader. */
    WRITER	= 1,	/* A writer. */
    WRCREAT	= 2,	/* A writer.  Create the db if needed. */
    NEWDB	= 3,	/* A writer.  Always create a new db. */
    OPENMASK = 7,	/* Mask for the above. */

    FAST	= 0x0010, /* Write fast! => No fsyncs.  OBSOLETE. */
    SYNC	= 0x0020, /* Sync operations to the disk. */
    NOLOCK	= 0x0040, /* Don't do file locking operations. */
    NOMMAP	= 0x0080, /* Don't use mmap(). */
    CLOEXEC = 0x0100, /* Close the underlying fd on exec(3) */
    BSEXACT = 0x0200, /* Don't adjust block_size. Bail out with
                 GDBM_BLOCK_SIZE_ERROR error if unable to
                 set it. */  
    CLOERROR = 0x0400, /* Only for gdbm_fd_open: close fd on error. */
    XVERIFY  = 0x0800, /* Additional consistency checks. */
    PREREAD  = 0x1000, /* Enable pre-fault reading of mmapped regions. */
    NUMSYNC  = 0x2000, /* Enable the numsync extension */
}


enum GDBM_ERROR {
    NO_ERROR		 = 0,
    MALLOC_ERROR	         = 1,
    BLOCK_SIZE_ERROR	 = 2,
    FILE_OPEN_ERROR	 = 3,
    FILE_WRITE_ERROR	 = 4,
    FILE_SEEK_ERROR	 = 5,
    FILE_READ_ERROR	 = 6,
    BAD_MAGIC_NUMBER	 = 7,
    EMPTY_DATABASE	         = 8,
    CANT_BE_READER	         = 9,
    CANT_BE_WRITER	         = 10, 
    READER_CANT_DELETE	 = 11,
    READER_CANT_STORE	 = 12,
    READER_CANT_REORGANIZE	 = 13,
    UNKNOWN_ERROR	         = 14,
    ITEM_NOT_FOUND	         = 15,
    REORGANIZE_FAILED	 = 16,
    CANNOT_REPLACE	         = 17,
    MALFORMED_DATA	         = 18,
    ILLEGAL_DATA            = MALFORMED_DATA,
    OPT_ALREADY_SET	 = 19,
    OPT_BADVAL           	 = 20,
    OPT_ILLEGAL           	 = OPT_BADVAL,
    BYTE_SWAPPED	         = 21,
    BAD_FILE_OFFSET	 = 22,
    BAD_OPEN_FLAGS	         = 23,
    FILE_STAT_ERROR         = 24,
    FILE_EOF                = 25,
    NO_DBNAME               = 26,
    ERR_FILE_OWNER          = 27,
    ERR_FILE_MODE           = 28,
    NEED_RECOVERY           = 29,
    BACKUP_FAILED           = 30,
    DIR_OVERFLOW            = 31,
    BAD_BUCKET              = 32,
    BAD_HEADER              = 33,
    BAD_AVAIL               = 34,
    BAD_HASH_TABLE          = 35,
    BAD_DIR_ENTRY           = 36,
    FILE_CLOSE_ERROR        = 37, 
    FILE_SYNC_ERROR         = 38,
    FILE_TRUNCATE_ERROR     = 39,
    BUCKET_CACHE_CORRUPTED  = 40,
    BAD_HASH_ENTRY          = 41,
    ERR_SNAPSHOT_CLONE      = 42,
    ERR_REALPATH            = 43,
    ERR_USAGE               = 44
}


private
struct Datum
{
  char *dptr;
  int   dsize;

  this(ubyte[] dat) {
     dptr = cast(char*)dat.ptr;
     assert(dat.length <= dsize.max);
     dsize = cast(typeof(dsize))dat.length;
  }

  ubyte[] opSlice() {
        ubyte[] val;
        return val[0..dsize] = cast(ubyte[])dptr[0..dsize];
  }
}

private extern(C) {
    GDBM_FILE gdbm_open(const char* name, int block_size, int flags, int mode, void function(const char *)fatal_func);
    int gdbm_close(GDBM_FILE dbf);
    int gdbm_count(GDBM_FILE dbf, scope gdbm_count_t *pcount);
    int gdbm_bucket_count (GDBM_FILE dbf, size_t *pcount);
    int gdbm_store (GDBM_FILE dbf, Datum key, Datum content, int flag);
    int gdbm_delete(GDBM_FILE dbf, Datum key);
    Datum gdbm_fetch(GDBM_FILE dbf, Datum key);
}

class GDBM {
    // static void create(string filename, string description, immutable uint BLOCK_SIZE, string file_label = null, const uint max_size = 0x80) {

    extern(C) static void fatal_func(const char* msg) {
        assert(0, fromStringz(msg));
    }

    ~this() {
        if(_file) {
            _close();
        }
    }

    private {
        GDBM_FILE _file;

        void _open(string name, int block_size, int flags = GDBM_FLAG.READER, int mode = octal!"0644") {
            _file = gdbm_open(toStringz(name), block_size, flags, mode, &fatal_func);
        }

        void _close() {
            assert(_file !is null);
            int rc = gdbm_close(_file);
            _file = null;
            gdbm_enforce(rc == GDBM_ERROR.NO_ERROR, rc, "Closing file");
        }

        gdbm_count_t _count() {
            assert(_file);
            gdbm_count_t pcount;
            int rc = gdbm_count(_file, &pcount);
            gdbm_enforce(rc == GDBM_ERROR.NO_ERROR, rc, "Counting items");
            return pcount;
        }

        size_t _bucket_count() {
            assert(_file);
            size_t pcount;
            int rc = gdbm_bucket_count(_file, &pcount);
            gdbm_enforce(rc == GDBM_ERROR.NO_ERROR, rc, "Counting buckets");
            return pcount;
        }

        void _store(ubyte[] key, ubyte[] value, int flag) {
            assert(_file);
            Datum _key = Datum(key);
            Datum _content = Datum(value);
            int rc = gdbm_store(_file, _key, _content, flag);
            gdbm_enforce(rc == GDBM_ERROR.NO_ERROR, rc, "Storing");
        }

        void _delete(ubyte[] key) {
            assert(_file);
            int rc = gdbm_delete(_file, Datum(key));
            gdbm_enforce(rc == GDBM_ERROR.NO_ERROR, rc, "Deleting");
        }

        ubyte[] _fetch(ubyte[] key) {
            assert(_file);
            Datum val = gdbm_fetch(_file, Datum(key));
            return val[];
        }
    }
}

unittest {
    auto db = new GDBM();
    db._open("agdbmfile", 0x80, GDBM_FLAG.WRCREAT);
    db._close();
}
