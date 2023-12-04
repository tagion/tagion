module tagion.utils.Term;

import std.format;

import std.meta : AliasSeq, staticSort;

//import std.algorithm : sort;

enum {
    BLACK = Color.Black.code,
    RED = Color.Red.code,
    GREEN = Color.Green.code,
    YELLOW = Color.Yellow.code,
    BLUE = Color.Blue.code,
    MAGENTA = Color.Magenta.code,
    CYAN = Color.Cyan.code,
    WHITE = Color.White.code,

    BOLD = Mode.Bold.code,

    BACKGOUND_BLACK = Color.Black.code(true),
    BACKGOUND_RED = Color.Red.code(true),
    BACKGOUND_GREEN = Color.Green.code(true),
    BACKGOUND_YELLOW = Color.Yellow.code(true),
    BACKGOUND_BLUE = Color.Blue.code(true),
    BACKGOUND_MAGENTA = Color.Magenta.code(true),
    BACKGOUND_CYAN = Color.Cyan.code(true),
    BACKGOUND_WHITE = Color.White.code(true),
    BACKGOUND_RESET = Color.Reset.code(true),

    RESET = Color.Reset.code,
    CLEARSCREEN = Cursor.ClearScreen.code(2),
    CLEARDOWN = Cursor.ClearScreen.code(0),
    CLEARUP = Cursor.ClearScreen.code(1),
    CLEARLINE = Cursor.ClearLine.code(2),
    CLEAREOL = Cursor.ClearLine.code(0),

    CR = "\x13",
    NEXTLINE = Cursor.NextLine.code(0),
    HOME = "\u001b[f",
}

enum Color {
    Black,
    Red,
    Green,
    Yellow,
    Blue,
    Magenta,
    Cyan,
    White,
    Reset,
}

string code(
        immutable Color c,
        immutable bool background = false,
        immutable bool bright = false) {
    if (c is Color.Reset) {
        return "\u001b[0m";
    }
    else {
        immutable background_color = (background) ? "4" : "3";
        immutable bright_color = (bright) ? "m" : ";1m";
        return format("\u001b[%s%d%s", background_color, c, bright_color);
    }
    assert(0);
}

enum Cursor : char {
    Up = 'A', /// Moves cursor up by n
    Down = 'B', /// Moves cursor down by n
    Right = 'C', /// Moves cursor right by n
    Left = 'D', /// Moves cursor left by n
    NextLine = 'E', /// Moves cursor to beginning of line n lines down
    PrevLine = 'F', /// Moves cursor to beginning of line n lines down
    SetColumn = 'G', /// Moves cursor to column n
    ClearScreen = 'J', /// clears the screen
    ClearLine = 'K' /// clears the current line
}

string code(immutable Cursor c, immutable uint n = 1) {
    return format("\u001b[%d%s", n, char(c));
}

string linePos(const size_t pos) {
    return format("\r\x1B[%dC", pos);
}

enum Mode {
    None = 0, /// All attributes off
    Bold = 1, /// Bold on
    Underscore = 4, /// Underscore (on monochrome display adapter only)
    Blink = 5, /// Blink on
    Reverse = 7, /// Reverse video on
    Concealed = 8, /// Concealed on
}

string code(immutable Mode m) {
    return format("\u001b[%dm", m);
}

string setCursor(immutable uint row, immutable uint column) {
    return format("\u001b[%d;%dH", row, column);
}

enum saveCursorPos = "\u001b[s"; /// Saves the current cursor position
enum restoreCursorPos = "\u001b[u"; /// Restores the cursor to the last saved position

