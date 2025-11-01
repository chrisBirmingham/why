CC?=gcc
SRC=$(shell find ./why -type f -name '*.c')
OBJ=$(SRC:.c=.o)
SHARED=$(SRC:.c=.so)
CFLAGS?=-O2 -fpic -Wall -std=c11
CLIB=$(shell pkg-config --cflags --libs lua5.4) -lev -lmagic

PROG?=why
PREFIX?=/usr/local
LUA_VERSION=5.4

SHARE_DIR=$(PREFIX)/share/lua/$(LUA_VERSION)/$(PROG)
LIB_DIR=$(PREFIX)/lib/lua/$(LUA_VERSION)/$(PROG)

.PHONEY: all install uninstall clean

all: $(SHARED)

%.o: %.c
	$(CC) -Wall $(CFLAGS) -c $< -o $@ $(CLIB)

%.so: %.o
	$(CC) -shared $(CFLAGS) $< -o $@ $(CLIB)

install:
	mkdir -p $(SHARE_DIR)
	cp why/*.lua $(SHARE_DIR)
	mkdir -p $(LIB_DIR)
	cp why/*.so $(LIB_DIR)
	cp why.lua $(PREFIX)/bin/$(PROG)
	mkdir -p /etc/why
	cp config/conf.lua /etc/why

uninstall:
	rm -rf $(SHARE_DIR)
	rm -rf $(LIB_DIR)
	rm -f $(PREFIX)/bin/$(PROG)
	rm -f /etc/why/conf.lua

clean:
	rm -f $(OBJ)
	rm -f $(SHARED)

