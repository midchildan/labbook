{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "ardielle-tools";
  version = "1.5.4";

  src = fetchFromGitHub {
    owner = "ardielle";
    repo = "ardielle-tools";
    rev = "v${version}";
    hash = "sha256-uesE2LZzbP24sIlyL5qz8lbdSJu0veiOYx9PHBlcKUU=";
  };

  vendorHash = "sha256-TDxMAx8yzb9OH2nkzWihr8bmXRsosE0F7JFnJn7Q++E=";

  meta = {
    description = "RDL tools.";
    homepage = "https://github.com/ardielle/ardielle-tools";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ midchildan ];
  };
}
