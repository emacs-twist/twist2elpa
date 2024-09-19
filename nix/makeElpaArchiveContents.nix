let
  inherit (builtins) concatStringsSep;
in
{ lib }:
packageInputs:
let
  lispList = xs: "(" + (concatStringsSep " " xs) + ")";

  lispCons = car: cdr: "(${car} . ${cdr})";

  lispVector = xs: "[" + (concatStringsSep " " xs) + "]";

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
      quotedDesc = "\"${meta.description}\"";
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
