{ config, pkgs, inputs, ... }:
{
  imports = [
    # This imports your automated hardware scan (DO NOT REMOVE)
    ./hardware-configuration.nix
  ];
  # Bootloader settings
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Networking
  networking.hostName = "nixos";
  networking.networkmanager.enable = true;
  # Time zone and locale
  time.timeZone = "America/New_York"; # Change this to your timezone if needed
  i18n.defaultLocale = "en_US.UTF-8";
  # Define your user account
  users.users.bv = {
    isNormalUser = true;
    description = "bv";
    extraGroups = [ "networkmanager" "wheel" ]; # wheel grants sudo
    packages = with pkgs; [
      # Put any temporary packages you need here
    ];
  };
  # Allow unfree packages (like proprietary drivers/software)
  nixpkgs.config.allowUnfree = true;
  # List packages installed in system profile
  environment.systemPackages = with pkgs; [
    nano
    git
    curl
    firefox
    alsa-utils# amixer, alsactl, aplay -- needed for the CS4208 amp unmute step
    jellyfin-desktop
    jellyfin-media-player
    mpv

  ];
  # Enable the X11 windowing system (needed as a base layer for display managers)
  services.xserver.enable = true;
  # Setting up flake
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  # Enable the SDDM Display Manager (the login screen)
  services.displayManager.sddm.enable = true;
  services.displayManager.sddm.wayland.enable = true;
  # Enable the KDE Plasma Desktop Environment
  services.desktopManager.plasma6.enable = true;

  ############################
  # Audio: CS4208 codec fix + PipeWire + WirePlumber
  ############################

  # Patched snd-hda-codec-cs420x that actually enables the speaker amp on
  # the 12" MacBook (MacBook9,1/10,1). Same module name as the in-tree one,
  # so NixOS uses this build instead once it's in extraModulePackages.
  # See ./pkgs/macbook-cs4208-audio-driver.nix for details + the hash you
  # need to fill in on first build.
  boot.extraModulePackages = [
    (config.boot.kernelPackages.callPackage ./pkgs/macbook-cs4208-audio-driver.nix { })
  ];

  # Disable the old sound.enable / pulseaudio path so PipeWire owns audio
  services.pulseaudio.enable = false;

  # rtkit lets PipeWire ask for realtime scheduling priority
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # jack.enable = true; # uncomment if you need JACK app support
    wireplumber.enable = true;
  };

  # CS4208 on the 12" MacBook (MacBook9,1) has no usable hardware volume
  # control on the internal speaker path -- the codec's only analog amp
  # is wired to headphones. WirePlumber has to apply volume in software
  # for this card, or the volume slider silently does nothing on speakers.
  #
  # This matches the audio controller at PCI 00:1f.3, which is where it
  # lives on these MacBooks. If your card name differs, check with
  # `wpctl status` or `pactl list cards short` and adjust device.name below.
  environment.etc."wireplumber/wireplumber.conf.d/51-macbook-cs4208-softvol.conf".text = ''
    monitor.alsa.rules = [
      {
        matches = [ { device.name = "alsa_card.pci-0000_00_1f.3" } ]
        actions = { update-props = { api.alsa.soft-mixer = true } }
      }
    ]
  '';

  # This value determines the NixOS release from which your settings
  # for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this at the release version you originally installed.
  system.stateVersion = "26.05";

  services.tailscale.enable = true;

# Optional but recommended: open the firewall for tailscale's own port and interface
networking.firewall.trustedInterfaces = [ "tailscale0" ];
networking.firewall.checkReversePath = "loose"; # needed if you plan to use subnet routes/exit nodes

}
