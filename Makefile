CC?=gcc
SRC=src/getopt.c src/fs.c src/server.c src/hash.c src/mimetype.c
OBJ=$(SRC:.c=.so)
CFLAGS=-O2 -fpic -Wall -std=c11
CLIB=$(shell pkg-config --cflags --libs lua5.4) -lev -lmagic

.PHONEY: all clean

all: $(OBJ)

%.o: %.c
	$(CC) -Wall $(CFLAGS) -c $< -o $@ $(CLIB)

%.so: %.o
	$(CC) -shared $(CFLAGS) $< -o $@ $(CLIB)

clean:
	rm -f $(OBJ)

