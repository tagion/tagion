#!/bin/sh

# Automatically format staged d files
# It automatically restages the files after formatting
# So if you stage a file then change it. Then that change will also be committed.

# install this by putting it in .git/hooks/ and making it executable
 
exec 1>&2
STAGED_DFILES=$(git diff --name-only --cached --diff-filter=ACM | grep '\.d$')

test -n $STAGED_DFILES && dfmt -i $STAGED_DFILES && git add $STAGED_DFILES

