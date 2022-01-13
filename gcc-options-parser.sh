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



cLangExtPatt=" c h C H cc hh cpp hpp cxx hxx c++ h++ CPP HPP cp hp tcc "

declare -A tmpExtOfInExt
tmpExtOfInExt=( [c]=i [h]=gch [C]=i [H]=gch [cc]=ii [hh]=gch [cpp]=ii [hpp]=gch [cxx]=ii [hxx]=gch [c++]=ii [h++]=gch [CPP]=ii [HPP]=gch [cp]=ii [hp]=gch [tcc]=ii )

# when should gcc stop?

stopE=
stopS=
stopC=

for ((i = 0; i < ${#args[@]}; i++ ))
do
  a=${args[$i]}
  case "$a" in
    -o*)
      [ -n "$oPath" ] && { echo "error: can have only one output"; exit 1; }
      if [ "$a" != "-o" ]; then oPath=${a:2}; else : $((i++)); oPath=${args[$i]}; fi
      echo "o: $oPath"
      constArgs+=("")
    ;;
    -x*)
      if [ "$a" != "-x" ]; then inLang=${a:2}; else : $((i++)); inLang=${args[$i]}; fi
      echo "f: $inLang"
      constArgs+=("")
    ;;
    -E) stopE=1; constArgs+=("");;
    -S) stopS=1; constArgs+=("");;
    -c) stopC=1; constArgs+=("");;
    -frandom-seed=*) constArgs+=("");; # ignore
    -T|-e|-R|-A|-L|-G|-z|-I|-U|-h|-l|-F|-u|-B|-D|-J|-Hd|-Xf|-MQ|-Hf|-MD|-MT|-MF|-MMD|-init|-Tbss|-arch|--dump|-rpath|-Tdata|-gnatO|-specs|-Ttext|-iquote|-soname|-assert|-defsym|--specs|--entry|--assert|-wrapper|-segprot|--output|-isystem|-iprefix|-segaddr|-imacros|-Xlinker|-include|--prefix|-dumpdir|--include|-seg1addr|-isysroot|--sysroot|-filelist|--dumpdir|-dumpbase|--imacros|-aux-info|--dumpbase|-undefined|-sectorder|-idirafter|--language|-sectalign|-segcreate|-framework|-imultilib|-rpath-link|-iframework|-Xassembler|-sectcreate|-imultiarch|-image_base|-dylib_file|--for-linker|-iwithprefix|-client_name|-sub_library|--output-pch|--force-link|-sub_umbrella|-dumpbase-ext|-install_name|--dumpbase-ext|-bundle_loader|--define-macro|-Xpreprocessor|-pagezero_size|-mtarget-linker|--for-assembler|-seg_addr_table|-current_version|--include-prefix|-dependency-file|--undefine-macro|--print-file-name|-read_only_relocs|-allowable_client|--print-prog-name|-multiply_defined|-msmall-data-limit|-iwithprefixbefore|-sectobjectsymbols|--library-directory|--include-directory|-segs_read_only_addr|--write-dependencies|-segs_read_write_addr|--include-with-prefix|-dylinker_install_name|-exported_symbols_list|-compatibility_version|-multiply_defined_unused|-unexported_symbols_list|-seg_addr_table_filename|-fintrinsic-modules-path|--include-directory-after|--write-user-dependencies|-weak_reference_mismatches|--include-with-prefix-after|--include-with-prefix-before)
      : $((i++))
      b=${args[$i]}
      echo "2: $a $b"
      constArgs+=("$a" "$b")
    ;;
    -*)
      echo "1: $a"
      constArgs+=("$a")
    ;;
    @*)
      argsFile="${a:1}"
      [ ! -e "$argsFile" ] && { echo "error parsing option $a: no such file"; exit 1; }
      eval "fileArgs=( $(cat "$argsFile") )" # WARNING eval is unsafe
      args=( "${args[@]:0:$i}" "${fileArgs[@]}" "${args[@]:$((i + 1))}" )
      argsLen=${#args[@]}
      : $((i--))
    ;;
    *)
      inPathList+=("$a")
      inPathIdxList+=("$i")
      if [ "$inLang" = "none" ]
      then
        ext="${a##*.}"
        if [ "$ext" = "$a" ]; then inLangList+=("_ld")
        elif [[ "$cLangExtPatt" = *" $ext "* ]]; then inLangList+=("_cfam")
        else inLangList+=("_not_cfam")
        fi
      else
        inLangList+=("$inLang")
      fi
      echo "i: $a [format: ${inLangList[ -1]}]"
      constArgs+=("")
    ;;
  esac
done

# split the gcc command line -> one call per source file
# TODO run gcc calls in parallel

echo loop all args
for (( i=0; i<${#args[@]}; i++ ))
do
  echo "arg $i: ${args[$i]}"
done

echo loop inputs
for (( i=0; i<${#inPathList[@]}; i++ ))
do
  inPathIdx=${inPathIdxList[$i]}
  inPath=${inPathList[$i]}
  inLang=${inLangList[$i]}
  if [[ "$inLang" != "_ld" && "$inLang" != "_not_cfam" ]]
  then
    echo "arg $inPathIdx -> input $i: path $inPath + lang = $inLang"
    inArgs=("${constArgs[@]}")
    inExt=${inPath##*.}
    tmpExt=${tmpExtOfInExt[$inExt]}
    tmpName=$(echo "$inPath" | tr / +)
    tmpName=${tmpName%.*}
    [ ${#tmpName} -gt 240 ] && tmpName=${tmpName: -240} # max 255 chars
    tmpPath="/tmp/$tmpName.$tmpExt"

    inArgs[$inPathIdx]="$inPath"
    inArgs+=("-o" "$tmpPath")
    inArgs+=("-E") # stop after preprocess
    inArgs+=("-frandom-seed=$tmpPath")

    tmpArgs=()
    echo remove empty args FIXME UNSAFE. original args can have empty args.
    for (( k=0; k<${#inArgs[@]}; k++ ))
    do
      a="${inArgs[$k]}"
      [ "$a" != "" ] && tmpArgs+=("$a")
    done

    echo gcc "${tmpArgs[@]}"
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
