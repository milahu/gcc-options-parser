# gcc-options-parser

parse command line options for the GCC compiler

"what would gcc do?"

## features

what can `gcc-options-parser` do?

* parse all gcc "binary" options (binary: consume the next argument). in gcc's `*.opt` files, these options have the `Separate` keyword.
* parse input paths and input languages
  * gcc's [-x language](https://gcc.gnu.org/onlinedocs/gcc/Overall-Options.html) option allows the user to override the input file extension. this setting is applied to all following input files.
  * with `-x none`, gcc goes back to the default "parse language from file extension" mode.
* parse the output path, if one was set with `-o path` or `-opath` (the `-o` option accepts `Separate` and `Joined` values).
  * if no output path was set, then gcc will use the default output path `a.out` (at least for C/C++ inputs).
* TODO? (do we need this? alternative: patch options like `-D`) parse options which are used only for the C/C++ preprocessor ([preprocessor options](https://gcc.gnu.org/onlinedocs/gcc/Preprocessor-Options.html)). these options can be safely removed from the compiler options.

### anti features

what will `gcc-options-parser` NOT do?

* validate "unary" options (options which do not consume the next argument).

## concept

the parser is generated from gcc's opt files,
for example [gcc/common.opt](https://github.com/gcc-mirror/gcc/blob/master/gcc/common.opt)

## use case

in my use case ([incremental nix-build with ccache](https://nixos.wiki/wiki/CCache)),
i want to "normalize" source code,
to get more cache hits with `ccache`.

normalize source code? aka "reproducible builds".

* replace variable output paths with constant template strings
* remove gcc options like `-frandom-seed=somestring`

so i want ...

* insert a code transformer (source postprocessor)
  * after the C/C++ preprocessor
  * before the C/C++ compiler
* insert a binary transformer (binary postprocessor)
  * after the C/C++ compiler

so, i want to split the compilation into

* multiple preprocessor steps = `gcc -E`, one for every input file
* multiple "source postprocessor" steps = custom code transformer, one for every input file
* one compile step
* one "binary postprocessor" step, so we need the output path

solution: a wrapper script for gcc, which understands some gcc options,
which can split the compilation into phases,
which can manipulate the intermediary files.

### example

the input is something like

```
gcc -o /out/output.o -frandom-seed=asdf -D PREFIX=/some/variable/path \
  -I/tmp/include/ /src/source1.c /src/source2.cc
```

* patch `-D PREFIX=/some/variable/path` to something constant
* remove `-frandom-seed=asdf`
* always set `-frandom-seed=some_constant_string`. we use the output path `/out/output.o`, just like [bazel: `-frandom-seed=%{output_file}`](https://github.com/bazelbuild/bazel/issues/6540).
* preprocess /src/source1.c to /tmp/source1.i
* preprocess /src/source2.cc to /tmp/source2.ii
* postprocess /tmp/source1.i
* postprocess /tmp/source2.ii
* compile /tmp/source1.i + /tmp/source2.ii &rarr; /out/output.o

## related

### parse arguments from array

* https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
  * https://stackoverflow.com/a/38297066/10440128 &rarr; https://github.com/matejak/argbash cli parser generator
  * https://stackoverflow.com/a/63413837/10440128 &rarr; https://github.com/ko1nksm/getoptions cli parser generator

### parse arguments from string

here: parse arguments from file, via [gcc's @file option](https://gcc.gnu.org/onlinedocs/gcc/Overall-Options.html)

