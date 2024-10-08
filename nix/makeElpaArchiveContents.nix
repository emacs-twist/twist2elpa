let
  inherit (builtins) concatStringsSep replaceStrings;
in
{ lib }:
packageInputs:
let
  inherit (import ./lisp.nix)
    lispList
    lispCons
    lispVector
    quoteString
    ;

  formatVersionAsList = version: lispList (lib.splitVersion version);

  makeAttrVector =
    {
      sourceInfo ? null,
      packageRequires,
      meta,
      version,
      ...
    }@attrs:
    let
      packReqsString =
        if packageRequires == null || packageRequires == { } then
          "nil"
        else
          lib.pipe packageRequires [
            (lib.mapAttrsToList (
              name: requiredVersion:
              lispList [
                name
                (lispList (lib.splitVersion (if requiredVersion == null then "0" else requiredVersion)))
              ]
            ))
            lispList
          ];
      quotedDesc = if (meta.description or null) == null then "nil" else quoteString meta.description;
    in
    lispVector [
      (formatVersionAsList version)
      packReqsString
      quotedDesc
      "tar"
    ];

  packageEntries = lib.mapAttrsToList (
    ename: attrs: lispCons ename (makeAttrVector attrs)
  ) packageInputs;
in
''
  (1
   ${concatStringsSep "\n " packageEntries})
''
