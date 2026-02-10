source $stdenv/setup
set -xe

echo "Fetching micropython $rev..."
git clone --shallow-since=2025-12-08 --branch "$rev" https://github.com/micropython/micropython
cd micropython
git checkout "$rev" # the initial clone gives a strange warning, so make sure we are on the right commit

git rev-parse HEAD > .gitrev

for s in $submodules; do
  echo "Fetching submodule $s..."
  git submodule init -- $s 2> /dev/null
  git submodule update --depth 1 -- $s 2> /dev/null
done
cd ..

mv micropython $out

cd $out
rm -r $(find -name .git)
