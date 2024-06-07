public import tagion.tools.nodeinterfaceutil.raylib_c;

import m = std.math;
import rl = tagion.tools.nodeinterfaceutil.raylib_c;

void DrawText(const(char)[] text, int posX, int posY, int fontSize, Color color) {
    rl.DrawText(&(text ~ '\0')[0], posX, posY, fontSize, color);
}

enum Colors {
    LIGHTGRAY = Color(200, 200, 200, 255), // Light Gray
    GRAY = Color(130, 130, 130, 255), // Gray
    DARKGRAY = Color(80, 80, 80, 255), // Dark Gray
    YELLOW = Color(253, 249, 0, 255), // Yellow
    GOLD = Color(255, 203, 0, 255), // Gold
    ORANGE = Color(255, 161, 0, 255), // Orange
    PINK = Color(255, 109, 194, 255), // Pink
    RED = Color(230, 41, 55, 255), // Red
    MAROON = Color(190, 33, 55, 255), // Maroon
    GREEN = Color(0, 228, 48, 255), // Green
    LIME = Color(0, 158, 47, 255), // Lime
    DARKGREEN = Color(0, 117, 44, 255), // Dark Green
    SKYBLUE = Color(102, 191, 255, 255), // Sky Blue
    BLUE = Color(0, 121, 241, 255), // Blue
    DARKBLUE = Color(0, 82, 172, 255), // Dark Blue
    PURPLE = Color(200, 122, 255, 255), // Purple
    VIOLET = Color(135, 60, 190, 255), // Violet
    DARKPURPLE = Color(112, 31, 126, 255), // Dark Purple
    BEIGE = Color(211, 176, 131, 255), // Beige
    BROWN = Color(127, 106, 79, 255), // Brown
    DARKBROWN = Color(76, 63, 47, 255), // Dark Brown

    WHITE = Color(255, 255, 255, 255), // White
    BLACK = Color(0, 0, 0, 255), // Black
    BLANK = Color(0, 0, 0, 0), // Blank (Transparent)
    MAGENTA = Color(255, 0, 255, 255), // Magenta
    RAYWHITE = Color(245, 245, 245, 255), // My own White (raylib logo)
}

Color ColorLerp(Color c1, Color c2, float alpha) {
    ubyte r = cast(ubyte)((1 - alpha) * c1.r + alpha * c2.r);
    ubyte g = cast(ubyte)((1 - alpha) * c1.g + alpha * c2.g);
    ubyte b = cast(ubyte)((1 - alpha) * c1.b + alpha * c2.b);
    ubyte a = cast(ubyte)((1 - alpha) * c1.a + alpha * c2.a);

    return Color(r, g, b, a);
}

Vector2 Vector2Subtract(Vector2 v1, Vector2 v2) {
    Vector2 result = { v1.x - v2.x, v1.y - v2.y };

    return result;
}

float Vector2Length(Vector2 v) {
    float result = m.sqrt((v.x*v.x) + (v.y*v.y));

    return result;
}
