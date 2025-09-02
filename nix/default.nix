let
  inherit (builtins) mapAttrs attrValues;
in
{ twist, ... }:
let
  inherit (twist.lib) buildElispPackage;

  # Convert a value from packageInputs for the ELPA context.
  convertAttrs =
    { lib }:
    attrs:
    attrs
    // {
      elispInputs = [ ];
      dontByteCompile = true;
      wantExtraOutputs = true;
      nativeCompileAhead = false;
      version = import ./makeSnapshotVersion.nix { inherit lib; } {
        sourceInfo = attrs.sourceInfo or null;
      } (attrs.version or null);
    };

  convertToElpaArchive = { pkgs }: pkgs.callPackage ./convertToElpaArchive.nix { };

  makeElpaArchiveContents = import ./makeElpaArchiveContents.nix;
in
rec {
  # Build a single package that can be installed using `package-install-file`.
  buildElpaPackage =
    { pkgs }: attrs: convertToElpaArchive { inherit pkgs; } attrs (buildElispPackage pkgs attrs);

  # Build an entire package archive that can be specified in `package-archives`
  # custom variable. `buildElpaArchive` builds a directory that can be served
  # from a server like S3, and `buildElpaArchiveAsTar` builds a tar archive that
  # can be distributed from GitHub Releases (Note: it's recommended to compress
  # the tar archive before you upload it).

  buildElpaArchive =
    {
      asInitDirectory ? false,
      archivePrefix ? "elpa-archive/",
      ...
    }:
    {
      packageInputs,
      pkgs,
      initFiles,
      ...
    }:
    let
      archivePrefix' = if asInitDirectory then archivePrefix else "";
      packageInputs' = mapAttrs (_: convertAttrs { inherit (pkgs) lib; }) packageInputs;
      packageEntries = mapAttrs (_: buildElpaPackage { inherit pkgs; }) packageInputs';
      tarCommands = pkgs.lib.mapAttrsToList (name: attrs: ''
        ( name="${attrs.ename}-${attrs.version}" \
        && tar --mode u+w -cf "$out/${archivePrefix'}$name.tar" \
           --transform "s,^,$name/," \
           -C ${packageEntries.${name}} \
           .
        )
      '') packageInputs';
      installerScript = import ./makeInstaller.nix {
        inherit (pkgs) lib;
        archivePrefix = archivePrefix';
      } packageInputs';
    in
    pkgs.runCommand "elpa-archive"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        passthru.entries = attrValues packageEntries;
        archiveContents = makeElpaArchiveContents { inherit (pkgs) lib; } packageInputs';
        installerScript = pkgs.lib.optionalString asInitDirectory installerScript;
        initFile = ''
          (load-file (file-name-concat (file-name-directory (or load-file-name
                                                                (buffer-file-name)))
                                       "install-all.el"))
        '';
        passAsFile = [
          "archiveContents"
          "installerScript"
          "initFile"
        ];
      }
      (
        ''
          mkdir -p $out/${archivePrefix'}
          ${pkgs.lib.concatStrings tarCommands}

          cat "$archiveContentsPath" > $out/${archivePrefix'}archive-contents
        ''
        + pkgs.lib.optionalString asInitDirectory ''

          cat "$installerScriptPath" > $out/install-all.el
          cat "$initFilePath" > $out/init.el

          for file in ${builtins.concatStringsSep " " initFiles}
          do
            cat "$file" >> $out/init.el
            echo >> $out/init.el
          done
        ''
      );

  buildElpaArchiveAsTar =
    { name, ... }@opts:
    emacs-env@{ pkgs, ... }:
    pkgs.runCommand "elpa-archive"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        root = buildElpaArchive opts emacs-env;
      }
      ''
        mkdir -p $out
        name="${name}"
        tar --mode u+w -cf "$out/$name.tar" --transform "s,^,$name/," -C $root .
      '';
}
