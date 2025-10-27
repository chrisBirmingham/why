# Why

A Lua SCGI web server that reads all files within the document root and stores
them into memory. When serving requests, Why doesn't make any filesystem
accesses and serves everything from memory.

While scanning the document root, it will check if there are associated `.gz`
or `.br` files and store them into memory as well. When a client that supports
compressed responses requests a file, Why will serve the compressed files
content instead. Brotli compression is favoured over gzip.

Why will also work out the murmur hash of each file and use that as the Etag.
If a client provides the same Etag in the request Why will return with a 304
not modified response.

Should a client request a directory and an associated `index.html` file exists
inside the directory, that file will be served instead otherwise Why will
return a 404 response.

## Requirements 

* (gnu) make
* A version of gcc or clang that supports c11
* A (*)nix based operating system
* Lua 5.4
* [Libmagic](https://www.man7.org/linux/man-pages/man3/libmagic.3.html)
* [Libev](https://software.schmorp.de/pkg/libev.html)

## Features

* HTTP HEAD GET AND OPTIONS methods supported
* Serving brotli and gzip compressed responses when available
* Etag support
* Clean urls

## Usage

Why can be invoked in one of two methods:

```commandline
why -p <port> <document root>
```

or

```commandline
why -f <path to config file>
```

The `-f` commandline option overrides values provided via the first method.

### Example config file

```lua
return {
    port = 8000,
    doc_root = '/var/www/html'
}
```

## Setup

As Why uses SCGI you'll need a proxy server to convert incoming HTTP requests
into SCGI requests. Two examples are Lighttpd and Nginx.

### Lighttpd

For lighttpd, add this to your `lighttpd.conf` file:

```conf
server.modules += (
	"mod_scgi"
)

scgi.server = (
	"/" =>
	(( "host" => "127.0.0.1",
	   "port" => 8000,
	   "check-local" => "disable" ))
)
```

The `check-local` tells lighty to check the filesystem to see if the requested
file exists. If enabled, lighty will return a 404 if the file doesn't exist
and won't call Why. If you prefer this behavour, you can set it to 
`enabled`.

### Nginx

For nginx add this to your nginx config:

```nginx
server {
    listen 80;
    server_name example.com;

    location / {
        scgi_pass 127.0.0.1:8000;
        include scgi_params;
    }
}
```

