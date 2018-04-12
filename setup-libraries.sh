#!/usr/bin/env bash

# Quick 'n dirty Telephone dependencies setup (unfortunately, it does not use Package Manager, Carthage, etc)

################################################################################

OPUS_VERSION="1.2.1"
PJSIP_VERSION="2.7.1"
LIBRESSL_VERSION="2.6.4"

telephone_lib_tmp_dir="/tmp/telephone_libs$$"
telephone_lib_logfile="/tmp/telephone_libs$$_build.log"

################################################################################

# Either set env var TELEPHONE_PROJECT_DIR to your Telephone project dir, or answer on script run

if [ -z $TELEPHONE_PROJECT_DIR ]; then
	echo "Telephone project dir?"
	read TELEPHONE_PROJECT_DIR
fi

if [ ! -d $TELEPHONE_PROJECT_DIR/Telephone.xcodeproj ]; then
	echo "Telephone Project dir $TELEPHONE_PROJECT_DIR not found"
	exit 1
fi

mkdir $telephone_lib_tmp_dir
cd $telephone_lib_tmp_dir

if [ -d $TELEPHONE_PROJECT_DIR/ThirdParty ]; then
	echo "Lib Dir $TELEPHONE_PROJECT_DIR/ThirdParty already exists. Overwrite?"
	read yn
	if [ "$yn" != "y" ]; then
		echo "Aborting."
		exit 1
	fi
	rm -r $TELEPHONE_PROJECT_DIR/ThirdParty
fi

# OPUS
echo "Downloading / Building OPUS ${OPUS_VERSION}"
wget --quiet https://archive.mozilla.org/pub/opus/opus-${OPUS_VERSION}.tar.gz >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
	echo "Download OPUS ${OPUS_VERSION} failed $? . Check $telephone_lib_logfile"
	exit 1
fi

tar xzf opus-${OPUS_VERSION}.tar.gz >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
	echo "Extract OPUS ${OPUS_VERSION} failed. Check $telephone_lib_logfile"
	exit 1
fi

cd opus-${OPUS_VERSION}
./configure --prefix=${TELEPHONE_PROJECT_DIR}/ThirdParty/Opus --disable-shared CFLAGS='-O2 -mmacosx-version-min=10.10'  >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Configure OPUS ${OPUS_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi

make install  >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Build OPUS ${OPUS_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi
cd ..

### PJSIP
echo "Downloading / Building PJSIP ${PJSIP_VERSION}"
wget --quiet http://www.pjsip.org/release/${PJSIP_VERSION}/pjproject-${PJSIP_VERSION}.tar.bz2  >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Download PJSIP ${PJSIP_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi

tar xzf pjproject-${PJSIP_VERSION}.tar.bz2  >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Extract PJSIP ${PJSIP_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi

cd pjproject-${PJSIP_VERSION}

cat <<EOF > pjlib/include/pj/config_site.h
#define PJSIP_DONT_SWITCH_TO_TCP 1
#define PJSUA_MAX_ACC 32
#define PJMEDIA_RTP_PT_TELEPHONE_EVENTS 101
#define PJMEDIA_RTP_PT_TELEPHONE_EVENTS_STR "101"
#define PJ_DNS_MAX_IP_IN_A_REC 32
#define PJ_DNS_SRV_MAX_ADDR 32
#define PJSIP_MAX_RESOLVED_ADDRESSES 32
#define PJ_GETHOSTIP_DISABLE_LOCAL_RESOLUTION 1
EOF

echo "PJLIB CONFIG:"  >> $telephone_lib_logfile 2>&1
cat pjlib/include/pj/config_site.h  >> $telephone_lib_logfile 2>&1

./configure --prefix=${TELEPHONE_PROJECT_DIR}/ThirdParty/PJSIP --with-opus=/path/to/Telephone/ThirdParty/Opus --disable-libyuv --disable-libwebrtc --host=x86_64-apple-darwin CFLAGS='-mmacosx-version-min=10.10'  >> $telephone_lib_logfile  2>&1
if [ $? != 0 ]; then
        echo "Configure PJSIP ${PJSIP_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi

make lib >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Make PJSIP ${PJSIP_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi
make install >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Install PJSIP ${PJSIP_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi
cd ..

### LibreSSL
echo "Downloading / Building LibreSSL ${LIBRESSL_VERSION}"
wget --quiet https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Download LibreSSL ${LIBRESSL_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi

wget --quiet https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-${LIBRESSL_VERSION}.tar.gz.asc >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Download LibreSSL Signature ${LIBRESSL_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi
gpg --verify libressl-${LIBRESSL_VERSION}.tar.gz.asc >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "GPG Verify LibreSSL ${LIBRESSL_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi
tar xzf libressl-${LIBRESSL_VERSION}.tar.gz >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Extract LibreSSL ${LIBRESSL_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi
cd libressl-${LIBRESSL_VERSION}
./configure --prefix=${TELEPHONE_PROJECT_DIR}/ThirdParty/LibreSSL --disable-shared CFLAGS='-mmacosx-version-min=10.10' >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Configure LibreSSL ${LIBRESSL_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi
make >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Make LibreSSL ${LIBRESSL_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi
make install >> $telephone_lib_logfile 2>&1
if [ $? != 0 ]; then
        echo "Install LibreSSL ${LIBRESSL_VERSION} failed. Check $telephone_lib_logfile"
        exit 1
fi
cd ..

rm -r $telephone_lib_tmp_dir

echo "Logfile: $telephone_lib_logfile"
echo " "
echo "Done. Compile in XCode, now"

