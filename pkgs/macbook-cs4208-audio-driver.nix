# CS4208 (Cirrus Logic) audio codec fix for the 12" MacBook (MacBook9,1 / MacBook10,1).
#
# The mainline `snd-hda-codec-cs420x` module detects the codec but never
# enables the speaker amplifier, so the internal speakers stay silent.
# This derivation rebuilds that exact in-tree module from source, but with
# the three files swapped for the patched versions from
# https://github.com/breitburg/macbook12-audio-driver (a maintained fork of
# leifliddy/macbook12-audio-driver, itself based on davidjo/snd_hda_macbookpro).
#
# Because the resulting module has the SAME name (snd-hda-codec-cs420x) as
# the in-tree one, NixOS's module aggregation will prefer this one when it's
# listed in boot.extraModulePackages -- no blacklisting of the stock module
# needed.
#
# Usage (in configuration.nix / hardware.nix):
#   let
#     macbookAudio = config.boot.kernelPackages.callPackage ./pkgs/macbook-cs4208-audio-driver.nix { };
#   in {
#     boot.extraModulePackages = [ macbookAudio ];
#   }
#
# NOTE ON THE HASH BELOW: pinned via the standard Nix fakeHash workflow --
# build once with `hash = lib.fakeHash;`, Nix reports the real hash in a
# mismatch error, paste it in. If you ever bump `rev` to a newer commit,
# you'll need to repeat that (set it back to lib.fakeHash, rebuild, copy
# the new hash Nix reports).
{ lib
, stdenv
, fetchFromGitHub
, kernel
}:

stdenv.mkDerivation {
  pname = "macbook-cs4208-audio-driver";
  # NOTE: no manual `version` here on purpose -- it comes from
  # `inherit (kernel) ... version ...` below, so the derivation name is
  # tied to the exact kernel it was built against (e.g.
  # macbook-cs4208-audio-driver-6.18.38). Setting it here too would clash
  # with that inherit, which is exactly the error this fixes.

  # Full patched sources for the cirrus codec directory, pinned to the
  # commit verified against README instructions as of 2026-07-08.
  driverSrc = fetchFromGitHub {
    owner = "breitburg";
    repo = "macbook12-audio-driver";
    rev = "5c3582f44adcd42e94ec5dc3a283fe99cc1f44ef";
    hash = "sha256-i7tXyndXchAXQXAegbppSOthwtb73ml85pg5fseqz4w=";
  };

  # We build the module from the *actual* kernel source tree so it matches
  # your exact running kernel's headers/ABI, then splice the patched files
  # in over the stock ones -- same technique NixOS uses for replacing any
  # other in-tree module (e.g. amdgpu overrides in the NixOS wiki).
  inherit (kernel) src version postPatch nativeBuildInputs;

  kernel_dev = kernel.dev;
  kernelVersion = kernel.modDirVersion;
  modulePath = "sound/hda/codecs/cirrus";

  postUnpack = ''
    hdaDir=$sourceRoot/sound/hda/codecs/cirrus

    rm -f "$hdaDir/cs420x.c"
    cp "$driverSrc/patch_cirrus/cs420x.c" "$hdaDir/cs420x.c"
    cp "$driverSrc/patch_cirrus/patch_cirrus_a1534_setup.h" "$hdaDir/patch_cirrus_a1534_setup.h"
    cp "$driverSrc/patch_cirrus/patch_cirrus_a1534_pcm.h" "$hdaDir/patch_cirrus_a1534_pcm.h"
    cp "$driverSrc/patch_cirrus/Makefile_cs420x" "$hdaDir/Makefile"

    # Kernels >=6.17 renamed the codec .free callback to .remove
    # (matches install.cirrus.driver.sh's own kernel-version check).
    sed -i 's/\.free/.remove/' "$hdaDir/patch_cirrus_a1534_pcm.h"
  '';

  buildPhase = ''
    runHook preBuild

    BUILT_KERNEL=$kernel_dev/lib/modules/$kernelVersion/build
    cp $BUILT_KERNEL/Module.symvers .
    cp $BUILT_KERNEL/.config .
    [ -f $kernel_dev/vmlinux ] && cp $kernel_dev/vmlinux . || true

    make "-j$NIX_BUILD_CORES" modules_prepare
    make "-j$NIX_BUILD_CORES" M=$modulePath modules

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    make \
      INSTALL_MOD_PATH="$out" \
      XZ="xz -T$NIX_BUILD_CORES" \
      M=$modulePath \
      modules_install

    runHook postInstall
  '';

  meta = with lib; {
    description = "Patched CS4208 codec module (speaker/headphone support) for the 12\" MacBook9,1 / MacBook10,1";
    homepage = "https://github.com/breitburg/macbook12-audio-driver";
    license = licenses.gpl2Plus;
    platforms = platforms.linux;
  };
}
