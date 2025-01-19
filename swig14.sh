SWIG-4.2.1
Introduction to SWIG
SWIG (Simplified Wrapper and Interface Generator) is a compiler that integrates C and C++ with languages including Perl, Python, Tcl, Ruby, PHP, Java, JavaScript, C#, D, Go, Lua, Octave, R, Racket, Scilab, Scheme, and Ocaml. SWIG can also export its parse tree into Lisp s-expressions and XML.

SWIG reads annotated C/C++ header files and creates wrapper code (glue code) in order to make the corresponding C/C++ libraries available to the listed languages, or to extend C/C++ programs with a scripting language.

This package is known to build and work properly using an LFS 12.2 platform.

Package Information
Download (HTTP): https://downloads.sourceforge.net/swig/swig-4.2.1.tar.gz

Download MD5 sum: 7697b443d7845381d64c90ab54d244af

Download size: 8.0 MB

Estimated disk space required: 81 MB (1.8 GB with tests)

Estimated build time: 0.1 SBU (add 7.7 SBU for tests; both using parallelism=4)

SWIG Dependencies
Required
pcre2-10.44

Optional
Boost-1.86.0 for tests, and any of the languages mentioned in the introduction, as run-time dependencies

Installation of SWIG
Install SWIG by running the following commands:

./configure --prefix=/usr                      \
            --without-javascript               \
            --without-maximum-compile-warnings &&
make
To test the results, issue: PY3=1 make TCL_INCLUDE= -k check. The unsetting of the variable TCL_INCLUDE is necessary since it is not correctly set by configure. The tests are only executed for the languages installed on your machine, so the disk space and SBU values given for the tests may vary, and should be considered as mere orders of magnitude. According to SWIG's documentation, the failure of some tests should not be considered harmful. The go tests are buggy and may generate a lot of meaningless output.

Now, as the root user:

make install &&
cp -v -R Doc -T /usr/share/doc/swig-4.2.1
Command Explanations
--without-maximum-compile-warnings: disables compiler ansi conformance enforcement, which triggers errors in the Lua headers (starting with Lua 5.3).

--without-<language>: allows disabling the building of tests and examples for <language>, but all the languages capabilities of SWIG are always built. This switch is used for JavaScript because the SWIG implementation is incomplete and a lot of tests fail due to API changes in Node-20.

Contents
Installed Programs:
swig and ccache-swig
Installed Library:
None
Installed Directories:
/usr/share/doc/swig-4.2.1 and /usr/share/swig
Short Descriptions
swig

takes an interface file containing C/C++ declarations and SWIG special instructions, and generates the corresponding wrapper code needed to build extension modules

ccache-swig

is a compiler cache, which speeds up re-compilation of C/C++/SWIG code
