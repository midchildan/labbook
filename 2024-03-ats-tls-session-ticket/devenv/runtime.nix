{ lib, config, ... }:

let
  hashAlgo = "sha256";

  hashedRoot = builtins.hashString hashAlgo config.env.DEVENV_ROOT;
  shortHash = builtins.substring 0 7 hashedRoot; # same as git's short hashes
  runtimeDir = "/tmp/devenv-${shortHash}";

  runtimeLink = lib.escapeShellArg "${config.env.DEVENV_DOTFILE}/run";
in
{
  # The path has to be
  # - unique to each DEVENV_ROOT to let multiple devenv environments coexist
  # - deterministic so that it won't change constantly
  # - short so that unix domain sockets won't hit the path length limit
  # - free to create as an unprivileged user on multiple OSes
  env.DEVENV_RUNTIME = runtimeDir;

  enterShell = ''
    mkdir -p ${runtimeDir}
    [[ -L ${runtimeLink} ]] && rm ${runtimeLink}
    ln -sf ${runtimeDir} ${runtimeLink}
  '';
}
