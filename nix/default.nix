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
    { pkgs }:
    attrs:
    let
      elpaAttrs = convertAttrs { inherit (pkgs) lib; } attrs;
    in
    convertToElpaArchive { inherit pkgs; } elpaAttrs (buildElispPackage pkgs elpaAttrs);

  # Build an entire package archive that can be specified in `package-archives`
  # custom variable. `buildElpaArchive` builds a directory that can be served
  # from a server like S3, and `buildElpaArchiveAsTar` builds a tar archive that
  # can be distributed from GitHub Releases (Note: it's recommended to compress
  # the tar archive before you upload it).

  buildElpaArchive =
    {
      pkgs,
      withInstaller ? false,
    }:
    packageInputs:
    let
      packageInputs' = mapAttrs (_: convertAttrs { inherit (pkgs) lib; }) packageInputs;
      packageEntries = mapAttrs (_: buildElpaPackage { inherit pkgs; }) packageInputs';
      tarCommands = pkgs.lib.mapAttrsToList (name: attrs: ''
        ( name="${attrs.ename}-${attrs.version}" \
        && tar --mode u+w -cf "$out/$name.tar" \
           --transform "s,^,$name/," \
           -C ${packageEntries.${name}} \
           .
        )
      '') packageInputs';
      installerScript = import ./makeInstaller.nix { inherit (pkgs) lib; } packageInputs';
    in
    pkgs.runCommand "elpa-archive"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        passthru.entries = attrValues packageEntries;
        archiveContents = makeElpaArchiveContents { inherit (pkgs) lib; } packageInputs';
        installerScript = pkgs.lib.optionalString withInstaller installerScript;
        passAsFile = [
          "archiveContents"
          "installerScript"
        ];
      }
      ''
        mkdir -p $out
        ${pkgs.lib.concatStrings tarCommands}
        if [[ -s "$installerScriptPath" ]]
        then
          cat "$installerScriptPath" > $out/install-all.el
        fi
        cat "$archiveContentsPath" > $out/archive-contents
      '';

  buildElpaArchiveAsTar =
    { pkgs, ... }@opts:
    name: packageInputs:
    pkgs.runCommand "elpa-archive"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        root = buildElpaArchive opts packageInputs;
      }
      ''
        mkdir -p $out
        name="${name}"
        tar --mode u+w -cf "$out/$name.tar" --transform "s,^,$name/," -C $root .
      '';
}
