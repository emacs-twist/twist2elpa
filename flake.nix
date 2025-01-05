{
  inputs = {
    twist.url = "github:emacs-twist/twist.nix";
  };

  outputs = inputs: {
    lib = import ./nix inputs;
  };
}
