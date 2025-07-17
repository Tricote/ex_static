#!/bin/bash

rm -rf public/
mix deps.get --only prod
MIX_ENV=prod mix deps.compile
MIX_ENV=prod mix assets.deploy
MIX_ENV=prod mix compile
echo y |MIX_ENV=prod mix release
_build/prod/rel/ex_static/bin/ex_static daemon
sleep 2

# cf Wget options: https://www.man7.org/linux/man-pages/man1/wget.1.html
# -r (or --recursive) Recursive retrieving. The default maximum depth is 5
# -k (or --convert-links) will convert links in the web pages to relative after the download finishes
# -E (or --adjust-extension) If a file of type application/xhtml+xml or text/html is
#   downloaded and the URL does not end with the regexp
#   \.[Hh][Tt][Mm][Ll]?, this option will cause the suffix .html
#   to be appended to the local filename.
# -P (or --directory-prefix) the directory where all other files and subdirectories will be saved to
# --no-host-directories Disable generation of host-prefixed directories
#   (no additional http://localhost:4000/ directory created,
#   files will be saved directly in the directory specified in the -P argument)
wget -r -k -E -P public/ --no-host-directories http://localhost:4000/

# 5. Stop the server
_build/prod/rel/ex_static/bin/ex_static stop