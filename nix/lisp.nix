let
  inherit (builtins) concatStringsSep replaceStrings;

  escapeDoubleQuotes = replaceStrings [ "\"" ] [ "\\\"" ];
in
{
  lispList = xs: "(" + (concatStringsSep " " xs) + ")";

  lispCons = car: cdr: "(${car} . ${cdr})";

  lispVector = xs: "[" + (concatStringsSep " " xs) + "]";

  quoteString = str: "\"" + (escapeDoubleQuotes str) + "\"";
}
