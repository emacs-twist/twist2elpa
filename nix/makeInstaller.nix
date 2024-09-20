let
  inherit (builtins) concatStringsSep splitVersion;

  lispList = xs: "(" + (concatStringsSep " " xs) + ")";
in
{ lib }:
packageInputs:
let
  installerExp =
    { ename, version, ... }:
    ''
      (unless (package-installed-p '${ename} '${lispList (splitVersion version)})
        (package-install '${ename}))
    '';

  installerExps = lib.mapAttrsToList (_: installerExp) packageInputs;
in
''
  ;; Please run this script with Emacs in batch mode, e.g.
  ;;
  ;;   emacs -q -batch -l ./install-all.el

  (setq package-archives
        (list (cons "local" (file-name-directory load-file-name))))
  (setq package-install-upgrade-built-in t)
  (package-initialize)
  (package-refresh-contents)

  ${lib.concatStrings installerExps}

  (message "Finished installing all packages")
''
