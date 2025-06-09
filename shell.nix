{ pkgs ? import <nixpkgs> {} }:
let
  xls = pkgs.stdenv.mkDerivation rec {
    name = "xls";
    version = "v0.0.0-7829-gc605fae2d";
    src = builtins.fetchurl {
      url = "https://github.com/google/xls/releases/download/${version}/xls-${version}-linux-x64.tar.gz";
    };
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
        mkdir -p $out/bin

        # The XLS names are very non-descript, and use underscroes.
        # Give them some proper names.
        for f in *_main ; do
           cp $f $out/bin/$(echo xls-$f | sed 's/_main//' | sed 's/_/-/g');
        done

        # dslx binaries don't have the main-suffix anymore, but still
        # punchcard-era underscores.
        cp dslx_ls $out/bin/dslx-ls
        cp dslx_fmt $out/bin/dslx-fmt

        # xls standard library
        mkdir -p $out/lib/xls
        mv xls/dslx $out/lib/xls
    '';
    postFixup = ''
      wrapProgram $out/bin/dslx-ls \
        --add-flags "--stdlib_path=$out/lib/xls/dslx/stdlib"
    '';
  };
in pkgs.mkShell {
  packages = with pkgs;
    [
      xls
    ];
  DSLX_STDLIB_PATH="${xls}/lib/xls/dslx/stdlib";

  # Possibly ':'-separated more paths to search
  DSLX_PATH="${xls}/lib";
}
