# Label Support Branch

This is a private fork of the original https://github.com/64characters/Telephone master branch, which adds Label support to the search results.
This is an interim solution until the new search GUI is available on the original project. When building and running this version, you see search results in format: "Contact Name - &lt;Addressbook-Label&gt; &lt;number&gt;"

Example:   "John Doe - Mobile &lt;01234567879&gt;"

WARNING
-------
The label support leaks the label to the remote party. So don't use offending labels in OSX Address Book :-)

-------

Telephone is a VoIP program which allows you to make phone calls over
the internet. It can be used to call regular phones via any
appropriate SIP provider. If your office or home phone works via SIP,
you can use that phone number on your Mac anywhere you have decent
internet connection.

## Building

### Opus

Opus codec is optional.

Download:

    $ ftp http://downloads.xiph.org/releases/opus/opus-1.1.3.tar.gz
    $ tar xzvf opus-1.1.3.tar.gz
    $ cd opus-1.1.3

Build and install:

    $ ./configure --prefix=/path/to/Telephone/ThirdParty/Opus --disable-shared CFLAGS='-O2 -mmacosx-version-min=10.10'
    $ make
    $ make install

### PJSIP

Download:

    $ ftp http://www.pjsip.org/release/2.5.5/pjproject-2.5.5.tar.bz2
    $ tar xzvf pjproject-2.5.5.tar.bz2
    $ cd pjproject-2.5.5

Create `pjlib/include/pj/config_site.h`:

    #define PJSIP_DONT_SWITCH_TO_TCP 1
    #define PJSUA_MAX_ACC 32
    #define PJMEDIA_RTP_PT_TELEPHONE_EVENTS 101
    #define PJMEDIA_RTP_PT_TELEPHONE_EVENTS_STR "101"
    #define PJ_DNS_MAX_IP_IN_A_REC 32
    #define PJ_DNS_SRV_MAX_ADDR 32
    #define PJSIP_MAX_RESOLVED_ADDRESSES 32
    #define PJ_GETHOSTIP_DISABLE_LOCAL_RESOLUTION 1

Build and install (remove `--with-opus` option if you don’t need Opus):

    $ ./configure --prefix=/path/to/Telephone/ThirdParty/PJSIP --with-opus=/path/to/Telephone/ThirdParty/Opus --host=x86_64-apple-darwin CFLAGS='-mmacosx-version-min=10.10'
    $ make lib
    $ make install

### LibreSSL

    $ ftp http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-2.4.3.tar.gz
    $ ftp http://ftp.openbsd.org/pub/OpenBSD/LibreSSL/libressl-2.4.3.tar.gz.asc
    $ gpg --verify libressl-2.4.3.tar.gz.asc
    $ tar xzvf libressl-2.4.3.tar.gz
    $ cd libressl-2.4.3
    $ ./configure --prefix=/path/to/Telephone/ThirdParty/LibreSSL --disable-shared CFLAGS='-mmacosx-version-min=10.10'
    $ make
    $ make install

    
Build Telephone.

## Contribution

For the legal reasons, pull requests are not accepted. Please feel
free to share your thoughts and ideas by commenting on the issues.
