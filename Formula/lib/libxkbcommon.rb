class Libxkbcommon < Formula
  desc "Keyboard handling library"
  homepage "https://xkbcommon.org/"
  url "https://xkbcommon.org/download/libxkbcommon-1.6.0.tar.xz"
  sha256 "0edc14eccdd391514458bc5f5a4b99863ed2d651e4dd761a90abf4f46ef99c2b"
  license "MIT"
  head "https://github.com/xkbcommon/libxkbcommon.git", branch: "master"

  livecheck do
    url :homepage
    regex(/href=.*?libxkbcommon[._-]v?(\d+(?:\.\d+)+)\.t/i)
  end

  bottle do
    sha256 arm64_sonoma:   "0240d70dc4af95827e15bf465f872fa3aac154dead173d14fd2cf5a3baeddf0d"
    sha256 arm64_ventura:  "8c6dc851dd48dd2df4a196a3dbc202451413ba45f5da1fa0e05bf5268e345209"
    sha256 arm64_monterey: "ae52bafef77ecad4edaaf4759fb8218af53468e9dc83ee65b43757d6aca14cef"
    sha256 arm64_big_sur:  "c1f908bc8515a3d84766bba989987ab29137e9d4b1d8d5854d6838dc9d41ec23"
    sha256 sonoma:         "fc7be887a5db40ed7c928b4b8e117dc619ee690f4d061e81193d201491fbc27f"
    sha256 ventura:        "043e964946f9f65d27e06628c9a7c61358211b98873c17930eaa36fb92e0fa70"
    sha256 monterey:       "2751b4fb16b67d57e71f8ec4b966306be8a856a3f786466057cb37cfdf03804c"
    sha256 big_sur:        "98e602696ef7cf0b7c42615f8424341ced5d265478a1c3ee7dbda237e83dcb1c"
    sha256 x86_64_linux:   "d7acfa362e20a3bc5123b5b8631c92ef84b84663d5fdf8f2edd04d330f5f384e"
  end

  depends_on "bison" => :build
  depends_on "meson" => :build
  depends_on "ninja" => :build
  depends_on "pkg-config" => :build
  depends_on "libx11"
  depends_on "libxcb"
  depends_on "xkeyboardconfig"

  uses_from_macos "libxml2"

  # upstream patch PR, https://github.com/xkbcommon/libxkbcommon/pull/468
  patch :DATA

  def install
    args = %W[
      -Denable-wayland=false
      -Denable-x11=true
      -Denable-docs=false
      -Dxkb-config-root=#{HOMEBREW_PREFIX}/share/X11/xkb
      -Dx-locale-root=#{HOMEBREW_PREFIX}/share/X11/locale
    ]
    system "meson", *std_meson_args, "build", *args
    system "meson", "compile", "-C", "build", "-v"
    system "meson", "install", "-C", "build"
  end

  test do
    (testpath/"test.c").write <<~EOS
      #include <stdlib.h>
      #include <xkbcommon/xkbcommon.h>
      int main() {
        return (xkb_context_new(XKB_CONTEXT_NO_FLAGS) == NULL)
          ? EXIT_FAILURE
          : EXIT_SUCCESS;
      }
    EOS
    system ENV.cc, "test.c", "-I#{include}", "-L#{lib}", "-lxkbcommon",
                   "-o", "test"
    system "./test"
  end
end

__END__
diff --git a/src/utils.h b/src/utils.h
index aa7969c..5d79288 100644
--- a/src/utils.h
+++ b/src/utils.h
@@ -64,6 +64,8 @@

 #define STRINGIFY(x) #x
 #define STRINGIFY2(x) STRINGIFY(x)
+#define CONCAT(x,y) x ## y
+#define CONCAT2(x,y) CONCAT(x,y)

 /* Check if a character is valid in a string literal */
 static inline bool
diff --git a/test/xvfb-wrapper.c b/test/xvfb-wrapper.c
index 38d159b..42f3822 100644
--- a/test/xvfb-wrapper.c
+++ b/test/xvfb-wrapper.c
@@ -133,25 +133,25 @@ err_display_fd:
     return ret;
 }

-/* All X11_TEST functions are in the test_functions_section ELF section.
+/* All X11_TEST functions are in the test_func_sec ELF section.
  * __start and __stop point to the start and end of that section. See the
  * __attribute__(section) documentation.
  */
-extern const struct test_function __start_test_functions_section, __stop_test_functions_section;
+DECLARE_CUSTOM_ELF_SECTION_POINTERS(CUSTOM_ELF_SECTION);

 int
 x11_tests_run()
 {
     size_t count = 1; /* For NULL-terminated entry */

-    for (const struct test_function *t = &__start_test_functions_section;
-         t < &__stop_test_functions_section;
+    for (const struct test_function *t = &__start_test_func_sec;
+         t < &__stop_test_func_sec;
          t++)
         count++;

     int rc;
-    for (const struct test_function *t = &__start_test_functions_section;
-         t < &__stop_test_functions_section;
+    for (const struct test_function *t = &__start_test_func_sec;
+         t < &__stop_test_func_sec;
          t++) {
         fprintf(stderr, "Running test: %s from %s\n", t->name, t->file);
         rc = xvfb_wrapper(t->func);
diff --git a/test/xvfb-wrapper.h b/test/xvfb-wrapper.h
index 222fa3e..e818c6b 100644
--- a/test/xvfb-wrapper.h
+++ b/test/xvfb-wrapper.h
@@ -15,6 +15,10 @@

 #pragma once

+int xvfb_wrapper(int (*f)(char* display));
+
+int x11_tests_run(void);
+
 typedef int (* x11_test_func_t)(char* display);

 struct test_function {
@@ -28,17 +32,37 @@ struct test_function {
  * loop over in x11_tests_run() to extract the tests. This removes the
  * need of manually adding the tests to a suite or listing them somewhere.
  */
+#define CUSTOM_ELF_SECTION test_func_sec
+
+#if defined(__APPLE__) && defined(__MACH__)
+#define SET_CUSTOM_ELF_SECTION(_section) \
+    __attribute__((retain,used)) \
+    __attribute__((section("__DATA," STRINGIFY(_section))))
+
+/* Custom section pointers. See: https://stackoverflow.com/a/22366882 */
+#define DECLARE_CUSTOM_ELF_SECTION_POINTERS(_section) \
+extern const struct test_function CONCAT2(__start_, _section) \
+    __asm("section$start$__DATA$" STRINGIFY2(_section)); \
+extern const struct test_function CONCAT2(__stop_, _section) \
+    __asm("section$end$__DATA$" STRINGIFY2(_section))
+
+#else
+
+#define SET_CUSTOM_ELF_SECTION(_section) \
+    __attribute__((retain,used)) \
+    __attribute__((section(STRINGIFY(_section))))
+
+#define DECLARE_CUSTOM_ELF_SECTION_POINTERS(_section) \
+    extern const struct test_function \
+    CONCAT2(__start_, _section), CONCAT2(__stop_, _section)
+#endif
+
 #define X11_TEST(_func) \
 static int _func(char* display); \
 static const struct test_function _test_##_func \
-__attribute__((used)) \
-__attribute__((section("test_functions_section"))) = { \
+SET_CUSTOM_ELF_SECTION(CUSTOM_ELF_SECTION) = { \
     .name = #_func, \
     .func = _func, \
     .file = __FILE__, \
 }; \
 static int _func(char* display)
-
-int xvfb_wrapper(int (*f)(char* display));
-
-int x11_tests_run(void);
