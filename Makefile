CC?=gcc
OBJ=fs.so server.so

.PHONEY: all clean

all: $(OBJ)

%.o: %.c
	$(CC) -Wall -fpic -c $< -o $@ -I/usr/include/lua5.4

%.so: %.o
	$(CC) -shared -fpic $< -o $@

clean:
	rm -f $(OBJ)

