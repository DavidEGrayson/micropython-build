source $stdenv/setup
set -u

# This date shows up in file creation/modification timestamps.
SOURCE_DATE_EPOCH=$(date -u --date=$date +%s)

# Expand MicroPython image to 1 MiB.
ruby -e 'print ARGF.read.b.ljust(1024*1024, "\xFF")' $base/*.bin > base.bin

# Create a 15 MiB FAT file system.
ruby -e 'print "\xFF"*('$image_size_mb'-1)*1024*1024' > files.bin
faketime $date mkfs.fat -S 4096 -s 1 -f 1 -g 255/63 \
  -i 0 -n 'MicroPython' files.bin

# Assemble the files for the file system.

cp --no-preserve=mode -r $example_code/micropython_demo files
cp --no-preserve=mode -r $base/licenses files/
cp $example_code/LICENSE.txt files/licenses/LICENSE_pololu.txt
cp $example_code/LICENSE_* files/licenses/

cat > files/_README.html <<END
<!DOCTYPE html>
<html lang="en">
<head><title>$board_name</title></head><body>

<p style="font-size: 120%; text-align: center">
To get started with the $board_name, please visit our website:<br><br>
<strong>
  <a href="$start_url">$start_url</a>
</strong>
</p></body></html>
END

# Copy the files into the file system.
faketime $date mcopy -i files.bin -s files/* ::

cat base.bin files.bin > image.bin

mkdir $out
ruby $bin2uf2 image.bin $out/$name.uf2
