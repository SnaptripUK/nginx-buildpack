#!/bin/bash
# Build NGINX and modules on Heroku.
# This program is designed to run in a web dyno provided by Heroku.
# We would like to build an NGINX binary for the builpack on the
# exact machine in which the binary will run.
# Our motivation for running in a web dyno is that we need a way to
# download the binary once it is built so we can vendor it in the buildpack.
#
# Once the dyno has is 'up' you can open your browser and navigate
# this dyno's directory structure to download the nginx binary.

NGINX_VERSION=${NGINX_VERSION-1.9.7}
PCRE_VERSION=${PCRE_VERSION-8.21}
HEADERS_MORE_VERSION=${HEADERS_MORE_VERSION-0.29}
OPEN_SSL_VERSION=${OPEN_SSL_VERSION-1.0.1p}

nginx_tarball_url=http://nginx.org/download/nginx-${NGINX_VERSION}.tar.gz
pcre_tarball_url=http://netcologne.dl.sourceforge.net/project/pcre/pcre/${PCRE_VERSION}/pcre-${PCRE_VERSION}.tar.bz2
headers_more_nginx_module_url=https://github.com/agentzh/headers-more-nginx-module/archive/v${HEADERS_MORE_VERSION}.tar.gz
open_ssl_url=https://www.openssl.org/source/openssl-${OPEN_SSL_VERSION}.tar.gz
lua_jit_url=http://luajit.org/download/LuaJIT-2.0.4.tar.gz
nginx_devel_kit_url=https://github.com/simpl/ngx_devel_kit/archive/v0.3.0.tar.gz
nginx_lua_module_url=https://github.com/openresty/lua-nginx-module/archive/v0.10.8.tar.gz

temp_dir=$(mktemp -d /tmp/nginx.XXXXXXXXXX)

#num_cpu_cores=$(grep -c ^processor /proc/cpuinfo)

echo "Serving files from /tmp on $PORT"
cd /tmp
python -m SimpleHTTPServer $PORT &

cd $temp_dir
echo "Temp dir: $temp_dir"

echo "Downloading $nginx_tarball_url"
curl -L $nginx_tarball_url | tar xzv

echo "Downloading $pcre_tarball_url"
(cd nginx-${NGINX_VERSION} && curl -L $pcre_tarball_url | tar xvj )

echo "Downloading $headers_more_nginx_module_url"
(cd nginx-${NGINX_VERSION} && curl -L $headers_more_nginx_module_url | tar xvz )

echo "Downloading $open_ssl_url"
(cd nginx-${NGINX_VERSION} && curl -L $open_ssl_url | tar xvz )

echo "Downloading $lua_jit_url"
curl -L $lua_jit_url | tar xzv

echo "Downloading $nginx_devel_kit_url"
curl -L $nginx_devel_kit_url | tar xzv

echo "Downloading $nginx_lua_module_url"
curl -L $nginx_lua_module_url | tar xzv

cd LuaJIT-2.0.4
make && sudo make install
cd $temp_dir

export LUAJIT_LIB=/usr/local/lib
export LUAJIT_INC=/usr/local/include

(
	cd nginx-${NGINX_VERSION}
	./configure \
		--with-pcre=pcre-${PCRE_VERSION} \
		--prefix=/tmp/nginx \
		--with-ld-opt="-Wl,-rpath,${LUAJIT_LIB}" \
		--add-module=/${temp_dir}/nginx-${NGINX_VERSION}/headers-more-nginx-module-${HEADERS_MORE_VERSION} \
   	    --add-module=/${temp_dir}/ngx_devel_kit-0.3.0
	    --add-module=/${temp_dir}/lua-nginx-module-0.10.8
		--with-http_ssl_module --with-openssl=${temp_dir}/nginx-${NGINX_VERSION}/openssl-${OPEN_SSL_VERSION} \
		--with-http_realip_module
	make install
)

while true
do
	sleep 1
	echo "."
done
