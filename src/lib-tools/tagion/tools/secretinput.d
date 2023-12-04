module tagion.tools.secretinput;

import core.stdc.stdio : getchar;
import std.stdio;
import tagion.utils.Term;
import std.algorithm;
import std.format;
import std.range;
import std.array;

KeyStroke.KeyCode getSecret(string text, out char[] passwd) {
    enum NUL = char(0);
    char[] result;
    KeyStroke key;
    KeyStroke.KeyCode keycode;
    enum MAX_SIZE = 0x100;
    char[MAX_SIZE] password;
    scope (exit) {
        password[] = 0;
    }
    password[] = 0;
    int pos;
    bool show_password;
    size_t passwordSize() {
        const count = (cast(ubyte[]) password).countUntil!(b => b == 0);
        if (count < 0) {
            return password.length;
        }
        return cast(size_t) count;

    }

    void display() {
        char[] show;
        if (show_password) {
            show = password[0 .. passwordSize];
        }
        else {
            show = repeat('*', passwordSize).array;
        }
        writef("\r%s%s%s%s", CLEAREOL, text,
                show,
                linePos(pos + text.length));
        stdout.flush;
    }

    InputLoop: for (;;) {
        display;
        int ch;
        keycode = key.getKey(ch);
        if (keycode == KeyStroke.KeyCode.ENTER) {
            break;
        }
        with (KeyStroke.KeyCode) {
            switch (keycode) {
            case ENTER:
                break InputLoop;
            case LEFT:
                pos -= (pos > 0);
                break;
            case RIGHT:
                pos += (pos < password.length);
                break;
            case DELETE:
                if (pos < password.length) {
                    password = password[0 .. pos] ~ password[pos + 1 .. $] ~ NUL;
                }
                break;
            case BACKSPACE:
                if (pos > 0) {
                    password = password[0 .. pos - 1] ~ password[pos .. $] ~ NUL;
                    pos--;
                }

                break;
            case CTRL_A:
                show_password = !show_password;
                break;
            case CTRL_C, CTRL_D:
                return keycode;

            case NONE:
                if (ch > 0x20 && ch < 127 && pos < password.length) {
                    password[pos] = cast(char) ch;
                    pos += (pos < password.length);
                }
                break;
            default:
            }
        }
    }
    show_password = false;
    display;
    writeln;
    passwd = password[0 .. passwordSize].dup;
    return KeyStroke.KeyCode.NONE;
}
