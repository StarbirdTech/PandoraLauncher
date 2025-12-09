# Homebrew Cask for Pandora Launcher
#
# This is an EXAMPLE cask formula. To actually distribute via Homebrew, you would:
# 1. Build a universal binary (arm64 + x86_64) or separate binaries
# 2. Create a .dmg or .zip of the .app bundle
# 3. Host it somewhere (GitHub Releases, your own server)
# 4. Submit to homebrew-cask or create your own tap
#
# For personal use, see install-from-source.rb below instead.

cask "pandora-launcher" do
  version "0.1.0"
  sha256 "REPLACE_WITH_ACTUAL_SHA256"

  url "https://github.com/StarbirdTech/PandoraLauncher/releases/download/v#{version}/PandoraLauncher-#{version}-macos.dmg"
  name "Pandora Launcher"
  desc "Minecraft launcher with mod deduplication and secure credential management"
  homepage "https://github.com/Moulberry/PandoraLauncher"

  depends_on macos: ">= :big_sur"

  app "Pandora Launcher.app"

  zap trash: [
    "~/Library/Application Support/PandoraLauncher",
    "~/Library/Caches/PandoraLauncher",
    "~/Library/Preferences/com.moulberry.pandora-launcher.plist",
  ]
end
