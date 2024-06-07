BEGIN{
    FS=","
    print "module nngd.mime;";
    print "const string[string] nng_mime_map = [";
    print " \".bin\": \"application/octet-stream\"";
}
$1 ~ /Name/ {  next }
$1 ~ /[^a-zA-Z0-9]/ { next }
$2 ~ /^$/ { next }
{
    print ",\"."$1"\": \""$2"\"" ;
    if($1 ~ /[A-Z]/)
    print ",\"."tolower($1)"\": \""tolower($2)"\"" ;
}
END{
    print "];\n";
}
