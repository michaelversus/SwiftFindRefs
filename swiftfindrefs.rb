class Swiftfindrefs < Formula
  desc "SwiftFindRefs is a macOS Swift CLI that resolves a project’s DerivedData, reads Xcode’s IndexStore, and reports every file referencing a chosen symbol, with optional verbose tracing for diagnostics."
  homepage "https://github.com/michaelversus/SwiftFindRefs"
  url "https://github.com/michaelversus/SwiftFindRefs.git", tag: "0.1.3"
  version "0.1.3"

  depends_on "xcode": [:build]

  def install
    system "make", "install", "prefix=#{prefix}"
  end

  test do
    system "#{bin}/Swiftfindrefs", "list"
  end
end