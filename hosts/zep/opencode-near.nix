{ config, pkgs, ... }:

let
  user = "dev-near";
  secretName = "near-ai-api-key";
in
{
  age.secrets.${secretName} = {
    file = ../../secrets/${secretName}.age;
    owner = user;
    group = "users";
    mode = "0400";
  };

  environment.systemPackages = [ pkgs.opencode ];

  # Keep both the provider setup and its work credential scoped to dev-near.
  # OpenCode resolves {file:...} at runtime, so the plaintext key never enters
  # the Nix store or the user's environment.
  home-manager.users.${user}.xdg.configFile."opencode/opencode.json".text =
    builtins.toJSON {
      "$schema" = "https://opencode.ai/config.json";
      model = "near-ai/z-ai/glm-5.2";
      provider.near-ai = {
        npm = "@ai-sdk/openai-compatible";
        name = "NEAR AI Cloud";
        options = {
          baseURL = "https://cloud-api.near.ai/v1";
          apiKey = "{file:${config.age.secrets.${secretName}.path}}";
        };
        models."z-ai/glm-5.2" = {
          name = "GLM 5.2";
        };
      };
    };
}