version (MOBILE) {
}
else {
    private import core.stdc.stdio;
    private import core.sys.posix.termios;

    extern (C) void cfmakeraw(termios* termios_p);

    struct KeyStroke {

        termios ostate; /* saved tty state */
        termios nstate; /* values for editor mode */

        int get()
        out (ret) {
            import std.stdio;

            writef("%d ", ret);

        }
        do {
            // Open stdin in raw mode
            // Adjust output channel
            tcgetattr(1, &ostate); // save old state
            tcgetattr(1, &nstate); // get base of new state
            cfmakeraw(&nstate);
            tcsetattr(1, TCSADRAIN, &nstate); // set mode
            scope (exit) {
                tcsetattr(1, TCSADRAIN, &ostate); // return to original mode
            }
            return fgetc(stdin);
        }

        enum KeyCode {
            NONE,
            UP,
            DOWN,
            LEFT,
            RIGHT,
            HOME,
            END,
            PAGEUP,
            PAGEDOWN,
            ENTER,
            DELETE,
            BACKSPACE,
            F1,
            F2,
            F3,
            F4,
            F5,
            F6,
            F7,
            F8,
            F9,
            F10,
            F11,
            F12,
            CTRL_A,
            CTRL_B,
            CTRL_C,
            CTRL_D,
        }

        struct KeyStrain {
            KeyCode code;
            int[] branch;
            int opComp(const KeyStrain b) const {
                return branch < b.branch;
            }
        }

        enum strain = [
            KeyStrain(KeyCode.UP, [27, 91, 65]),
            KeyStrain(KeyCode.DOWN, [27, 91, 66]),
            KeyStrain(KeyCode.RIGHT, [27, 91, 67]),
            KeyStrain(KeyCode.LEFT, [27, 91, 68]),
            KeyStrain(KeyCode.HOME, [27, 91, 49, 59, 50, 72]),
            KeyStrain(KeyCode.END, [27, 91, 49, 59, 50, 70]),
            KeyStrain(KeyCode.PAGEDOWN, [27, 91, 54, 126]),
            KeyStrain(KeyCode.PAGEUP, [27, 91, 53, 126]),
            KeyStrain(KeyCode.DELETE, [27, 91, 51, 126]),
            KeyStrain(KeyCode.F1, [27, 79, 80]),
            KeyStrain(KeyCode.F2, [27, 79, 81]),
            KeyStrain(KeyCode.F3, [27, 79, 82]),
            KeyStrain(KeyCode.F4, [27, 79, 83]),
            KeyStrain(KeyCode.F5, [27, 91, 49, 53, 126]),
            KeyStrain(KeyCode.F6, [27, 91, 49, 55, 126]),
            KeyStrain(KeyCode.F7, [27, 91, 49, 56, 126]),
            KeyStrain(KeyCode.F8, [27, 91, 49, 57, 126]),
            KeyStrain(KeyCode.F9, [27, 91, 50, 48, 126]),
            KeyStrain(KeyCode.F10, [27, 91, 50, 49, 126]),
            KeyStrain(KeyCode.F11, [27, 91, 50, 51, 126]),
            KeyStrain(KeyCode.F12, [27, 91, 50, 52, 126]),
            KeyStrain(KeyCode.CTRL_A, [1]),
            KeyStrain(KeyCode.CTRL_B, [2]),
            KeyStrain(KeyCode.CTRL_C, [3]),
            KeyStrain(KeyCode.CTRL_D, [4]),
            KeyStrain(KeyCode.ENTER, [13]),
            KeyStrain(KeyCode.BACKSPACE, [127]),
        ];

        KeyCode getKey(ref int ch) {
            import std.algorithm;
            import std.array;

            enum StaticComp(KeyStrain a, KeyStrain b) = a.branch < b.branch;

            enum sorted_strain = strain.array.sort!((a, b) => a.branch < b.branch); //staticSort!(StaticComp, strain);
            KeyCode select(uint index = 0, uint pos = 0)(ref int ch) {
                static if (index < sorted_strain.length) {
                    static if (pos < sorted_strain[index].branch.length) {
                        if (ch == sorted_strain[index].branch[pos]) {
                            static if (pos + 1 is sorted_strain[index].branch.length) {
                                return sorted_strain[index].code;
                            }
                            else {
                                ch = get;
                                return select!(index, pos + 1)(ch);
                            }
                        }
                        else if (ch > sorted_strain[index].branch[pos]) {
                            return select!(index + 1, pos)(ch);
                        }
                        else {
                            return KeyCode.NONE;
                        }
                    }
                    else {
                        return select!(index + 1, pos)(ch);
                    }
                }
                else {
                    return KeyCode.NONE;
                }
            }

            ch = get;
            return select(ch);
        }
    }
}
