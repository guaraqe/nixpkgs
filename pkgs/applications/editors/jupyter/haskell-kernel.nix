{ haskellPackages
, stdenv
, fetchFromGitHub
, packages ? (_:[])
}:

let
  ghc = haskellPackages.ghcWithPackages (p:
    packages p ++ (with p; [
    ])
  );

  kernelFile = {
    display_name = "Haskell";
    language = "haskell";
    argv = [
      "${haskellPackages.ihaskell}/bin/ihaskell"
      "kernel"
      "{connection_file}"
      "--ghclib"
      "${ghc}/lib/${ghc.name}"
      "+RTS"
      "-M3g"
      "-N2"
      "-RTS"
    ];
  };

  ihaskellKernel = stdenv.mkDerivation {
    name = "ihaskell-kernel";
    src = fetchFromGitHub {
      owner = "gibiansky";
      repo = "IHaskell";
      rev = "376d108d1f034f4e9067f8d9e9ef7ddad2cce191";
      sha256 = "0359rn46xaspzh96sspjwklazk4qljdw2xxchlw2jmfa173miq6a";
    };
    phases = "installPhase";
    installPhase = ''
      mkdir -p $out
      cp $src/html/* $out
      echo '${builtins.toJSON kernelFile}' > $out/kernel.json
    '';
  };

in
  ihaskellKernel
