{ pkgs ? import <nixpkgs> {} }:
let
  xls = pkgs.stdenv.mkDerivation rec {
    name = "xls";
    version = "v0.0.0-8280-g390405a30";
    src = builtins.fetchurl {
      url = "https://github.com/google/xls/releases/download/${version}/xls-${version}-linux-x64.tar.gz";
    };
    nativeBuildInputs = [ pkgs.makeWrapper ];
    installPhase = ''
        mkdir -p $out/bin

        # The XLS names are very non-descript, and use underscores.
        # Give them some proper names.
        for f in *_main ; do
           mv $f $out/bin/$(echo xls-$f | sed 's/_main//' | sed 's/_/-/g');
        done

        # dslx binaries don't have the main-suffix anymore, but still
        # punchcard-era underscores.
        mv dslx_ls $out/bin/dslx-ls
        mv dslx_fmt $out/bin/dslx-fmt

        # xls standard library
        mkdir -p $out/lib/xls
        mv xls/dslx $out/lib/xls
    '';
    postFixup = ''
      # Make language server already know the stdlib to avoid
      # messing with the editor configuration.
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
