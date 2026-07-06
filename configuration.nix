{ config, pkgs, ... }:

{
  # =========================================================================
  # 1. HARDWARE & KERNEL (Crucial for 2016 12" MacBook SPI Keyboard/Trackpad)
  # =========================================================================
  
  boot.initrd.availableKernelModules = [ 
    "xhci_pci" 
    "nvme" 
    "usbhid" 
    "usb_storage" 
    "sd_mod"
    # Essential for the internal keyboard and trackpad (SPI bus)
    "applespi" 
    "intel_lpss_pci" 
    "spi_pxa2xx_platform" 
  ];
  
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" "applespi" ];
  boot.extraModulePackages = [ ];

  # Bootloader setup
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # =========================================================================
  # 2. FIRMWARE, WI-FI, & BLUETOOTH (Broadcom Drivers)
  # =========================================================================
  
  # Required for proprietary Broadcom wireless and bluetooth firmware blobs
  hardware.enableRedistributableFirmware = true;
  nixpkgs.config.allowUnfree = true;

  # Networking via NetworkManager (plays beautifully with Wayland/Sway bar applets)
  networking.networkmanager.enable = true;
  
  # Bluetooth setup
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnOnBoot = true;
  services.blueman.enable = true; # Bluetooth manager applet

  # =========================================================================
  # 3. SOUND & AUDIO (PipeWire for Wayland)
  # =========================================================================
  
  # Disable legacy ALSA/PulseAudio services
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # =========================================================================
  # 4. GRAPHICS & WAYLAND DEPS
  # =========================================================================
  
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      vaapiIntel
    ];
  };

  # =========================================================================
  # 5. SWAY WINDOW MANAGER & ENVIRONMENT
  # =========================================================================
  
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # Ensures GTK applications scale properly
    extraPackages = with pkgs; [
      swaylock             # Screen locker
      swayidle             # Idle management (sleep/screen blanking)
      waybar               # Status bar
      mako                 # Notification daemon
      grim                 # Screenshot tool
      slurp                # Region selector for screenshots
      wl-clipboard         # Clipboard management
      alacritty            # GPU-accelerated terminal emulator
      dmenu                # Application launcher (or substitute with rofi-wayland)
    ];
  };

  # Set Environment Variables for pure Wayland execution
  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1"; # Forces Electron/Chromium apps to use Wayland natively
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  # =========================================================================
  # 6. SYSTEM TUNING (Retina Scaling & Power Management)
  # =========================================================================
  
  # Console font size adjustment for the HiDPI Retina display during boot stage
  console = {
    earlySetup = true;
    font = "ter-v32n";
    packages = [ pkgs.terminus_font ];
  };

  # Power Management (Crucial for fanless Intel Core m designs)
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
    };
  };

  # Touchpad tweaks for the MacBook trackpad
  services.libinput = {
    enable = true;
    touchpad = {
      tapping = true;
      naturalScrolling = true;
      clickMethod = "clickfinger";
    };
  };

  # Define your user account
  users.users.yourusername = { bv
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" ];
    packages = with pkgs; [
      firefox
    ];
  };

  system.stateVersion = "24.11"; # Match your target NixOS channel version
}
