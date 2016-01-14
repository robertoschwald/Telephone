#!/bin/sh

# build script to build pjsip for Telephone.
# Uses Carthage for dependency management and checkout. 
# Later, we will add XCode project file to the pjproject fork to fully build with Carthage.

PJSIP_VERSION_TAG=2.4.5

pushd ..

if [ ! -d pjproject ]; then
  svn checkout http://svn.pjsip.org/repos/pjproject/tags/${PJSIP_VERSION_TAG} pjproject
fi

cd pjproject

echo "[+] Writing pjlib/include/pj/config_site.h"

cat <<EOF > pjlib/include/pj/config_site.h
#undef  PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO
#undef  PJMEDIA_AUDIO_DEV_HAS_COREAUDIO

#define PJMEDIA_AUDIO_DEV_HAS_PORTAUDIO 0
#define PJMEDIA_AUDIO_DEV_HAS_COREAUDIO 1
#define PJSIP_DONT_SWITCH_TO_TCP 1
#define PJSUA_MAX_ACC 32
#define PJMEDIA_RTP_PT_TELEPHONE_EVENTS 101
#define PJMEDIA_RTP_PT_TELEPHONE_EVENTS_STR "101"
#define PJ_DNS_MAX_IP_IN_A_REC 32
#define PJ_DNS_SRV_MAX_ADDR 32
#define PJSIP_MAX_RESOLVED_ADDRESSES 32
EOF

echo "[+] Building pjsip" &&
CFLAGS="-mmacosx-version-min=10.9" ./configure --target=x86_64-apple-darwin && make clean && make dep && make lib

echo "\n"
echo "****************************************************"
echo "pjlib created. Please build Telephone in XCode, now."
echo "****************************************************"