# Packages given by 'callPackage'.
{
  callPackage,
  lib,
  mkShell,
  nodejs,
  python3Packages
}:

# Package options.
{
  directory ? "${python3Packages.jupyterlab}/share/jupyter/lab" ,
  kernels ? [],
  extraJupyterPath ? "",
  extraInputs ? []
}:

# Extra dependencies.
with (callPackage ./python-overrides.nix {});

let
  # Kernel generators.
  kernelsString = lib.concatMapStringsSep ":" (k: "${k.spec}");

  # PYTHONPATH setup for JupyterLab.
  pythonPath = python3Packages.makePythonPath [
    jupyter_contrib_core
    jupyter_nbextensions_configurator
    python3Packages.ipykernel
    python3Packages.tornado
  ];

  # JupyterLab executable wrapped with suitable environment variables.
  jupyterlab = python3Packages.toPythonModule (
    python3Packages.jupyterlab.overridePythonAttrs (oldAttrs: {
      makeWrapperArgs = [
        "--set JUPYTERLAB_DIR ${directory}"
        "--set JUPYTER_PATH ${extraJupyterPath}:${kernelsString kernels}"
        "--set PYTHONPATH ${extraJupyterPath}:${pythonPath}"
      ];
    })
  );

  # Shell with the appropriate JupyterLab.
  env = mkShell {
    name = "jupyterlab-shell";
    inputsFrom = extraInputs;
    buildInputs =
      [ jupyterlab nodejs ] ++ (map (k: k.runtimePackages) kernels);
    shellHook = ''
      export JUPYTER_PATH=${kernelsString kernels}
      export JUPYTERLAB=${jupyterlab}
    '';
  };
in
  jupyterlab.override (oldAttrs: {
    passthru = oldAttrs.passthru or {} // { inherit env; };
  })
