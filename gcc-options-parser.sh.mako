<%

# mako template for gcc-options-parser.bash
# mako is a superset of python

# config
# the "gcc" folder is in this folder:
gcc_src_dir = "./gcc"

import re, sys, os, glob

def separate_options_of_gcc_opt_file(gcc_opt_file):
  """
  return only the "separate" options, which consume the next argument
  """
  print(f"gcc_opt_file = {gcc_opt_file}")
  opts = []
  opt = null
  for line in open(gcc_opt_file, "r").readlines():
    line = line.strip()
    if line == "":
      if opt != null:
        if opt[0] != "Variable" and opt[0] != "###" and len(opt) > 1: # TODO parse sections? ###\nDriver etc
          # ignore: Variable\nint var_name
          # ignore: Mask(SVINTO)
          opts.append(opt[:])
        opt = null
      continue
    if line[0] == ";":
      continue
    if opt == null:
      opt = []
    opt.append(line)

  if opt != null:
    if opt[0] != "Variable" and opt[0] != "###" and len(opt) > 1: # TODO parse sections? ###\nDriver etc
      opts.append(opt[:])
    opt = null

  #print("debug: opts = " + repr(opts))

  for i in range(len(opts)):
    opt = opts[i]

    long_name = opt[0]

    long_name = long_name.split("=")[0]
    long_name = long_name.split(",")[0]
    # TODO better
    # probably can ignore these (unary options)

    long_name = "-" + long_name

    description = null
    try:
      description = opt[2]
    except IndexError:
      pass

    opts_opts = {}

    for m in re.findall(r"([^() ]+)(?:\(([^()]+)\))?", opt[1]):
      if True:
        m = [null, m[0], m[1]]
        if m[2]:
          opts_opts[m[1]] = m[2]
        else:
          opts_opts[m[1]] = True

    # test -> ok
    #if "Separate" in opts_opts:
    #  print(repr(opts_opts))

    variable_name = null
    try:
      variable_name = opts_opts["Var"]
    except KeyError:
      variable_name = long_name.replace("-", "_")

    # JoinedOrMissing: -time=timeval or time= (empty value)

    takes_value = False
    if "Joined" in opts_opts or "Separate" in opts_opts or "JoinedOrMissing" in opts_opts:
      takes_value = True
    
    short_name = null
    if len(long_name) == 2:
      short_name = long_name
      long_name = null

    opts[i] = {
      "variable_name": variable_name, # TODO use this
      "short_name": short_name,
      "long_name": long_name,
      "takes_value": False,
      "help_text": description,
      "opts_opts": opts_opts,
    }

  separate_options = []

  # TODO remove short/long name parsing, not used
  for opt in filter(lambda opt: "Separate" in opt["opts_opts"], opts):
    if opt["short_name"]:
      separate_options.append(opt["short_name"])
    if opt["long_name"]:
      separate_options.append(opt["long_name"])

  # TODO later sort by length ascending

  # filter unique, keep order
  #opts = list(dict.fromkeys(opts))
  # TODO later do this

  return separate_options




separate_options = []
for gcc_opt_file in glob.glob(gcc_src_dir+"/gcc/**/*.opt", recursive=True):
  separate_options += separate_options_of_gcc_opt_file(gcc_opt_file)

# remove special cases
separate_options = filter(lambda s: s!="-o" and s!="-x", separate_options)

# filter unique, change order
separate_options = list(set(separate_options))

# sort by length ascending
separate_options = sorted(separate_options, key=lambda s: len(s))

%>\
#! /usr/bin/env bash

# NOTE this file was generated by gcc-options-parser.sh.mako

args=("$@")

# used for all input files
constArgs=()

# default values
inPathList=()
inLangList=() # TODO use these in the last compile/assemble/link step only for the unprocessed files
inLang=none
oPath=a.out
<%doc>
  see "-o file" in https://gcc.gnu.org/onlinedocs/gcc/Overall-Options.html

  > If -o is not specified, the default is to put
  > an executable file in a.out,
  > the object file for source.suffix in source.o,
  > its assembler file in source.s,
  > a precompiled header file in source.suffix.gch,
  > and all preprocessed C source on standard output.
</%doc>

<%doc>
  C/C++ file extensions
  based on gcc/cp/lang-specs.h
  docs https://gcc.gnu.org/onlinedocs/gcc/Overall-Options.html#Options-Controlling-the-Kind-of-Output
  gcc is case-sensitive here
  this is an "inverse regex pattern"
  the leading + trailing spaces are required
</%doc>
cLangExtPatt=" c h C H cc hh cpp hpp cxx hxx c++ h++ CPP HPP cp hp tcc "

declare -A tmpExtOfInExt
tmpExtOfInExt=( [c]=i [h]=gch [C]=i [H]=gch [cc]=ii [hh]=gch [cpp]=ii [hpp]=gch [cxx]=ii [hxx]=gch [c++]=ii [h++]=gch [CPP]=ii [HPP]=gch [cp]=ii [hp]=gch [tcc]=ii )

# when should gcc stop?
<%doc> https://gcc.gnu.org/onlinedocs/gcc/Overall-Options.html </%doc>
stopE=
stopS=
stopC=

