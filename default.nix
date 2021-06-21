{ lib
, stdenv
, python27Packages
, callPackage
, fetchFromGitHub
, makeWrapper
, # re2c deps
  autoreconfHook
, # py-yajl deps
  git
, # oil deps
  readline
, cmark
, file
, glibcLocales
}:

rec {
  re2c = stdenv.mkDerivation rec {
    pname = "re2c";
    version = "1.0.3";
    sourceRoot = "${src.name}/re2c";
    src = fetchFromGitHub {
      owner = "skvadrik";
      repo = "re2c";
      rev = version;
      sha256 = "0grx7nl9fwcn880v5ssjljhcb9c5p2a6xpwil7zxpmv0rwnr3yqi";
    };
    nativeBuildInputs = [ autoreconfHook ];
    preCheck = ''
      patchShebangs run_tests.sh
    '';
  };

  py-yajl = python27Packages.buildPythonPackage rec {
    pname = "oil-pyyajl-unstable";
    version = "2019-12-05";
    src = fetchFromGitHub {
      owner = "oilshell";
      repo = "py-yajl";
      rev = "eb561e9aea6e88095d66abcc3990f2ee1f5339df";
      sha256 = "17hcgb7r7cy8r1pwbdh8di0nvykdswlqj73c85k6z8m0filj3hbh";
      fetchSubmodules = true;
    };
    # just for submodule IIRC
    nativeBuildInputs = [ git ];
  };

  oildev = python27Packages.buildPythonPackage rec {
    pname = "oildev-unstable";
    version = "2021-02-26";

    src = fetchFromGitHub {
      owner = "oilshell";
      repo = "oil";
      rev = "11c6bd3ca0e126862c7a1f938c8510779837affa";
      hash = "sha256-UTQywtx+Dn1/qx5uocqgGn7oFYW4R5DbuiRNF8t/BzY=";

      /*
        It's not critical to drop most of these; the primary target is
        the vendored fork of Python-2.7.13, which is ~ 55M and over 3200
        files, dozens of which get interpreter script patches in fixup.
      */
      extraPostFetch = ''
        rm -rf Python-2.7.13 benchmarks metrics py-yajl rfc gold web testdata services demo devtools cpp
      '';
    };

    # TODO: not sure why I'm having to set this for nix-build...
    #       can anyone tell if I'm doing something wrong?
    SOURCE_DATE_EPOCH = 315532800;

    # patch to support a python package, pass tests on macOS, etc.
    patches = (
      builtins.map
        (x: ./. + "/${x}")
        (builtins.filter (x: lib.hasSuffix ".patch" x) (builtins.attrNames (builtins.readDir ./.)))
    );

    buildInputs = [ readline cmark py-yajl ];

    nativeBuildInputs = [ re2c file makeWrapper ];

    propagatedBuildInputs = with python27Packages; [ six typing ];

    doCheck = true;

    preBuild = ''
      build/dev.sh all
    '';

    postPatch = ''
      patchShebangs asdl build core doctools frontend native oil_lang
    '';

    # TODO: this may be obsolete?
    _NIX_SHELL_LIBCMARK = "${cmark}/lib/libcmark${stdenv.hostPlatform.extensions.sharedLibrary}";

    # See earlier note on glibcLocales TODO: verify needed?
    LOCALE_ARCHIVE = lib.optionalString (stdenv.buildPlatform.libc == "glibc") "${glibcLocales}/lib/locale/locale-archive";

    # not exhaustive; just a spot-check for now
    pythonImportsCheck = [ "oil" "oil._devbuild" ];

    meta = {
      license = with lib.licenses; [
        psfl # Includes a portion of the python interpreter and standard library
        asl20 # Licence for Oil itself
      ];
    };
  };
}