{
  lib,
  runCommand,
  texinfo,
}:
{
  ename,
  version,
  meta,
  sourceInfo ? null,
  packageRequires,
  # There are some missing attributes desired for the package description, but
  # omit them for now.
  ...
}:
drv:
let
  inherit (import ./lisp.nix)
    lispList
    lispCons
    lispVector
    quoteString
    ;

  attrsToLispAlist =
    attrs:
    lispList (
      lib.mapAttrsToList (
        name: value:
        lispList [
          name
          (quoteString value)
        ]
      ) attrs
    );

  hasInfo = builtins.elem "info" drv.outputs;

  commitInfo = lib.optionalString (sourceInfo != null && sourceInfo ? rev) ''
    :commit "${sourceInfo.rev}"
  '';
in
runCommand "${ename}-${version}"
  {
    buildInputs = lib.optional hasInfo texinfo;

    pkgDescription =
      (lispList [
        "define-package"
        (quoteString ename)
        (quoteString version)
        (quoteString meta.description)
        (
          "'"
          + (attrsToLispAlist (builtins.mapAttrs (_: v: if v != null then v else "0.0.0") packageRequires))
        )
        commitInfo
      ])
      + "\n"
      + ''
        ;; Local Variables:
        ;; no-byte-compile: t
        ;; End:
      '';

    passAsFile = [ "pkgDescription" ];
  }
  ''
    mkdir $out
    cd $out
    install -m 644 $pkgDescriptionPath ${ename}-pkg.el
    ${lib.optionalString hasInfo ''
      if [[ -d ${drv.info}/share/info ]]
      then
        shopt -s nullglob
        for i in ${drv.info}/share/info/*.info ${drv.info}/share/info/*.info.gz
        do
          install -m 644 -t . $i
          install-info $(basename $i) $out/dir
        done
      fi
    ''}
    (cd ${drv.outPath}/share/emacs/site-lisp \
     && tar cf - \
        --exclude='*-autoloads.el' \
        .) | tar xf -
  ''