${"for ((i = 0; i < ${#args[@]}; i++ ))"}
do
  ${"a=${args[$i]}"}
  case "$a" in
    -o*)
      [ -n "$oPath" ] && { echo "error: can have only one output"; exit 1; }
      if [ "$a" != "-o" ]; then ${"oPath=${a:2}"}; else : $((i++)); ${"oPath=${args[$i]}"}; fi
      echo "o: $oPath"
      constArgs+=("")
    ;;
    -x*)
      if [ "$a" != "-x" ]; then ${"inLang=${a:2}"}; else : $((i++)); ${"inLang=${args[$i]}"}; fi
      echo "f: $inLang"
      constArgs+=("")
    ;;
    -E) stopE=1; constArgs+=("");;
    -S) stopS=1; constArgs+=("");;
    -c) stopC=1; constArgs+=("");;
    -frandom-seed=*) constArgs+=("");; # ignore
    ${"|".join(separate_options)})<%doc>
        note: -c -E -S ... are missing, cos they are "unary" options = dont consume the next argument.
        we parse only some of these unary options, the rest is passed through to gcc.
      </%doc>
      : $((i++))
      ${"b=${args[$i]}"}
      echo "2: $a $b"
      constArgs+=("$a" "$b")
    ;;
    -*)
      echo "1: $a"
      constArgs+=("$a")
    ;;
    @*)<%doc>
        @file is a "Joined only" option. see https://gcc.gnu.org/onlinedocs/gcc/Overall-Options.htm
      </%doc>
      ${ 'argsFile="${a:1}"' }
      [ ! -e "$argsFile" ] && { echo "error parsing option $a: no such file"; exit 1; }
      eval "fileArgs=( $(cat "$argsFile") )" # WARNING eval is unsafe
      ${ 'args=( "${args[@]:0:$i}" "${fileArgs[@]}" "${args[@]:$((i + 1))}" )' }<%doc> replace the @file argument </%doc>
      ${ 'argsLen=${#args[@]}' }<%doc> update length </%doc>
      : $((i--))<%doc> re-parse the replaced argument </%doc>
    ;;
    *)
      inPathList+=("$a")
      inPathIdxList+=("$i")
      if [ "$inLang" = "none" ]
      then<%doc> parse language from file extension </%doc>
        ${ 'ext="${a##*.}"' }
        if [ "$ext" = "$a" ]; then inLangList+=("_ld")<%doc>default: linker script. but "ld" is not supported by the "-x language" option</%doc>
        elif [[ "$cLangExtPatt" = *" $ext "* ]]; then inLangList+=("_cfam")<%doc>C family = C or C++</%doc>
        else inLangList+=("_not_cfam")<%doc>here we only care for "cfam or not cfam"</%doc>
        fi
      else
        inLangList+=("$inLang")
      fi
      ${ 'echo "i: $a [format: ${inLangList[ -1]}]"' }
      constArgs+=("")
    ;;
  esac
done

# split the gcc command line -> one call per source file
# TODO run gcc calls in parallel

echo loop all args
${ 'for (( i=0; i<${#args[@]}; i++ ))' }
do
  ${ 'echo "arg $i: ${args[$i]}"' }
done

echo loop inputs
${ 'for (( i=0; i<${#inPathList[@]}; i++ ))' }
do
  ${ 'inPathIdx=${inPathIdxList[$i]}' }
  ${ 'inPath=${inPathList[$i]}' }
  ${ 'inLang=${inLangList[$i]}' }
  if [[ "$inLang" != "_ld" && "$inLang" != "_not_cfam" ]]
  then
    echo "arg $inPathIdx -> input $i: path $inPath + lang = $inLang"
    ${ 'inArgs=("${constArgs[@]}")' }
    ${ 'inExt=${inPath##*.}' }
    ${ 'tmpExt=${tmpExtOfInExt[$inExt]}' }
    tmpName=$(echo "$inPath" | tr / +)
    ${ 'tmpName=${tmpName%.*}' }
    ${ '[ ${#tmpName} -gt 240 ] && tmpName=${tmpName: -240} # max 255 chars' }
    tmpPath="/tmp/$tmpName.$tmpExt"

    inArgs[$inPathIdx]="$inPath"
    inArgs+=("-o" "$tmpPath")
    inArgs+=("-E") # stop after preprocess
    inArgs+=("-frandom-seed=$tmpPath")<%doc>
      bazel: -frandom-seed=%{output_file}
      FIXME should be constant. input/output paths can be variable -> make paths relative to CCACHE_BASEDIR
    </%doc>

    tmpArgs=()
    echo remove empty args FIXME UNSAFE. original args can have empty args.
    ${ 'for (( k=0; k<${#inArgs[@]}; k++ ))' }
    do
      ${ 'a="${inArgs[$k]}"' }
      [ "$a" != "" ] && tmpArgs+=("$a")
    done

    ${ 'echo gcc "${tmpArgs[@]}"' }
    # TODO run gcc
    # TODO run gcc in background, wait for all to finish
    # TODO patch all temp files in one sed call
    # TODO
  else
    echo "ignore input $i: path $inPath + lang = $inLang"
  fi

done

cat <<EOF
stopE=$stopE
stopS=$stopS
stopC=$stopC
EOF
