{...}: {
  xdg.configFile = {
    opAgent = {
      recursive = true;
      target = "1Password/ssh/agent.toml";
      text = ''
        [[ssh-keys]]
        vault = "Private"
      '';
    };
  };
  programs.git = {
    userEmail = "aliwong1980@gmail.com";
    userName = "smashell";
  };
}
