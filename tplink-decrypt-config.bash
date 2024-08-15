#!/usr/bin/env bash

: ${DD:=dd}
: ${OPENSSL:=openssl}

d_des()
{
    infile=$1
    outfile=${infile%.*}.cfg

    key=478DA50BF9E3D2CF

    $DD if=$infile bs=1 iseek=148 status=none   |
        $OPENSSL enc -des-ecb -d -K $key -nopad |
        $OPENSSL zlib -d -out $outfile
}

eap245_header()
{
    # n.b. basenc is case-sensitive for A-F
    declare -a preamble=(
        # \0^E^A\0\0^A6IEAP245(TP-Link|UN|AC1750-D):3.0\0\0...
        00 05 01 00 00 01 36 49  45 41 50 32 34 35 28 54  # \0^E^A\0\0^A6I    EAP245(T
        50 2D 4C 69 6E 6B 7C 55  4E 7C 41 43 31 37 35 30  # P-Link|U          N|AC1750
        2D 44 29 3A 33 2E 30 00  00 00 00 00 00 00 00 00  # -D):3.0\0         \0\0\0\0\0\0\0\0
        00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  # \0\0\0\0\0\0\0\0  \0\0\0\0\0\0\0\0
        00 00 00 00 00 00 00 00  01 00 00 00 00 00 00 00  # \0\0\0\0\0\0\0\0  ^A\0\0\0\0\0\0\0
        00 00 00 00 00 00 00 00  00 00 00 01 00 00 00 00  # \0\0\0\0\0\0\0\0  \0\0\0^A\0\0\0\0
        00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  # \0\0\0\0\0\0\0\0  \0\0\0\0\0\0\0\0
        00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  # \0\0\0\0\0\0\0\0  \0\0\0\0\0\0\0\0
    )
    echo "${preamble[@]}" | basenc --decode --base16 --ignore-garbage
}

e_des()
{
    infile=$1
    outfile=${infile%.*}.new.bin

    key=478DA50BF9E3D2CF

    : ${TMPDIR:=${XDG_RUNTIME_DIR:-/tmp}}
    temprefix=$TMPDIR/tplink$$
    umask 077
    trap 'e=$?; rm -vf $temprefix.tem $temprefix.md5; exit $e' 0 1 2 3 15

    {
        # Replace bytes 0x04-0x14 before computing checksum
        echo 478DA50BF9E3D2CF8819839D4C061445 | basenc --base16 -d
        eap245_header
        jq -c --raw-output0 '.' $infile |
            $OPENSSL zlib -e -nopad     |
            $OPENSSL enc -des-ecb -K $key
    } > $temprefix.tem
    $OPENSSL enc -md5 -binary -in $temprefix.tem -out $temprefix.md5
    size=$(stat -c %s $temprefixout.bin.new.tem)
}

d_aes()
{
    infile=$1
    outfile=${infile%.*}.tgz

    key=30313233343536373839616263646566  # 0123456789abcdef
     iv=31323334353637383930616263646566  # 1234567890abcdef

    $DD if=$infile bs=1 iseek=128 status=none |
        $OPENSSL enc -aes-128-cbc -d -K $key -iv $iv -out $outfile
}

main()
{
#    d_des "$@"
    e_des "$@"
}

set -x
main "$@"

# eof
