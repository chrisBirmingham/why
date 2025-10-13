CC?=gcc
OBJ=fs.so server.so
CFLAGS=-fpic -Wall -std=c11

.PHONEY: all clean

all: $(OBJ)

%.o: %.c
	$(CC) -Wall $(CFLAGS) -c $< -o $@ -I/usr/include/lua5.4

%.so: %.o
	$(CC) -shared $(CFLAGS) $< -o $@

clean:
	rm -f $(OBJ)

