{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "athenz-authorization-proxy";
  version = "4.16.1";

  src = fetchFromGitHub {
    owner = "AthenZ";
    repo = "authorization-proxy";
    rev = "v${version}";
    hash = "sha256-mlM4FJc0geWvE+E2QE4aBXwoi3tj67IH94WTpOMPSwU=";
  };

  vendorHash = "sha256-goip9e0H4MLRMepLWMVRdBcLYtSpfrC2KsdVZTTn30k=";

  meta = {
    description = "Reverse proxy to control HTTP/gPRC access with Athenz policy.";
    homepage = "https://github.com/AthenZ/authorization-proxy";
    license = lib.licenses.asl20;
    maintainer = with lib.maintainers; [ midchildan ];
  };
}
