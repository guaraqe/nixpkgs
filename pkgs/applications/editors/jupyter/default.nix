# Jupyter notebook with the given kernel definitions

{ python3
, nodejs
, nodePackages
, stdenv
, kernels ? [ "${python3.pkgs.ipykernel}/share/jupyter" ]
, extensions ? [ "@jupyterlab/toc" ] # python3.pkgs.ipywidgets ]
}:

let
  # see link for expected kernel specification
  # https://jupyter-client.readthedocs.io/en/stable/kernels.html#kernel-specs
  jupyterPath = stdenv.lib.concatStringsSep ":" kernels;

  # assumes that extensions are a list of derivations or strings
  # each derivation has a passthru attribute that specifies jupyterlab npm extensions required
  # `passthru = { jupyterlabExtensions = [ "@jupyter-widgets/jupyterlab-manager" ]; }`
  # we have to have the string name of the package becuase npm does not have a flat directory structure
  # for example "@jupyter-widgets/jupyterlab-manager" has two directories vs. "jupyter-leaflet" has one
  # this is needed for the `jupyter labextension link lib/node_modules/<package name>`
  collectedExtensions =
    builtins.map (s: {name = s; package = nodePackages."${s}"; })
      (stdenv.lib.unique  # get unique npm packages string names -- there could be duplicates
        (stdenv.lib.concatMap (e: if stdenv.lib.isDerivation e then (stdenv.lib.attrByPath ["passthru" "jupyterlabExtensions"] [] e) else [ e ]) extensions));

  # assumes that each extension has a "lib/node_modules/<labextension>"
  # we are using the jupyterlab link mechanism
  # https://jupyterlab.readthedocs.io/en/stable/developer/extension_dev.html
  jupyterLabDir = stdenv.mkDerivation {
    name = "jupyterlab-directory";
    src = "/dev/null";
    unpackCmd = "mkdir home"; # never used

    nativeBuildInputs = [ nodePackages.webpack nodePackages.webpack-cli ];

    buildInputs = [ nodejs python3.pkgs.jupyterlab ];

    buildPhase = ''
      echo "======== BUILD PHASE ========="
      export HOME=$PWD/home

      mkdir -p $out
      cp -r ${python3.pkgs.jupyterlab}/share/jupyter/lab/* $out
      chmod -R 755 $out

      # link extensions
      ${stdenv.lib.concatMapStrings
        (e: "jupyter labextension link --no-build --app-dir=$out ${e.package}/lib/node_modules/${e.name}; ")
        collectedExtensions}

      # npm build
      jupyter lab build --app-dir=$out
      echo "==== BUILD DONE==== "
    '';
  };
in

with python3.pkgs; toPythonModule (
  notebook.overridePythonAttrs(oldAttrs: {
    makeWrapperArgs = ["--set JUPYTER_PATH ${jupyterPath}" "--set JUPYTERLAB_DIR ${jupyterLabDir}"];
  })
)
