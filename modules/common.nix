{
  self,
  inputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    ./primaryUser.nix
    ./nixpkgs.nix
  ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    enableBashCompletion = true;
  };

  nix = {
    optimise.automatic = true;
    settings = {
      max-jobs = 8;
      trusted-users = ["${config.user.name}" "@admin" "@root" "@sudo" "@wheel"];
      keep-outputs = true;
      keep-derivations = true;
      experimental-features = ["nix-command" "flakes"];
    };
  };

  user = {
    description = "smashell";
    home = "${
      if pkgs.stdenvNoCC.isDarwin
      then "/Users"
      else "/home"
    }/${config.user.name}";
    shell = pkgs.zsh;
  };

  # bootstrap home manager using system config
  hm = {
    imports = [
      ./home-manager
      ./home-manager/1password.nix
      inputs.nix-index-database.hmModules.nix-index
    ];
  };

  # let nix manage home-manager profiles and use global nixpkgs
  home-manager = {
    extraSpecialArgs = {inherit self inputs;};
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "backup";
  };

  # environment setup
  environment = {
    systemPackages = with pkgs; [
      # editors
      neovim

      # standard toolset
      coreutils-full
      findutils
      diffutils
      curl
      wget
      git
      jq

      # helpful shell stuff
      bat
      fzf
      ripgrep
    ];
    etc = {
      home-manager.source = "${inputs.home-manager}";
      nixpkgs.source = "${inputs.nixpkgs}";
    };
    # list of acceptable shells in /etc/shells
    shells = with pkgs; [bash zsh fish];
  };

  fonts = {
    packages = with pkgs; [jetbrains-mono];
  };
}
