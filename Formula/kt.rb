class Kt < Formula
  desc "Keeptrusts AI governance gateway CLI"
  homepage "https://keeptrusts.com"
  license :cannot_represent
  version "0.1.0"

  on_macos do
    url "https://dl.eu.keeptrusts.com/releases/#{version}/kt-macos-universal.tar.gz"
    sha256 "92fe69cf4bf64932e924858311037cd10939cdaf25fdb7f7462b43d7c5d71e34"
  end

  on_linux do
    if Hardware::CPU.arm?
      url "https://dl.eu.keeptrusts.com/releases/#{version}/kt-linux-aarch64.tar.gz"
      sha256 "5c0c8b7a90254edef58ff0719a673e965880917aba5439d86e4e9e70058438d5"
    else
      url "https://dl.eu.keeptrusts.com/releases/#{version}/kt-linux-x86_64.tar.gz"
      sha256 "eefffa171cc5d9db2d30d6fdc7e5213c26ba98dc4313067791ea97b93f9d782c"
    end
  end

  def install
    bin.install "kt"
  end

  test do
    assert_match "kt", shell_output("#{bin}/kt --version")
  end
end
