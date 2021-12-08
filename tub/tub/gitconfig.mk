BLANK :=
define NEWLINE

$(BLANK)
endef

export GITWRAPPER_MK=$(DMAKEFILE)/local.gitwrapper.mk
-include $(GITWRAPPER_MK)

GITS:="${subst $(NEWLINE),;,$(GITDEF)}"

export ALL_GIT_COMMANDS:=${shell git help | egrep "^   " | awk '{print $$1}' | egrep '^[a-z]+'}

export GITCONFIG=$(DMAKEFILE)/.gitconfig

all-gits:
	@echo "$(ALL_GIT_COMMANDS)"

.ONESHELL:

define GITWRAPPER
#!${shell which bash}
usage() { echo " usage:" && grep " .)\ #" $$0; exit 0; }
[ $$# -eq 0 ] && usage
while getopts ":hs:ac" arg; do
  case $$arg in
    a) # All submodule including the wrap and tub
       a="ok"
      ;;
    c) # Only not commited.
       c="ok"
      ;;
#    s) # Specify strength, either 45 or 90.
#      strength=$${OPTARG}
      # [ trength -eq 45 -o trength -eq 90 ] #   && echo "Strength is $strength." #   || echo "Strength needs to be either 45 or 90, trength found instead."
#      ;;
    h | *) # Display help.
      usage
      exit 0
      ;;
  esac
done

shift $$((OPTIND-1))

## If -a is not set then wrap repositories is ignored
if [ -z "$${a}" ]; then
if [[ "$$PWD" =~ .*src/wrap.* ]]; then
exit
fi
fi
## Only execute submodules which contais untracked file
if [ -n "$${c}" ]; then
git ls-files . --exclude-standard --others
NOTADDED=$$(git ls-files . --exclude-standard --others)
if [ -z "$$NOTADDED" ]; then
exit
fi
fi

GIT_ALIAS=$$(git --no-pager config --file /home/carsten/work/regression/.gitconfig --get alias.$$1)
if [ -z "$$GIT_ALIAS" ]; then
    GIT_ALIAS=$$(git --no-pager config --get alias.$$1)
fi

if [ -z "$$GIT_ALIAS" ]; then
    GIT_ALIAS=$$@
else
    GIT_COMMAND=1
    [[ "$$GIT_ALIAS" =~ '^!.*' ]] && echo match
    shift;
    GIT_ALIAS=$$(echo $$GIT_ALIAS | sed "s/^!//") $$@
fi

COMMAND=$$(echo "$$GIT_ALIAS" | awk '{print $$1}')

if [ -n "$$GIT_COMMAND" ] || [[ "$$COMMAND" =~ ^($$ALL_GIT_COMMAND) ]]; then
    # Add a git if it is an git alias or and git command
    [[ "$$GIT_ALIAS " =~ (^git.*) ]] || GIT_ALIAS="git $$GIT_ALIAS"
fi

#echo "$$GIT_ALIAS";
cd $$PWD; $$GIT_ALIAS;
endef # GITWRAPPER

define COPY_GITCONFIG
export UUID=${shell uuidgen}
export GITSCRIPT=/tmp/git_$$UUID.sh
export GITHELP=/tmp/help_$$UUID.sh
export TMPFILE=/tmp/$$UUID.tmp
git --no-pager config --file $$GITCONFIG --list > $$TMPFILE
echo $$TMPFILE
cat $$TMPFILE
perl -pe 's/=.+//' $$TMPFILE
DEFLIST=$$(perl -pe 's/=.+//' $$TMPFILE)
echo $$DEFLIST
SHFILE=/tmp/${shell uuidgen}.sh
echo "### Create script $$SHFILE"
echo "#!$$(which sh)" > $$SHFILE
for def in $$(perl -pe 's/=.+//' $$TMPFILE)
do
VALUE=$$(git config --file $$GITCONFIG --get $$def)
echo $$VALUE |  perl -pe 's/([\"])/\\$$1/g'
echo git config $$def \'$$VALUE\' >> $$SHFILE
done

cat >> $$SHFILE <<EOF
git config alias.all '!git submodule foreach --recursive $$GITSCRIPT '
exit 0
EOF

#echo DUMP
#cat $$SHFILE
chmod 750 $$SHFILE
$$SHFILE
git submodule foreach --recursive $$SHFILE
echo "### Create the git wrapper $$GITSCRIPT"
cat > $$GITSCRIPT << EOF
$$GITWRAPPER
EOF

chmod 750 $$GITSCRIPT

echo $$GITWRAPPER_MK
cat > $$GITWRAPPER_MK << EOF
export GITWRAPPER=$$GITSCRIPT
EOF

endef

#GITLIST=git --no-pager config --file $(GITCONFIG) --list
#GITALIAS=$(GITLIST) | perl -pe 's/=.+//'
#GETALIAS=${addprefix git config --file $(GITCONFIG) --get ,${shell $(GITALIAS)}}

#|xargs git config --file $(GITCONFIG)
#GITSETS=$(GITALIAS) | xargs git config --file $(GITCONFIG) --get

gits:
	$(PRECMD)$(GITLIST)
	$(PRECMD)$(GITALIAS)
	$(PRECMD)echo $(GETALIAS)
	$(PRECMD)echo GITWRAPPER_MK $(GITWRAPPER_MK)

-include $(GITWRAPPER_MK)

gitconfig: $(GITWRAPPER_MK)

$(GITWRAPPER_MK): $(GITCONFIG)
	@$(COPY_GITCONFIG)


UUID1=${shell uuidgen}

test33:
	@echo $(UUID1)
