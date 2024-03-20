{ system }:

let
  pkgsFor = { commit, sha256 }:
    let
      nixpkgs = builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/${commit}.tar.gz";
        inherit sha256;
      };
    in
    import nixpkgs { inherit system; };
in
{
  pkgsGlibc_2_17 = pkgsFor {
    commit = "fd7bc4ebfd0bd86a86606cbc4ee22fbab44c5515";
    sha256 = "sha256-YIoEry26M+mNwFME43F/JTO6zvncS1PsUeJR2aHNEA8=";
  };

  pkgsGlibc_2_24 = pkgsFor {
    commit = "0ff2179e0ffc5aded75168cb5a13ca1821bdcd24";
    sha256 = "sha256-Qo8wglIH6OTPVX6ipkSoQzaeEBBXZWDcti3pgTw3GDc=";
  };

  pkgsGlibc_2_25 = pkgsFor {
    commit = "09d02f72f6dc9201fbfce631cb1155d295350176";
    sha256 = "sha256-D1knWEPWVAWvIE8MG6Y3BkMbiN9McHcljCczyRilB8Q=";
  };
}
