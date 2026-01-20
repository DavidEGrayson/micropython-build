let

  # This date is used to identify releases.  It gets baked into the filenames,
  # file system timestamps, and `sys.version` in Python.
  date = "2026-02-10";

  short_date = (builtins.substring 2 2 date) +
    (builtins.substring 5 2 date) + (builtins.substring 8 2 date);

  build_git_tag = if builtins.getEnv "COMMIT" == "" then
    builtins.throw "Be sure to use build.sh.  See README." else
    short_date + "-" + builtins.getEnv "COMMIT";

  # nixos-25.11 from 2026-01-08:
  nixpkgs-version = "d351d0653aeb7877273920cd3e823994e7579b0b";
  nixpkgs = fetchTarball {
    name = "nixpkgs-${nixpkgs-version}";
    url = "https://github.com/NixOS/nixpkgs/archive/${nixpkgs-version}.tar.gz";
    sha256 = "049hhh8vny7nyd26dfv7i962jpg18xb5bg6cv126b8akw5grb0dg";
  };
  pkgs = import nixpkgs {};

  micropython = rec {
    src = pkgs.stdenv.mkDerivation rec {
      name = "micropython-${rev}";
      rev = "v1.27.0";
      outputHash = "sha256-IExtpwuiro4e/MCitJTYF4AzVYGTwtao23M9JiLLQic=";
      outputHashAlgo = "sha256";
      outputHashMode = "recursive";
      builder = ./fetch_micropython.sh;
      buildInputs = [ pkgs.git pkgs.cacert ];
      submodules = ["lib/mbedtls" "lib/micropython-lib" "lib/pico-sdk" "lib/tinyusb"];
    };

    patches = [
      # Expose traceback info for exceptions, making better error messages possible.
      # https://github.com/micropython/micropython/pull/11244
      ./mpy-traceback.patch

      # ports/rp2/clocks_extra: Set VREG like the SDK: needed for 200 MHz.
      # https://github.com/micropython/micropython/pull/18739
      ./mpy-vreg.patch

       # Change the Pico firmware to use a 1MB USB Mass Storage filesystem.
      ./mpy-pico-1mb-mass-storage.patch

      # Add main_menu.py support.
      ./mpy-main-menu-py.patch

      # Zumo is now supported in pico-sdk, so remove the temporary support.
      ./mpy-supported-zumo.patch
    ];
  };
  # if rev is a commit instead of a tag, run "git describe --tags --match=v\*" to get this
  mpy_git_tag = micropython.src.rev;

  pico_sdk_patches = [
    # Increase default clock speed to the new spec
    ./pico-sdk-200mhz.patch
  ];

  ulab_src = pkgs.fetchFromGitHub rec {
    owner = "v923z";
    repo = "micropython-ulab";
    rev = "6.11.0";
    name = "${repo}-${rev}";
    hash = "sha256-KA26/ZAfjP1LvJ6OAdngc4NGD9aUHTgHU0y/Y7VX+Qs=";
  };
  ulab_git_tag = ulab_src.rev;

  board = { board_name, file_name, MICROPY_BOARD, example_code, start_url, image_size_mb }:
    let
      name_suffix = "-${file_name}-${mpy_git_tag}-${short_date}";
      base = pkgs.stdenv.mkDerivation rec {
        name = "micropython-base" + name_suffix;

        inherit MICROPY_BOARD date mpy_git_tag ulab_src ulab_git_tag build_git_tag pico_sdk_patches;
        inherit (micropython) src patches;

        buildInputs = with pkgs;
          [ cmake gcc gcc-arm-embedded python3 picotool ];

        cmake_flags = "-DMICROPY_BOARD=${MICROPY_BOARD} " +
          #"-DCMAKE_BUILD_TYPE=Debug " +
          "-DPICO_BUILD_DOCS=0 " +
          "-DUSER_C_MODULES=${ulab_src}/code/micropython.cmake";

        builder = ./base_builder.sh;
      };
      image = pkgs.stdenv.mkDerivation {
        name = "micropython" + name_suffix;
        inherit board_name start_url date base example_code image_size_mb;
        bin2uf2 = ./bin2uf2.rb;
        buildInputs = [ pkgs.dosfstools pkgs.libfaketime pkgs.mtools pkgs.ruby ];
        builder = ./image_builder.sh;
      };
    in image // { inherit base; };

in rec {
  inherit micropython;

  pico = board {
    board_name = "Raspberry Pi Pico";
    file_name = "pico";
    MICROPY_BOARD = "RPI_PICO";
    image_size_mb = 2;
    start_url = "https://www.raspberrypi.com/documentation/microcontrollers/pico-series.html";
    example_code = pkgs.fetchFromGitHub rec {
      owner = "pololu";
      repo = "pico-blink-demo";
      rev = "6d94a102c7290eceb53bb8dc0083a4e2c0e29a61"; # 2025-01-20
      name = "${repo}-${rev}";
      hash = "sha256-pS9YovP8Ar+GdclhSqLHXY71eEODQYdE0Mg111LrQ/o=";
    };
  };

  pololu-3pi-2040-robot = board {
    board_name = "Pololu 3pi+ 2040 Robot";
    file_name = "pololu-3pi-2040-robot";
    MICROPY_BOARD = "POLOLU_3PI_2040_ROBOT";
    image_size_mb = 16;
    start_url = "https://www.pololu.com/3pi/start";
    example_code = pkgs.fetchFromGitHub rec {
      owner = "pololu";
      repo = "pololu-3pi-2040-robot";
      rev = "3eaee7e247a2acf4d2875c766ccaec36881e3ac0";  # 2026-02-09
      name = "${repo}-${rev}";
      hash = "sha256-Q63pdnYCjtHLaY0Z33+w0K+INq7i9IVQFTVny0TewSs=";
    };
  };

  pololu-zumo-2040-robot = board {
    board_name = "Pololu Zumo 2040 Robot";
    file_name = "pololu-zumo-2040-robot";
    MICROPY_BOARD = "POLOLU_ZUMO_2040_ROBOT";
    image_size_mb = 16;
    start_url = "https://www.pololu.com/zumo/start";
    example_code = pkgs.fetchFromGitHub rec {
      owner = "pololu";
      repo = "zumo-2040-robot";
      rev = "a530761b51241c4bd23a95b4065b5d113c7f6a23";  # 2026-02-10
      name = "${repo}-${rev}";
      hash = "sha256-Dfe9zugGT43uN+gx3hXQaa2l/TR+S/YAaiDrdFpQOWA=";
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
