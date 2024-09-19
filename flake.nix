{
  inputs = {
    twist.url = "github:emacs-twist/twist.nix";
  };

  outputs =
    { ... }@inputs:
    {
      overlays.default = _: super: {
        emacsTwist2Elpa = import ./nix inputs super;
      };
    };
}
