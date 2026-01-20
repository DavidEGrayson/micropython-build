source $stdenv/setup
set -u

cp --no-preserve=mode -r $src src
cd src

export MICROPY_GIT_HASH=$(head -c 9 .gitrev)
export MICROPY_GIT_TAG=$mpy_git_tag
banner="MicroPython ${MICROPY_GIT_TAG} build ${build_git_tag}; with ulab ${ulab_git_tag}";

for patch in $patches; do
  echo applying patch $patch
  patch -p1 -i $patch
done

cd lib/pico-sdk
for patch in $pico_sdk_patches; do
  echo applying patch $patch
  patch -p1 -i $patch
done
cd ../..

cat >> ports/rp2/boards/$MICROPY_BOARD/mpconfigboard.h <<END
#define MICROPY_BANNER_NAME_AND_VERSION "$banner"
#define MICROPY_PY_SYS_EXC_INFO 1
END

rm ports/rp2/modules/_boot.py

# Remove unused licenses
rm -r ports/{cc3200,nrf,samd} \
  tools/mpremote docs/license.rst \
  lib/tinyusb/lib/{fatfs,SEGGER_RTT} \
  lib/tinyusb/hw/bsp/espressif \
  lib/pico-sdk/test \
  lib/pico-sdk/src/rp2_common/pico_btstack/LICENSE.RP

mkdir -p $out/licenses
mv LICENSE $out/licenses/LICENSE_micropython.txt
mv lib/mbedtls/LICENSE $out/licenses/LICENSE_mbedtls.txt
mv lib/micropython-lib/LICENSE $out/licenses/LICENSE_micropython_lib.txt
mv lib/tinyusb/LICENSE $out/licenses/LICENSE_tinyusb.txt
mv lib/pico-sdk/LICENSE.TXT $out/licenses/LICENSE_pico_sdk.txt
mv lib/pico-sdk/src/rp2_common/pico_printf/LICENSE $out/licenses/LICENSE_pico_printf.txt
mv lib/pico-sdk/src/rp2_common/cmsis/stub/CMSIS/LICENSE.txt $out/licenses/LICENSE_cmsis.txt
matches=$(find . -iname 'LICENSE*' -print)
if [[ -n $matches ]]; then
  echo "Error: Found LICENSE files that we should move to output or remove:"
  echo "$matches"
  exit 1
fi

cd ..

# This date shows up in sys.version.
SOURCE_DATE_EPOCH=$(date -u --date=$date +%s)

mkdir build
cd build
cmake ../src/ports/rp2 $cmake_flags
cmake --build . -j

cp --no-preserve=mode firmware.uf2 $out/$name.uf2
cp --no-preserve=mode firmware.bin $out/$name.bin
cp --no-preserve=mode firmware.elf $out/$name.elf

echo "Built $banner"
