class Gmic < Formula
  desc "Full-Featured Open-Source Framework for Image Processing"
  homepage "https://gmic.eu/"
  url "https://gmic.eu/files/source/gmic_3.3.4.tar.gz"
  sha256 "f52c5c8b44afe830e0d7e177a1477621821f8aa2e5183f8a432970a17acfa0bb"
  license "CECILL-2.1"
  head "https://github.com/GreycLab/gmic.git", branch: "master"

  livecheck do
    url "https://gmic.eu/download.html"
    regex(/Latest\s+stable:.*?href=.*?gmic[._-]v?(\d+(?:\.\d+)+)\.t/im)
  end

  bottle do
    rebuild 1
    sha256 cellar: :any,                 arm64_sonoma:   "423f97ef38164621dc904d4783dc327f65d5d3428ba4c911a928de54c77c7a42"
    sha256 cellar: :any,                 arm64_ventura:  "bd1fd2a455bb56b62e2bab5ac8380826e6f0b6dd2dc710bb546aac6bc5d6c0e4"
    sha256 cellar: :any,                 arm64_monterey: "77035a3113827bcb85d23fc417ce0da4180475545fa7baab9aa5c4fab5b3c2fc"
    sha256 cellar: :any,                 sonoma:         "684226bd9b88de8dfb371bb1692f8091833ada283adae2357b722520a309bb15"
    sha256 cellar: :any,                 ventura:        "f5352ddb96b2c1a6997c70f8637cd3180153db1e676768e78572d4fd4c2b59ed"
    sha256 cellar: :any,                 monterey:       "048c584f771f173a29bdb41a0da31f1915d520769456fed9e2bb3d27ff93a649"
    sha256 cellar: :any_skip_relocation, x86_64_linux:   "1a65fcd384a17292da8fe3f60078b5ad037325a8661010a9fded0ad94d024327"
  end

  depends_on "cmake" => :build
  depends_on "pkg-config" => :build
  depends_on "fftw"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "libtiff"
  depends_on "openexr"

  uses_from_macos "curl"
  uses_from_macos "zlib"

  def install
    args = %w[
      -DENABLE_FFMPEG=OFF
      -DENABLE_GRAPHICSMAGICK=OFF
      -DENABLE_X=OFF
    ]
    if OS.linux?
      args << "-DENABLE_DYNAMIC_LINKING=ON"
      ENV.deparallelize
    end

    system "cmake", "-S", ".", "-B", "build", *args, *std_cmake_args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    %w[test.jpg test.png].each do |file|
      # system bin/"gmic", "-verbose", "3", "-debug", test_fixtures(file)
      pid = fork { exec bin/"gmic", "-verbose", "3", "-debug", test_fixtures(file) }
      begin
        sleep 30
      ensure
        Process.kill("TERM", pid)
      end
    end
    system bin/"gmic", "-input", test_fixtures("test.jpg"), "rodilius", "10,4,400,16",
           "smooth", "60,0,1,1,4", "normalize_local", "10,16", "-output", testpath/"test_rodilius.jpg"
    assert_predicate testpath/"test_rodilius.jpg", :exist?
  end
end
