source $stdenv/setup

echo "Fetching micropython $version..."
git clone --shallow-since=2025-12-08 --branch "$version" https://github.com/micropython/micropython 2> /dev/null
cd micropython

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

