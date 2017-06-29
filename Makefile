# Makefile for the open-source release of adventure 2.5

# Note: If you're building from the repository rather than the source tarball,
# do this to get the linenoise library where you can use it:
#
# git submodule update --recursive --remote --init
#
# Therafter, you can update it like this:
#
# git submodule update --recursive --remote
#
# but this should seldom be necessary as that library is pretty stable.
#
# You will also need Python 3 YAML.  Under Debian or ubuntu:
#
# apt-get install python3-yaml
#
# If you have pip installed,
#
# pip3 install PyYAML
#
# If you are using MacPorts on OS X:
# port install py3{5,6}-yaml as appropriate for your Python 3 version.
#
# To build with save/resume disabled, pass CCFLAGS="-D ADVENT_NOSAVE"

VERS=$(shell sed -n <NEWS '/^[0-9]/s/:.*//p' | head -1)

.PHONY: debug indent release refresh dist linty html clean

CC?=gcc
CCFLAGS+=-std=c99 -D _DEFAULT_SOURCE -Wpedantic -O2
LIBS=
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Linux)
	LIBS=-lrt
endif

OBJS=main.o init.o actions.o score.o misc.o saveresume.o
CHEAT_OBJS=cheat.o init.o actions.o score.o misc.o saveresume.o
SOURCES=$(OBJS:.o=.c) advent.h adventure.yaml Makefile control linenoise/linenoise.[ch] make_dungeon.py

.c.o:
	$(CC) $(CCFLAGS) $(DBX) -c $<

advent:	$(OBJS) linenoise.o dungeon.o
	$(CC) $(CCFLAGS) $(DBX) -o advent $(OBJS) dungeon.o linenoise.o $(LDFLAGS) $(LIBS)

main.o:	 	advent.h dungeon.h

init.o:	 	advent.h dungeon.h

actions.o:	advent.h dungeon.h

score.o:	advent.h dungeon.h

misc.o:		advent.h dungeon.h

cheat.o:	advent.h dungeon.h

saveresume.o:	advent.h dungeon.h

dungeon.o:	dungeon.c dungeon.h
	$(CC) $(CCFLAGS) $(DBX) -c dungeon.c

dungeon.c dungeon.h: make_dungeon.py adventure.yaml
	python3 make_dungeon.py

linenoise.o:	linenoise/linenoise.h
	$(CC) -c linenoise/linenoise.c

linenoise-dbg:	linenoise/linenoise.h
	$(CC) $(CCFLAGS) -c linenoise/linenoise.c

clean:
	rm -f *.o advent cheat *.html *.gcno *.gcda
	rm -f dungeon.c dungeon.h
	rm -f README advent.6 MANIFEST *.tar.gz
	rm -f *~
	rm -f .*~
	rm -rf coverage advent.info
	cd tests; $(MAKE) --quiet clean


cheat: $(CHEAT_OBJS) linenoise.o dungeon.o 
	$(CC) $(CCFLAGS) $(DBX) -o cheat $(CHEAT_OBJS) linenoise.o dungeon.o $(LDFLAGS) $(LIBS)

check: advent cheat
	cd tests; $(MAKE) --quiet

coverage: debug cheat
	cd tests; $(MAKE) coverage --quiet

.SUFFIXES: .adoc .html .6

# Requires asciidoc and xsltproc/docbook stylesheets.
.adoc.6:
	a2x --doctype manpage --format manpage $<
.adoc.html:
	asciidoc $<
.adoc:
	asciidoc $<

html: advent.html history.html hints.html

# README.adoc exists because that filename is magic on GitLab.
DOCS=COPYING NEWS README.adoc TODO advent.adoc history.adoc notes.adoc hints.adoc advent.6
TESTFILES=tests/*.log tests/*.chk tests/README tests/decheck tests/Makefile

# Can't use GNU tar's --transform, needs to build under Alpine Linux.
# This is a requirement for testing dist in GitLab's CI pipeline
advent-$(VERS).tar.gz: $(SOURCES) $(DOCS)
	@find $(SOURCES) $(DOCS) $(TESTFILES) -print | sed s:^:advent-$(VERS)/: >MANIFEST
	@(ln -s . advent-$(VERS))
	(tar -T MANIFEST -czvf advent-$(VERS).tar.gz)
	@(rm advent-$(VERS))

indent:
	astyle -n -A3 --pad-header --min-conditional-indent=1 --pad-oper *.c

release: advent-$(VERS).tar.gz advent.html history.html hints.html notes.html
	shipper version=$(VERS) | sh -e -x

refresh: advent.html notes.html history.html
	shipper -N -w version=$(VERS) | sh -e -x

dist: advent-$(VERS).tar.gz

linty: CCFLAGS += -W
linty: CCFLAGS += -Wall
linty: CCFLAGS += -Wextra
linty: CCFLAGS += -Wundef
linty: CCFLAGS += -Wstrict-prototypes
linty: CCFLAGS += -Wmissing-prototypes
linty: CCFLAGS += -Wmissing-declarations
linty: CCFLAGS += -Wshadow
linty: CCFLAGS += -Wfloat-equal
linty: CCFLAGS += -Wcast-align
linty: CCFLAGS += -Wwrite-strings
linty: CCFLAGS += -Waggregate-return
linty: CCFLAGS += -Wcast-qual
linty: CCFLAGS += -Wswitch-enum
linty: CCFLAGS += -Wwrite-strings
linty: CCFLAGS += -Wunreachable-code
linty: CCFLAGS += -Winit-self
linty: CCFLAGS += -Wpointer-arith
linty: advent

debug: CCFLAGS += -O0 --coverage -ggdb
debug: linty
debug: cheat

debug-ln: linenoise-dbg debug
