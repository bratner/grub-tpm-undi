#!/bin/bash
TRUSTEDGRUB_VERSION="TrustedGRUB-1.1.5"
TRUSTEDGRUB_ARCHIVE="${TRUSTEDGRUB_VERSION}.src.tar.gz"
VERBOSE=" /dev/null"
BUILD=1

export CC

configure_tgrub()
{
echo "- Deflating TrustedGRUB"
if test -d ${TRUSTEDGRUB_VERSION}; then
    echo "TrustedGRUB directory already exists!"
    echo "Please remove first (as root):"
    echo "	rm -rf ${TRUSTEDGRUB_VERSION}"
    exit -1
fi

if test -f ./${TRUSTEDGRUB_ARCHIVE}; then
    tar -xpzf ${TRUSTEDGRUB_ARCHIVE}
    if [ $? != 0 ]; then exit 1; fi
else
    echo "TrustedGRUB sources not present"
    exit -1
fi

echo "- Configuring TrustedGRUB"
if [[ $(which aclocal) = "" ]] ; then
    echo "Need automake and autoconf"
    exit -1
else
    cd ${TRUSTEDGRUB_VERSION}
    aclocal >& $VERBOSE
    if [ $? != 0 ]; then exit 501; fi
    autoconf >& $VERBOSE
    if [ $? != 0 ]; then exit 502; fi
    automake >& $VERBOSE
    if [ $? != 0 ]; then exit 503; fi
    if [[ $SHOWSHA1 ]] ; then
    	./configure CFLAGS="-DSHOW_SHA1" >& $VERBOSE
    else
	./configure --prefix=/opt/tgrub >& $VERBOSE
    fi
    if [ $? != 0 ]; then exit 504; fi
fi
}

built_tgrub()
{
echo "- Compiling TrustedGRUB"
gcc util/create_sha1.c -o util/create_sha1
if [ $? != 0 ]; then exit 601; fi
gcc util/verify_pcr.c -o util/verify_pcr
if [ $? != 0 ]; then exit 602; fi
make >& $VERBOSE 
if [ $? != 0 ]; then exit 603; fi
chmod g+w * -R
if [ $? != 0 ]; then exit 604; fi
chmod a+x util/grub-install
if [ $? != 0 ]; then exit 605; fi

if [[ $SRC == "src" ]] ; then
    echo "- done"
else
    echo "- done"
    echo 
    echo "Please do"
    echo "	'cp default /boot/grub'"
    echo "	'cd ${TRUSTEDGRUB_VERSION}'"
    echo "	'make install'"
    echo
    echo "To install TrustedGRUB to your local harddisc do:"
    echo
    echo "	'rm -rf /boot/grub/stage*'"
    echo "	'rm -rf /boot/grub/*1_5'"
    echo "	'cp default /boot/grub'"
    echo "	'cd ${TRUSTEDGRUB_VERSION}'"
    echo "	'cp stage1/stage1 /boot/grub'"
    echo "	'cp stage2/stage2 /boot/grub'"
    echo "	'./grub/grub --no-floppy'"
    echo "Then enter:"
    echo "	root (hdX,Y)"
    echo "	setup (hdX)"
    echo "	quit"
    echo
    echo "or alternatively"
    echo "	'rm -rf /boot/grub/stage*'"
    echo "	'rm -rf /boot/grub/*1_5'"
    echo "	'./${TRUSTEDGRUB_VERSION}/util/grub-install /dev/XXX --no-floppy'"
    echo 
fi

}
until [ -z "$1" ]; do
    case $1 in

"-h" | "--help")
    echo "Script to build TrustedGRUB."
    echo "The following options are possible:"
    echo ""
    echo "-f | --force   : force deleting of existing GRUB-directory"
    echo "-h | --help    : show this help"
    echo "-v | --verbose : compile with verbose output"
    echo "-n | --nobuild : extract and patch, but do not compile"
    echo "-s | --showsha1: compile TrustedGRUB with \"-DSHOW_SHA1\""
    exit 0
;;

"-f" | "--force")
    shift;
    DELETE=1
;;

"-s" | "--showsha1")
    shift;
    SHOWSHA1=1
;;

"-v" | "--verbose")
    shift;
    echo "Enabling verbose output"
    VERBOSE=" /dev/stdout"
;;

"-n" | "--nobuild")
    shift;
    BUILD=0
;;

*)
    shift;
;;

    esac    
done

if [[ $DELETE ]] ; then
    echo "Deleting old TrustedGRUB directory"
    rm -rf ${TRUSTEDGRUB_VERSION}
fi
configure_tgrub
if [[ "$BUILD" == "1" ]] ; then
    built_tgrub
fi
