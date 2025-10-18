CC?=gcc
SRC=getopt.c fs.c server.c hash.c
OBJ=$(SRC:.c=.o)
CFLAGS=-fpic -Wall -std=c11
CLIB=$(shell pkg-config --cflags --libs lua5.4)

.PHONEY: all clean

all: $(OBJ)

%.o: %.c
	$(CC) -Wall $(CFLAGS) -c $< -o $@ $(CLIB)

%.so: %.o
	$(CC) -shared $(CFLAGS) $< -o $@

clean:
	rm -f $(OBJ)

