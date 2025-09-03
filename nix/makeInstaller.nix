let
  inherit (builtins) concatStringsSep splitVersion;

  lispList = xs: "(" + (concatStringsSep " " xs) + ")";
in
{ lib, archivePrefix }:
packageInputs:
let
  installerExp =
    {
      ename,
      version,
      packageRequires,
      ...
    }:
    let
      emacsVersionCheckExp =
        if packageRequires ? emacs then "(version<= \"${packageRequires.emacs}\" emacs-version)" else "t";
    in
    ''
      (when (and ${emacsVersionCheckExp}
                 (not (package-installed-p '${ename} '${lispList (splitVersion version)})))
        (package-install '${ename}))
    '';

  installerExps = lib.mapAttrsToList (_: installerExp) packageInputs;
in
''
  ;; Please run this script with Emacs in batch mode, e.g.
  ;;
  ;;   emacs -q -batch -l ./install-all.el

  (setq package-archives
        (list (cons "local" (file-name-concat (file-name-directory
                                                  (or load-file-name
                                                      (buffer-file-name)))
                                              "${archivePrefix}"))))
  (setq package-install-upgrade-built-in t)
  (package-initialize)
  (package-read-all-archive-contents)

  ${lib.concatStrings installerExps}

  (message "Finished installing all packages")
''
