
import std.stdio;
import std.string;
import std.json;

import dfunctions;

static extern (C) void handler (cdata *d)
{
    nng_url *u;
    string uri;
    string route;
    string[] path;
        
    uri = cast(immutable)(fromStringz(d.uri)) ~ "/xxx";

    auto rc = nng_url_parse(&u, uri.toStringz );
    
    route = cast(immutable)(fromStringz(u.u_path));

    JSONValue data = parseJSON("{}");
    data["a"] = "b";
    data["c"] = 1;
    string s = data.toString;
    
    path = route.split("/");

    writeln("Handled url: "~uri~" Found path: ", path);
    
    nng_url_free(u);

}


int
main()
{
    csrv *s;

    cserver_init(&s, toStringz("myserver"), &handler);

    cserver_start(s);

    writeln("Bye!");
    return 0;

}
