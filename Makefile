CC?=gcc
SRC=$(shell find ./why -type f -name '*.c')
OBJ=$(SRC:.c=.o)
SHARED=$(SRC:.c=.so)
CFLAGS=-O2 -fpic -Wall -std=c11
CLIB=$(shell pkg-config --cflags --libs lua5.4) -lev -lmagic

.PHONEY: all clean

all: $(SHARED)

%.o: %.c
	$(CC) -Wall $(CFLAGS) -c $< -o $@ $(CLIB)

%.so: %.o
	$(CC) -shared $(CFLAGS) $< -o $@ $(CLIB)

clean:
	rm -f $(OBJ)
	rm -f $(SHARED)

