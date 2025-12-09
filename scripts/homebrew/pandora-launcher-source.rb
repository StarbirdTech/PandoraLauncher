# Homebrew Formula for building Pandora Launcher from source
#
# To use this formula personally:
#   1. Create a tap: brew tap-new starbirdtech/pandora
#   2. Copy this file to: $(brew --repo starbirdtech/pandora)/Formula/pandora-launcher.rb
#   3. Install: brew install starbirdtech/pandora/pandora-launcher
#
# Or install directly from local file:
#   brew install --formula ./pandora-launcher-source.rb

class PandoraLauncher < Formula
  desc "Minecraft launcher with mod deduplication and secure credential management"
  homepage "https://github.com/Moulberry/PandoraLauncher"
  url "https://github.com/StarbirdTech/PandoraLauncher.git",
      branch: "personal/macos"
  version "0.1.0"
  license "MIT"  # Update if different

  depends_on "rust" => :build
  depends_on "imagemagick" => :build  # For icon conversion

  def install
    # Build the release binary
    system "cargo", "build", "--release"

    # Create .app bundle
    app_name = "Pandora Launcher"
    app_bundle = "#{app_name}.app"

    mkdir_p "#{app_bundle}/Contents/MacOS"
    mkdir_p "#{app_bundle}/Contents/Resources"

    # Copy binary
    cp "target/release/pandora_launcher", "#{app_bundle}/Contents/MacOS/PandoraLauncher"

    # Generate icon
    iconset = buildpath/"AppIcon.iconset"
    mkdir_p iconset
    svg = "assets/icons/pandora.svg"

    [16, 32, 64, 128, 256, 512, 1024].each do |size|
      system "magick", "-background", "none", "-density", "384", svg, "-resize", "#{size}x#{size}", "#{iconset}/icon_#{size}x#{size}.png"
    end

    # Create proper iconset naming
    mv "#{iconset}/icon_32x32.png", "#{iconset}/icon_16x16@2x.png"
    mv "#{iconset}/icon_64x64.png", "#{iconset}/icon_32x32@2x.png"
    mv "#{iconset}/icon_256x256.png", "#{iconset}/icon_128x128@2x.png"
    mv "#{iconset}/icon_512x512.png", "#{iconset}/icon_256x256@2x.png"
    mv "#{iconset}/icon_1024x1024.png", "#{iconset}/icon_512x512@2x.png"

    system "magick", "-background", "none", "-density", "384", svg, "-resize", "16x16", "#{iconset}/icon_16x16.png"
    system "magick", "-background", "none", "-density", "384", svg, "-resize", "32x32", "#{iconset}/icon_32x32.png"
    system "magick", "-background", "none", "-density", "384", svg, "-resize", "128x128", "#{iconset}/icon_128x128.png"
    system "magick", "-background", "none", "-density", "384", svg, "-resize", "256x256", "#{iconset}/icon_256x256.png"
    system "magick", "-background", "none", "-density", "384", svg, "-resize", "512x512", "#{iconset}/icon_512x512.png"

    system "iconutil", "-c", "icns", iconset, "-o", "#{app_bundle}/Contents/Resources/AppIcon.icns"

    # Create Info.plist
    (buildpath/"#{app_bundle}/Contents/Info.plist").write <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
          <key>CFBundleDevelopmentRegion</key>
          <string>en</string>
          <key>CFBundleExecutable</key>
          <string>PandoraLauncher</string>
          <key>CFBundleIconFile</key>
          <string>AppIcon</string>
          <key>CFBundleIdentifier</key>
          <string>com.moulberry.pandora-launcher</string>
          <key>CFBundleInfoDictionaryVersion</key>
          <string>6.0</string>
          <key>CFBundleName</key>
          <string>#{app_name}</string>
          <key>CFBundlePackageType</key>
          <string>APPL</string>
          <key>CFBundleShortVersionString</key>
          <string>#{version}</string>
          <key>CFBundleVersion</key>
          <string>1</string>
          <key>LSMinimumSystemVersion</key>
          <string>11.0</string>
          <key>NSHighResolutionCapable</key>
          <true/>
          <key>NSSupportsAutomaticGraphicsSwitching</key>
          <true/>
      </dict>
      </plist>
    EOS

    # Install to prefix (Homebrew's Cellar)
    prefix.install app_bundle

    # Create CLI command
    bin.install_symlink "#{prefix}/#{app_bundle}/Contents/MacOS/PandoraLauncher" => "pandora-launcher"
  end

  def post_install
    # Link to /Applications
    system "ln", "-sf", "#{prefix}/Pandora Launcher.app", "/Applications/Pandora Launcher.app"
  end

  def caveats
    <<~EOS
      Pandora Launcher has been installed to /Applications.

      To add CLI aliases, add to your ~/.zshrc:
        alias pandora='open -a "Pandora Launcher"'
        alias mc='pandora'
    EOS
  end

  test do
    assert_predicate prefix/"Pandora Launcher.app/Contents/MacOS/PandoraLauncher", :executable?
  end
end
