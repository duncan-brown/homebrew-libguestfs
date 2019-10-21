class Libguestfs < Formula
  homepage "http://libguestfs.org/"

  stable do
    url "http://archive.libguestfs.org/1.30-stable/libguestfs-1.30.1.tar.gz"
    sha256 "45e81ee1e205c21620af94d170c60da36342185c9b00d66fdaeb3ef77c966486"

    patch do
      # Change program_name to avoid collision with gnulib
      url "https://raw.githubusercontent.com/duncan-brown/homebrew-libguestfs/master/libguestfs-gnulib.patch"
      sha256 "b88e85895494d29e3a0f56ef23a90673660b61cc6fdf64ae7e5fecf79546fdd0"
    end
  end

  depends_on "autoconf" => :build
  depends_on "automake" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  # Most dependencies are listed in http://libguestfs.org/README.txt
  depends_on "qemu"
  depends_on "xz"
  depends_on "yajl"
  depends_on "glib"
  depends_on "gettext"
  depends_on "readline"
  depends_on "cdrtools"
  depends_on "augeas"
  depends_on "pcre"
  depends_on :osxfuse

  # Bindings & tools
  depends_on "libvirt" => :optional
  option "with-python", "Build with Python bindings"
  depends_on "python@2" => :optional
  option "with-java", "Build with Java bindings"
  depends_on :java => :optional
  option "with-perl", "Build with Perl bindings"
  option "with-ruby", "Build with Ruby bindings"
  option "with-php", "Build with PHP bindings"
  # depends_on "go" => :optional
  option "with-go", "Build with Go bindings"

  # Download the precompiled appliance unless explicitly told not to.
  option "without-fixed-appliance", "Not Recommended: Skip downloading the fixed-appliance(supermin kernel)"

  # Since we can't build an appliance, the recommended way is to download a fixed one.
  resource "fixed_appliance" do
    url "http://libguestfs.org/download/binaries/appliance/appliance-1.30.1.tar.xz"
    sha256 "12d88227de9921cc40949b1ca7bbfc2f6cd6e685fa6ed2be3f21fdef97661be2"
  end

  def install
    # configure doesn't detect ncurses correctly
    ENV["LIBTINFO_CFLAGS"] = "-I/usr/local/opt/include/ncurses"
    ENV["LIBTINFO_LIBS"] = "-lncurses"

    ENV["FUSE_CFLAGS"] = "-D_FILE_OFFSET_BITS=64 -D_DARWIN_USE_64_BIT_INODE -I/usr/local/include/osxfuse/fuse"
    ENV["FUSE_LIBS"] = "-losxfuse -pthread -liconv"

    ENV["AUGEAS_CFLAGS"] = "-I/usr/local/opt/augeas/include"
    ENV["AUGEAS_LIBS"] = "-L/usr/local/opt/augeas/lib"

    args = [
      "--disable-probes",
      "--disable-appliance",
      "--disable-daemon",
      # Not supporting OCaml bindings due to ocamlfind (required) not being packaged in homebrew.
      "--disable-ocaml",
      "--disable-lua",
      "--disable-haskell",
      "--disable-erlang",
      "--disable-gtk-doc-html",
      "--disable-gobject",
    ]

    args << "--without-libvirt" if build.without? "libvirt"
    args << "--disable-php"  if build.without? "php"
    args << "--disable-perl" if build.without? "perl"

    if build.with? "go"
      args << "--enable-golang"
    else
      args << "--disable-golang"
    end

    if build.with? "python"
      ENV.prepend_path "PKG_CONFIG_PATH", `python-config --prefix`.chomp + "/lib/pkgconfig"
      args << "--with-python-installdir=#{lib}/python2.7/site-packages"
    else
      args << "--disable-python"
    end

    if build.with? "ruby"
      # Force ruby bindings to install locally
      ruby_libdir = "#{lib}/ruby/site_ruby/#{RbConfig::CONFIG["ruby_version"]}"
      ruby_archdir = "#{ruby_libdir}/#{RbConfig::CONFIG["sitearch"]}"
      inreplace "ruby/Makefile.am", /\$\(RUBY_LIBDIR\)/, ruby_libdir
      inreplace "ruby/Makefile.am", /\$\(RUBY_ARCHDIR\)/, ruby_archdir
    else
      args << "--disable-ruby"
    end

    if build.with? :java
      args << "--with-java="+`#{Language::Java.java_home_cmd}`.chomp
    end

    if build.with? "go"
      inreplace "golang/Makefile.am", %r{^(golangpkgdir = )(.*)(GOROOT.*)(/pkg/.*)$}, "\\1#{lib}/golang\\4"
      inreplace "golang/Makefile.am", %r{^(golangsrcdir = )(.*)(GOROOT.*)(/src/)(pkg/)(\$\(pkg\).*)$}, "\\1#{lib}/golang\\4\\6"
    end

    system "autoreconf -f -i"

    system "./configure", "--disable-dependency-tracking",
                          "--disable-silent-rules",
                          "--prefix=#{prefix}",
                          *args

    # ENV.deparallelize

    # Build fails with just 'make install'
    system "make"

    if build.with? "php"
      # Put php bindings inside our lib
      inreplace "php/extension/Makefile", %r{^(EXTENSION_DIR = )(.*)(/php/.*)$}, "\\1#{lib}\\3"
    end

    ENV["REALLY_INSTALL"] = "yes"
    system "make", "install"

    if build.with? "fixed-appliance"
      # The appliance doesn't change, and we don't want to copy 4GB for each new version
      # appliance_dir = "#{prefix}/var/appliance"
      # mkdir_p appliance_dir
      libguestfs_path = "/usr/local/Cellar/libguestfs/1.30.1/lib/guestfs"
      mkdir_p libguestfs_path
      resource("fixed_appliance").stage(libguestfs_path)
      # (prefix/"var/appliance").install "/usr/local/lib/guestfs"
      # mkdir_p libguestfs_path
      # mkdir_p appliance_dir
    end
  end

  def caveats
    <<-EOS.undent
      A fixed appliance is required for libguestfs to work on Mac OS X.
      Unless you choose to build --without-fixed-appliance, it's downloaded for
      you and placed in the following path:
      #{HOMEBREW_PREFIX}/var/libguestfs-appliance

      To use the appliance, add the following to your shell configuration:
      export LIBGUESTFS_PATH=#{HOMEBREW_PREFIX}/var/libguestfs-appliance
      and use libguestfs binaries in the normal way.

    EOS
  end

  test do
    ENV["LIBGUESTFS_PATH"] = "#{var}appliance"
    system "#{bin}/libguestfs-test-tool", "-t 180"
  end
end


