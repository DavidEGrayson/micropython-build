let

  # This date is used to identify releases.  It gets baked into the filenames,
  # file system timestamps, and `sys.version` in Python.
  date = "2025-01-19";

  short_date = (builtins.substring 2 2 date) +
    (builtins.substring 5 2 date) + (builtins.substring 8 2 date);

  build_git_tag = if builtins.getEnv "COMMIT" == "" then
    builtins.throw "Be sure to use build.sh.  See README." else
    short_date + "-" + builtins.getEnv "COMMIT";

  # nixos-24.11 branch, 2024-12-14
  nixpkgs = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/a0f3e10d94359665dba45b71b4227b0aeb851f8e.tar.gz";
    sha256 = "0nci4yyxpjhvkmgvb97xjqaql6dbd3f7xmqa8ala750y6hshhv19";
  });
  pkgs = nixpkgs {};

  micropython = {
    src = pkgs.fetchFromGitHub {
      owner = "micropython";
      repo = "micropython";
      rev = "ecfdd5d6f9be971852003c2049600dc7b3e2a838"; # 1.24.1
      hash = "sha256-Dc40uLyLQBfs8Elku8g+sTz/OETsFNqLqp/xnbF/rn4=";
    };

    patches = [
      ./mpy-traceback.patch

       # Change the Pico firmware to use a 1MB USB Mass Storage filesystem.
      ./pico-1mb-mass-storage.patch
    ];

    # After changing the MicroPython version above, run
    # 'git describe --tags --match=v*' to get the new values for these:
    version = "v1.24.1";
    version_suffix = ""; # e.g. "-47"
  };

  # Submodules of MicroPython needed by the RP2 port.
  # We could try 'fetchSubmodules = true;' above but that would fetch lots of repositories
  # we don't need, and it won't work with submodules that come from private URLs.
  #
  # After changing the MicroPython version, get the info you need to update this by
  # running in the MicroPython repository:
  #   cd ports/rp2 && make submodules && git submodule status --recursive | grep '^ '
  lib_axtls = pkgs.fetchFromGitHub {
    owner = "micropython";
    repo = "axtls";
    rev = "531cab9c278c947d268bd4c94ecab9153a961b43";
    hash = "sha256-+Uh598l4ri6y5nwoV+bPozmpHlhpzOO2LLaRVOIj6hU=";
  };
  lib_berkeley_db = pkgs.fetchFromGitHub {
    owner = "pfalcon";
    repo = "berkeley-db-1.xx";
    rev = "85373b548f1fb0119a463582570b44189dfb09ae";
    hash = "sha256-HyQXMy5mruTQHL4LcACfLxJGhu6jpOSQbnbS/A/aGE0=";
  };
  lib_mbedtls = pkgs.fetchFromGitHub {
    owner = "ARMmbed";
    repo = "mbedtls";
    rev = "edb8fec9882084344a314368ac7fd957a187519c";
    hash = "sha256-HxsHcGbSExp1aG5yMR/J3kPL4zqnmNoN5T5wfV3APaw=";
  };
  lib_micropython_lib = pkgs.fetchFromGitHub {
    owner = "micropython";
    repo = "micropython-lib";
    rev = "68e3e07bc7ab63931cead3854b2a114e9a084248";
    hash = "sha256-ZL0zKCGzMpK4L/394JP+Xhu9dNPkLWVzqDppPVDNBnw=";
  };
  lib_pico_sdk = pkgs.fetchFromGitHub {
    owner = "raspberrypi";
    repo = "pico-sdk";
    rev = "efe2103f9b28458a1615ff096054479743ade236";
    hash = "sha256-d6mEjuG8S5jvJS4g8e90gFII3sEqUVlT2fgd9M9LUkA=";
  };
  lib_tinyusb = pkgs.fetchFromGitHub {
    owner = "hathach";
    repo = "tinyusb";
    rev = "5217cee5de4cd555018da90f9f1bcc87fb1c1d3a";
    hash = "sha256-spkx1LbRfIzSpZVTBj2Y6z9AB51blvrDxF6nBXnVvGw=";
  };

  pico_sdk_patches = [ ];

  ulab_src = pkgs.fetchFromGitHub {
    owner = "v923z";
    repo = "micropython-ulab";
    rev = "303e8d790acc6e996c6851f00fa98122b3f85000";  # 6.6.1 2024-11-24
    hash = "sha256-XLkZThEtt3kxVG4ri4ey9godDND2GagXm21BcUGRKiA=";
  };

  # After changing the ulab version, look in its docs/ulab-change-log.md
  # file to get the new version of this.
  ulab_git_tag = "6.6.1" + "-" + builtins.substring 0 7 ulab_src.rev;

  board = { board_name, file_name, MICROPY_BOARD, example_code, start_url, image_size_mb }:
    let
      base = pkgs.stdenv.mkDerivation rec {
        name = "micropython-base" + name_suffix;
        name_suffix = "-${file_name}-${version}-${short_date}";

        inherit MICROPY_BOARD date;
        inherit (micropython) src patches version version_suffix;

        MICROPY_GIT_HASH = builtins.substring 0 9 src.rev;
        MICROPY_GIT_TAG = version + version_suffix + "-g" + MICROPY_GIT_HASH;

        inherit lib_axtls lib_berkeley_db lib_mbedtls lib_micropython_lib lib_pico_sdk pico_sdk_patches lib_tinyusb ulab_src ulab_git_tag;

        MICROPY_BANNER_NAME_AND_VERSION =
          "MicroPython ${MICROPY_GIT_TAG} build ${build_git_tag}; with ulab ${ulab_git_tag}";

        buildInputs = with pkgs;
          [ cmake gcc gcc-arm-embedded python3 picotool ];

        cmake_flags = "-DMICROPY_BOARD=${MICROPY_BOARD} " +
          #"-DCMAKE_BUILD_TYPE=Debug " +
          "-DPICO_BUILD_DOCS=0 " +
          "-DUSER_C_MODULES=${ulab_src}/code/micropython.cmake";

        builder = ./base_builder.sh;
      };

      image = pkgs.stdenv.mkDerivation {
        name = "micropython" + base.name_suffix;
        inherit board_name start_url date base example_code image_size_mb;
        bin2uf2 = ./bin2uf2.rb;
        buildInputs = [ pkgs.dosfstools pkgs.libfaketime pkgs.mtools pkgs.ruby ];
        builder = ./image_builder.sh;
      };
    in image // { inherit base; };

