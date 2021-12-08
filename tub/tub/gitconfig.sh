#!/usr/bin/env bash

GITCONFIG=$1/../.gitconfig
ALIAS_NAMES=$(perl -pe 's/=.+//' $GITCONFIG | grep -wv alias)

GITDIRS=$(git submodule foreach pwd | grep -wv Entering)
GITDIRS="$GITDIRS $(pwd)"

function clean_alias() {
    for GITDIR in $GITDIRS; do
        echo "Cleaning git aliases for $GITDIR"
        ALIASES_LOCAL=$(
            cd $GITDIR
            git config --local --list | grep alias.
        )
        for ALIAS_LOCAL in $ALIASES_LOCAL; do
            if [[ $ALIAS_LOCAL =~ "alias." ]]; then
                ALIAS_LOCAL_PURE=${ALIAS_LOCAL%=*}
                cd $GITDIR
                git config --local --unset-all $ALIAS_LOCAL_PURE
            fi
        done
    done
}

function set_alias() {
    for GITDIR in $GITDIRS; do
        echo "Setting git aliases for $GITDIR"
        cd $GITDIR
        git config --local --add alias.all "!f() { $1/gitforeach.sh all "\$@"; }; f"
        git config --local --add alias.drt "!f() { $1/gitforeach.sh dirty "\$@"; }; f"
        for ALIAS_NAME in $ALIAS_NAMES; do
            ALIAS_VALUE=$(git config -f $GITCONFIG --get alias.$ALIAS_NAME)
            git config --local --add alias.$ALIAS_NAME "$ALIAS_VALUE"
        done
    done
}

clean_alias
set_alias $1

echo 
echo "Git aliases:"
cat $GITCONFIG

echo "You can also use:"
echo -e "\tgit all * (execute on all submodules, e.g., git all hash)"
echo -e "\tgit drt * (execute on dirty submodules, e.g., git all hash)"
echo 