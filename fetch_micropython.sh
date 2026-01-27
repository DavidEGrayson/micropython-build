source $stdenv/setup
set -e

echo "Fetching micropython $rev..."
git clone --shallow-since=2025-12-08 --branch "$rev" https://github.com/micropython/micropython

cd micropython
git checkout "$rev" # the clone gives a warning, so make sure we are on the right commit
git rev-parse HEAD > .gitrev
git submodule update --depth 1 --init -- $submodules
rm -r $(find -name .git)
cd ..

mv micropython $out
