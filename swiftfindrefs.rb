# Version is managed by the VERSION file - do not edit manually
# Run the Release workflow to bump version automatically
class Swiftfindrefs < Formula
  APP_VERSION = File.read(File.join(__dir__, "Sources/SwiftFindRefs/VERSION")).strip.freeze

  desc "SwiftFindRefs is a macOS Swift CLI that resolves a project's DerivedData, reads Xcode's IndexStore, and reports every file referencing a chosen symbol, with optional verbose tracing for diagnostics."
  homepage "https://github.com/michaelversus/SwiftFindRefs"
  url "https://github.com/michaelversus/SwiftFindRefs.git", tag: APP_VERSION
  version APP_VERSION

  depends_on "xcode": [:build]

  def install
    system "make", "install", "prefix=#{prefix}"
  end

  test do
    system "#{bin}/Swiftfindrefs", "list"
  end
end