in rec {
  pico = board {
    board_name = "Raspberry Pi Pico";
    file_name = "pico";
    MICROPY_BOARD = "RPI_PICO";
    image_size_mb = "2";
    start_url = "https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html";
    example_code = pkgs.fetchFromGitHub {
      owner = "pdg137";
      repo = "pico-blink-demo";
      rev = "92e56eb0498e78391e808220da9c21424685ba24";  # 2025-01-19
      hash = "sha256-pS9YovP8Ar+GdclhSqLHXY71eEODQYdE0Mg111LrQ/o=";
    };
  };

  pololu-3pi-2040-robot = board {
    board_name = "Pololu 3pi+ 2040 Robot";
    file_name = "pololu-3pi-2040-robot";
    MICROPY_BOARD = "POLOLU_3PI_2040_ROBOT";
    image_size_mb = "16";
    start_url = "https://www.pololu.com/3pi/start";
    example_code = pkgs.fetchFromGitHub {
      owner = "pololu";
      repo = "pololu-3pi-2040-robot";
      rev = "6ddb719da080c21d9d1fb03e9f92007a12848f24";  # 2024-01-16
      hash = "sha256-KcT2ChRHVFUHAa1h+B75kmP1wDPcyP1cxVF3IsEllxU=";
    };
  };

  pololu-zumo-2040-robot = board {
    board_name = "Pololu Zumo 2040 Robot";
    file_name = "pololu-zumo-2040-robot";
    MICROPY_BOARD = "POLOLU_ZUMO_2040_ROBOT";
    image_size_mb = "16";
    start_url = "https://www.pololu.com/zumo/start";
    example_code = pkgs.fetchFromGitHub {
      owner = "pololu";
      repo = "zumo-2040-robot";
      rev = "7bf996d4aa4180349538ab3c64980621930f6623";  # 2024-01-16
      hash = "sha256-V+vFeZ82soP77lXwHTVZks7a2DvdbjIJckPnrViBgCE=";
    };
  };

  # Run this to avoid having most of the useful things garbage collected:
  #   nix-build -A gcroots --out-link gcroots
  gcroots = pkgs.mkShell {
    buildInputs = p3pi.buildInputs ++ p3pi.base.buildInputs;
    inherit (p3pi.base) src lib_mbedtls lib_micropython_lib lib_pico_sdk lib_tinyusb ulab_src;
    p3pi_example_code = p3pi.example_code;
  };

  # Aliases:
  p3pi = pololu-3pi-2040-robot;
  zumo = pololu-zumo-2040-robot;
}
