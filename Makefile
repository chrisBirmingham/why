CC?=gcc
SRC=$(shell find ./why -type f -name '*.c')
OBJ=$(SRC:.c=.o)
SHARED=$(SRC:.c=.so)
CFLAGS?=-O2 -fpic -Wall -std=c11
CLIB=$(shell pkg-config --cflags --libs lua5.4) -lev -lmagic

PROG?=why
PREFIX?=/usr/local
LUA_VERSION=5.4

SHAREDIR=$(PREFIX)/share/lua/$(LUA_VERSION)/$(PROG)
LIBDIR=$(PREFIX)/lib/lua/$(LUA_VERSION)/$(PROG)
BINDIR=$(PREFIX)/bin
MANDIR=$(PREFIX)/share/man/man1/

.PHONEY: all install uninstall clean

all: $(SHARED)

%.o: %.c
	$(CC) -Wall $(CFLAGS) -c $< -o $@ $(CLIB)

%.so: %.o
	$(CC) -shared $(CFLAGS) $< -o $@ $(CLIB)

install:
	mkdir -p $(SHAREDIR)
	cp why/*.lua $(SHAREDIR)
	mkdir -p $(LIBDIR)
	cp why/*.so $(LIBDIR)
	cp why.lua $(BINDIR)/$(PROG)
	mkdir -p $(MANDIR)
	cp man/why.1 $(MANDIR)
	mkdir -p /etc/why
	cp config/conf.lua /etc/why

uninstall:
	rm -rf $(SHAREDIR)
	rm -rf $(LIBDIR)
	rm -f $(BINDIR)/$(PROG)
	rm -f $(MANDIR)/why.1
	rm -f /etc/why/conf.lua

clean:
	rm -f $(OBJ)
	rm -f $(SHARED)

