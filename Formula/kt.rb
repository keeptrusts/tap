class Kt < Formula
  desc "Keeptrusts AI governance gateway CLI"
  homepage "https://keeptrusts.com"
  license :cannot_represent
  version "0.1.0"

  on_macos do
    url "https://dl.keeptrusts.com/releases/#{version}/kt-macos-universal.tar.gz"
    sha256 "92fe69cf4bf64932e924858311037cd10939cdaf25fdb7f7462b43d7c5d71e34"
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://dl.keeptrusts.com/releases/#{version}/kt-linux-aarch64.tar.gz"
      sha256 "156e8d0623bb70a13eddc3d5e5434889f1db426f71c55139ced43acb3e45c76e"
    else
      url "https://dl.keeptrusts.com/releases/#{version}/kt-linux-x86_64.tar.gz"
      sha256 "ceabaa5163eca3a92adea28ef455ef5116a5fdb13acc152632672628cfa3e1a8"
    end
  end

  def install
    bin.install "kt"
  end

  test do
    assert_match "kt", shell_output("#{bin}/kt --version")
  end
end
