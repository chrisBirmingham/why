# Why

An event driven Lua SCGI web server that serves all requests from memory.
Influenced by [StaticHttpFileServer](https://github.com/andrewrk/StaticHttpFileServer)

When run, why scans the entire document root and reads all files into memory. 
As it's reading all files it will perform several additional tasks.

If an associated `.gz` or `.br` file exists, they will also be read into memory
and will be served to the client if they support compressed responses. Brotli
compressed files are favoured over gziped files if both are present.

If an `index.html` file exists that will be served when a client requests 
a directory i.e `/about` => `/about.html`

Why will also create a murmur hash of all read files and will respond with
that hash in the `Etag` response header. If the client sends in the same `Etag`
in the request for the same file, Why will respond with a `304 Not Modified`
http response.

Why won't check the filesystem again until it's either reloaded via a `SIGHUP`
signal or it's restarted. It's up to you to refresh it's memory should it's
cache become out of date.

## Requirements 

* (gnu) make
* A version of gcc or clang that supports c11
* A (*)nix based operating system
* Lua 5.4
* [Libmagic](https://www.man7.org/linux/man-pages/man3/libmagic.3.html)
* [Libev](https://software.schmorp.de/pkg/libev.html)
* [Luarocks](https://luarocks.org/)

## Installation

Why can be installed via Luarocks or Make

### Luarocks

```commandline
cd why
luarocks make
```

### Make:

```commandline
cd why
make
[sudo] make install
```

You can specify the `PREFIX` variable to set where Why will be installed. By
default it installs into /usr/local.

## Usage

Why can be invoked like so:

```commandline
why [options] [config file]
```

If no options are provided, Why will try to read the default config file at
`/etc/why/conf.lua` and start the server. You can provide the `-f` option to
tell Why to read a different config file.

If provide the `-t` flag, Why will only read and validate the config file. 

### Example config file

Why's config file is lua file like so:

```lua
return {
    port = 8000,
    document_root = '/var/www/html'
}
```

The config file includes these options:

* document_root - The absolute filepath to the folder containing your files
* port - The tcp port to listen on
* socket - The absolute filepath to the unix domain socket

You must provide the `document_root` value and must provide either the `port`
or `socket` values.

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
	"/" => ((
        "host" => "127.0.0.1",
	    "port" => 8000,
	    "check-local" => "disable"
    ))
)
```

By default, lighttpd will check to see if the file exists and will serve a 
`404 Not Found` response if it doesn't instead of calling Why. If you don't 
want this behavior, set the option to `disable`.

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

## Systemd

You can also run Why as a Systemd service. I have provided an exmaple Systemd
service file within this repo. Why also supports a systemd reload request via
a `SIGHUP` signal. This will cause Why to stop the server, reread it's config
file, load the files back into memory and restart the server.

