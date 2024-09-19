let
  inherit (builtins) mapAttrs attrValues;
in
inputs@{ twist, ... }:
pkgs@{ lib, ... }:
let
  inherit (twist.lib) buildElispPackage;

  makeSnapshotVersion = import ./makeSnapshotVersion.nix { inherit lib; };

  # Convert a value from packageInputs for the ELPA context.
  convertAttrs =
    attrs:
    attrs
    // {
      elispInputs = [ ];
      dontByteCompile = true;
      wantExtraOutputs = true;
      nativeCompileAhead = false;
      version = makeSnapshotVersion {
        sourceInfo = attrs.sourceInfo or null;
      } (attrs.version or null);
    };

  convertToElpaArchive = pkgs.callPackage ./convertToElpaArchive.nix { };

  buildElpaPackage = attrs: convertToElpaArchive attrs (buildElispPackage pkgs attrs);

  makeElpaArchiveContents = import ./makeElpaArchiveContents.nix { inherit lib; };

  buildElpaArchive =
    packageInputs:
    let
      packageInputs' = mapAttrs (_: convertAttrs) packageInputs;
      packageEntries = mapAttrs (_: buildElpaPackage) packageInputs';
      tarCommands = lib.mapAttrsToList (name: attrs: ''
        ( name="${attrs.ename}-${attrs.version}" \
        && tar --mode u+w -cf "$out/$name.tar" \
           --transform "s,^,$name/," \
           -C ${packageEntries.${name}} \
           .
        )
      '') packageInputs';
    in
    pkgs.runCommand "elpa-archive"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        passthru.entries = attrValues packageEntries;
        archiveContents = makeElpaArchiveContents packageInputs';
        passAsFile = [ "archiveContents" ];
      }
      ''
        mkdir -p $out
        ${lib.concatStrings tarCommands}
        cat "$archiveContentsPath" > $out/archive-contents
      '';

  buildElpaArchiveAsTar =
    name: packageInputs:
    pkgs.runCommand "elpa-archive"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
        root = buildElpaArchive packageInputs;
      }
      ''
        mkdir -p $out
        name="${name}"
        tar --mode u+w -cf "$out/$name.tar" --transform "s,^,$name/," -C $root .
      '';
in
{
  # Build a single package that can be installed using `package-install-file`.
  buildElpaPackage = attrs: buildElpaPackage (convertAttrs attrs);

  # Build an entire package archive that can be specified in `package-archives`
  # custom variable. `buildElpaArchive` builds a directory that can be served
  # from a server like S3, and `buildElpaArchiveAsTar` builds a tar archive that
  # can be distributed from GitHub Releases (Note: it's recommended to compress
  # the tar archive before you upload it).
  inherit buildElpaArchive buildElpaArchiveAsTar;
}
