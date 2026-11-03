# Installs the DMG of release v<version>. CI keeps version equal to the app's, so a version bump bumps it too.
# The app updates itself, so brew upgrade leaves it alone, and Gatekeeper checks its notarization.
cask "tallynn" do
  version "0.6.0"
  sha256 :no_check

  url "https://github.com/zolferfigueiredo/tallynn/releases/download/v#{version}/Tallynn-#{version}.dmg"
  name "Tallynn"
  desc "Menu bar counter for GitHub release downloads"
  homepage "https://tallynn.zolfer.com/"

  auto_updates true
  depends_on macos: :tahoe

  app "Tallynn.app"

  uninstall quit: "com.zolfer.tallynn"

  zap trash: [
    "~/Library/Caches/com.zolfer.tallynn",
    "~/Library/HTTPStorages/com.zolfer.tallynn",
    "~/Library/Preferences/com.zolfer.tallynn.plist",
  ]

  caveats <<~EOS
    Tallynn signs in through the GitHub CLI (brew install gh) to count your own repositories.
    Anyone's public repositories count without signing in.
  EOS
end
