#!/usr/bin/env ruby
# coding: ASCII-8BIT

# Converts a .bin file into a .uf2 file for the RP2040's flash memory.

input_filename = ARGV.fetch(0)
output_filename = ARGV.fetch(1)

UF2_FLAG_FAMILY_ID_PRESENT = 0x2000
RP2040_FAMILY_ID = 0xe48bff56

image = File.open(input_filename, 'rb') { |f| f.read }

block_map = {}
(0...image.size).step(256) do |offset|
  block = image[offset, 256].ljust(256, "\xFF")
  block_map[offset] = block if block != "\xFF" * 256
end

# Workaround for bug RP2040-E14 documented in the RP2040 datasheet.
# If we write to any part of a 4 KB sector, write the whole sector.
block_map.keys.each do |offset|
  (0...4096).step(256) do |i|
    block_map[(offset & ~4095) + i] ||= "\xFF" * 256
  end
end

File.open(output_filename, 'wb') do |output|
  block_map.keys.sort.each_with_index do |offset, block_number|
    address = offset + 0x1000_0000
    block = block_map.fetch(offset)
    uf2_block = "UF2\n\x57\x51\x5D\x9E" +
      [UF2_FLAG_FAMILY_ID_PRESENT, address, block.size,
      block_number, block_map.size, RP2040_FAMILY_ID].pack('VVVVVV') +
      block.ljust(476, "\x00") + "\x30\x6F\xB1\x0A"
    output.write uf2_block
  end
end
