# Debian Package Name
ARCH=$(shell arch)

# URL and Revision for Quagga to checkout
QUAGGAGIT = https://github.com/opensourcerouting/quagga-capnproto.git
QUAGGAREV = 2706164
RELEASE = 8

# URL and Revision for ODL Thrift Interface
QTHRIFTGIT = https://github.com/opensourcerouting/odlvpn2bgpd.git
QTHRIFTREV = b9ed3c7

# URL for Python Thrift Library
THRIFTPYGIT = https://github.com/opensourcerouting/thriftpy.git
THRIFTPYREV = c7e6cb2

# URL for Capnproto Library
CAPNPROTOGIT = https://github.com/opensourcerouting/capnproto.git
CAPNPROTOREV = 5f20b54

# URL for Python Capnproto Interface
PYCAPNPGIT = https://github.com/opensourcerouting/pycapnp.git
PYCAPNPREV = 33ca5c1

MKDIR = /bin/mkdir -p
MV = /bin/mv
RM = /bin/rm -f
RMDIR = /bin/rm -rf
COPY = /bin/cp -a
TAR = /bin/tar
SED = /bin/sed
THISDIR = $(shell pwd)
DEPPKGDIR = $(THISDIR)/depend
TEMPDIR = $(THISDIR)/temp
INSTALL = /usr/bin/install
DEBUILD = /usr/bin/debuild
RPMBUILD = /usr/bin/rpmbuild
GROFF = /usr/bin/groff
PATCH = /usr/bin/patch
GBP = /usr/bin/gbp

# Matching Quagga Package Version
VERSION = 0.99.24.99
SOURCEURL = http://www.quagga.net/
# We try to get username and hostname from system, but could be manually set if preferred
PKGUSER = OPNFV Pkg Builder
PKGEMAIL = <$(shell whoami)@$(shell hostname --fqdn)>

DEBPKGBUILD_DIR = quaggasrc
# The output dir for the packages needed to install
DEBPKGOUTPUT_DIR = $(THISDIR)/debian_package
DEB_PACKAGES = opnfv-quagga_$(VERSION)-$(RELEASE)_amd64.deb

RPMPKGBUILD_DIR = quaggasrc-rpm
# The output dir for the packages needed to install
RPMPKGOUTPUT_DIR = $(THISDIR)/rpm_package
RPM_PACKAGES = opnfv-quagga_$(VERSION)-$(RELEASE)_$(shell uname -m).rpm

# Extra package directory - built and partially needed for building, but
# not required on target system
EXTRAPACKAGES_DIR = $(THISDIR)/extras

# Build Date
DATE := $(shell date -u +"%a, %d %b %Y %H:%M:%S %z")
RPMDATE := $(shell date -u +"%a %b %d %Y")

# Finding correct target based on distribution
TARGET := $(shell if test -s /etc/debian_version; then echo "debian"; elif ( test -s /etc/redhat-release ) || ( test -s /etc/SuSE-release ); then echo "rpm"; else echo "unknown";  fi)

# Verify GCC/G++/CC Versions (Need 4.8 or higher)
GCCVERSION_OK := $(shell expr `gcc -dumpversion | cut -f1,2 -d.` \>= 4.8)
GCPPVERSION_OK := $(shell expr `g++ -dumpversion | cut -f1,2 -d.` \>= 4.8)
CCVERSION_OK := $(shell expr `cc -dumpversion | cut -f1,2 -d.` \>= 4.8)
ifneq "$(GCCVERSION_OK)" "1"
$(error "Outdated GCC: gcc must be 4.8 or higher (Reports Version $(shell expr `gcc -dumpversion`))")
endif
ifneq "$(GCPPVERSION_OK)" "1"
$(error "Outdated CC: cc must be 4.8 or higher (Reports Version $(shell expr `gcc -dumpversion`))")
endif
ifneq "$(CCVERSION_OK)" "1"
$(error "Outdated C++: g++ must be 4.8 or higher (Reports Version $(shell expr `gcc -dumpversion`))")
endif


all: $(TARGET)

rpm: $(RPMPKGOUTPUT_DIR)/$(RPM_PACKAGES) $(DEPPKGDIR)/capnproto-rpm $(DEPPKGDIR)/python-thriftpy-rpm $(DEPPKGDIR)/python-pycapnp-rpm

debian: $(DEBPKGOUTPUT_DIR)/$(DEB_PACKAGES) $(DEPPKGDIR)/capnproto-deb $(DEPPKGDIR)/python-thriftpy-deb $(DEPPKGDIR)/python-pycapnp-deb

unknown:
	$(error Unknown OS - only supporting Debian or RPM based systems)

$(DEBPKGOUTPUT_DIR)/$(DEB_PACKAGES): $(DEPPKGDIR)/capnproto-deb
	@echo 
	@echo
	@echo Building opnfv-quagga $(VERSION) Debian Pkg
	@echo    Using Quagga from $(QUAGGAGIT)
	@echo    opnfv-quagga $(VERSION)-$(RELEASE), Git Rev $(QUAGGAREV)
	@echo -------------------------------------------------------------------------
	@echo
	
	# Hack: We don't have capnproto installed yet (needs priv to install and we
	#       just built it. So we unpack library to temp directory and add it to paths
	#       from temp directory
	#
	rm -rf $(TEMPDIR)
	dpkg -x $(EXTRAPACKAGES_DIR)/$(shell cat $(DEPPKGDIR)/capnproto-deb) $(TEMPDIR)
	dpkg -x $(DEBPKGOUTPUT_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-deb) $(TEMPDIR)
	dpkg -x $(EXTRAPACKAGES_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-dev-deb) $(TEMPDIR)
	# Build capnp pkg_config temp config
	$(COPY) $(TEMPDIR)/usr/lib/pkgconfig/*.pc $(TEMPDIR)/
	$(SED) -i 's|prefix=/usr|prefix=$(TEMPDIR)/usr|g' $(TEMPDIR)/*.pc
	
	# Checkout and patch (if needed) the Capnproto Quagga Version and Thrift Interface
	#
	rm -rf $(DEBPKGBUILD_DIR) 
	git clone $(QUAGGAGIT) $(DEBPKGBUILD_DIR)
	cd $(DEBPKGBUILD_DIR); git checkout $(QUAGGAREV); git submodule init && git submodule update
	$(GROFF) -ms $(DEBPKGBUILD_DIR)/doc/draft-zebra-00.ms -T ascii > $(DEBPKGBUILD_DIR)/doc/draft-zebra-00.txt
	cd $(DEBPKGBUILD_DIR); ./bootstrap.sh
	git clone $(QTHRIFTGIT) $(DEBPKGBUILD_DIR)/qthrift
	cd $(DEBPKGBUILD_DIR)/qthrift; git checkout $(QTHRIFTREV)
	# Pack Up Source
	tar --exclude=".git*" -czf opnfv-quagga_$(VERSION).orig.tar.gz $(DEBPKGBUILD_DIR)

	# Build Debian Pkg Scripts and configs from templates
	#
	rm -rf debian
	cp -a debian_template $(DEBPKGBUILD_DIR)/debian
	#
	# Fix up the debian package build scripts
	#    debian/changelog
	$(SED) -i 's/%_VERSION_%/$(VERSION)/g' $(DEBPKGBUILD_DIR)/debian/changelog
	$(SED) -i 's/%_RELEASE_%/$(RELEASE)/g' $(DEBPKGBUILD_DIR)/debian/changelog
	$(SED) -i 's|%_SOURCEURL_%|$(SOURCEURL)|g' $(DEBPKGBUILD_DIR)/debian/changelog
	$(SED) -i 's/%_DATE_%/$(DATE)/g' $(DEBPKGBUILD_DIR)/debian/changelog
	$(SED) -i 's/%_USER_%/$(PKGUSER)/g' $(DEBPKGBUILD_DIR)/debian/changelog
	$(SED) -i 's/%_EMAIL_%/$(PKGEMAIL)/g' $(DEBPKGBUILD_DIR)/debian/changelog
	$(SED) -i 's|%_QUAGGAGIT_%|$(QUAGGAGIT)|g' $(DEBPKGBUILD_DIR)/debian/changelog
	$(SED) -i 's/%_QUAGGAREV_%/$(QUAGGAREV)/g' $(DEBPKGBUILD_DIR)/debian/changelog
	$(SED) -i 's|%_QTHRIFTGIT_%|$(QTHRIFTGIT)|g' $(DEBPKGBUILD_DIR)/debian/changelog
	$(SED) -i 's/%_QTHRIFTREV_%/$(QTHRIFTREV)/g' $(DEBPKGBUILD_DIR)/debian/changelog 
	#    debian/rules
	$(SED) -i 's/%_VERSION_%/$(VERSION)/g' $(DEBPKGBUILD_DIR)/debian/rules
	$(SED) -i 's/%_RELEASE_%/$(RELEASE)/g' $(DEBPKGBUILD_DIR)/debian/rules
	$(SED) -i 's|%_QUAGGAGIT_%|$(QUAGGAGIT)|g' $(DEBPKGBUILD_DIR)/debian/rules
	$(SED) -i 's/%_QUAGGAREV_%/$(QUAGGAREV)/g' $(DEBPKGBUILD_DIR)/debian/rules
	$(SED) -i 's|%_QTHRIFTGIT_%|$(QTHRIFTGIT)|g' $(DEBPKGBUILD_DIR)/debian/rules
	$(SED) -i 's/%_QTHRIFTREV_%/$(QTHRIFTREV)/g' $(DEBPKGBUILD_DIR)/debian/rules
	#
	# Build the Debian Source and Binary Package
	#  - Need to add reference to local Capnproto as we can't assume correct version
	#    to be installed (needs 0.5.99 or higher)
	cd $(DEBPKGBUILD_DIR); $(DEBUILD) --set-envvar PKG_CONFIG_PATH=$(TEMPDIR) --set-envvar LD_LIBRARY_PATH=$(TEMPDIR)/usr/lib --prepend-path $(TEMPDIR)/usr/bin -us -uc
	$(MKDIR) $(DEBPKGOUTPUT_DIR)
	$(MKDIR) $(EXTRAPACKAGES_DIR)
	$(MV) -f $(DEB_PACKAGES) $(DEBPKGOUTPUT_DIR)
	$(MV) -f opnfv-quagga*.deb $(EXTRAPACKAGES_DIR) 2> /dev/null || true

$(RPMPKGOUTPUT_DIR)/$(RPM_PACKAGES): $(DEPPKGDIR)/capnproto-rpm
	@echo 
	@echo
	@echo Building opnfv-quagga $(VERSION) RPM Pkg
	@echo    Using Quagga from $(QUAGGAGIT)
	@echo    opnfv-quagga $(VERSION)-$(RELEASE), Git Rev $(QUAGGAREV)
	@echo -------------------------------------------------------------------------
	@echo
	
	# Hack: We don't have capnproto installed yet (needs priv to install and we
	#       just built it. So we unpack library to temp directory and add it to paths
	#       from temp directory
	#
	rm -rf $(TEMPDIR)
	$(MKDIR) $(TEMPDIR)
	cd $(TEMPDIR); rpm2cpio $(EXTRAPACKAGES_DIR)/$(shell cat $(DEPPKGDIR)/capnproto-rpm) | cpio -idmv
	cd $(TEMPDIR); rpm2cpio $(RPMPKGOUTPUT_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-rpm) | cpio -idmv
	cd $(TEMPDIR); rpm2cpio $(EXTRAPACKAGES_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-dev-rpm) | cpio -idmv
	# Build capnp pkg_config temp config
	$(COPY) $(TEMPDIR)/usr/lib*/pkgconfig/*.pc $(TEMPDIR)/
	$(SED) -i 's|prefix=/usr|prefix=$(TEMPDIR)/usr|g' $(TEMPDIR)/*.pc
	$(SED) -i 's|dir=/usr|dir=$(TEMPDIR)/usr|g' $(TEMPDIR)/*.pc
	
	# Checkout and patch (if needed) the Capnproto Quagga Version and Thrift Interface
	#
	rm -rf $(RPMPKGBUILD_DIR) 
	git clone $(QUAGGAGIT) $(RPMPKGBUILD_DIR)
	cd $(RPMPKGBUILD_DIR); git checkout $(QUAGGAREV); git submodule init && git submodule update
	cd $(RPMPKGBUILD_DIR); $(PATCH) < $(THISDIR)/patches/010-configure.ac-force_gnu99.patch
	cd $(RPMPKGBUILD_DIR); $(PATCH) < $(THISDIR)/patches/020-configure.ac-remove_silent_rule.patch
	cd $(RPMPKGBUILD_DIR)/lib/c-capnproto; $(PATCH) -p1 < $(THISDIR)/patches/030-c-capnproto-cpp-std-hdr.patch

	$(SED) -i 's/AC_INIT(Quagga, 0.99.25-dev/AC_INIT(OPNFV-Quagga, $(VERSION)-$(RELEASE)/' $(RPMPKGBUILD_DIR)/configure.ac
	$(GROFF) -ms $(RPMPKGBUILD_DIR)/doc/draft-zebra-00.ms -T ascii > $(RPMPKGBUILD_DIR)/doc/draft-zebra-00.txt
	cd $(RPMPKGBUILD_DIR); ./bootstrap.sh
	git clone $(QTHRIFTGIT) $(RPMPKGBUILD_DIR)/qthrift
	cd $(RPMPKGBUILD_DIR)/qthrift; git checkout $(QTHRIFTREV)
	# Pack Up Source
	tar --exclude=".*" -czf opnfv-quagga_$(VERSION)-$(RELEASE).orig.tar.gz $(RPMPKGBUILD_DIR)

	##cd $(RPMPKGBUILD_DIR); export PKG_CONFIG_PATH=$(TEMPDIR); \
	##    LD_LIBRARY_PATH=$(TEMPDIR)/usr/lib; PATH=$(TEMPDIR)/usr/bin:$$PATH; \
	##	./configure
	##cd $(RPMPKGBUILD_DIR); PATH=$(TEMPDIR)/usr/bin:$$PATH; \
	##	export LD_LIBRARY_PATH=$(TEMPDIR)/usr/lib:$(TEMPDIR)/usr/lib64; make dist
	## tar --exclude=".*" -czf opnfv-quagga_$(VERSION)-$(RELEASE).orig.tar.gz $(RPMPKGBUILD_DIR)

	# Building rpmbuild structure
	rm -rf $(RPMPKGBUILD_DIR)/rpmbuild
	$(INSTALL) -d $(RPMPKGBUILD_DIR)/rpmbuild/{SPECS,SOURCES,SRPMS,BUILD,RPMS/$(ARCH)}
	$(COPY) rpm_template/opnfv-quagga.spec $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/
	$(COPY) rpm_template/opnfv-quagga-sources/* $(RPMPKGBUILD_DIR)/rpmbuild/SOURCES/
	mv opnfv-quagga_$(VERSION)-$(RELEASE).orig.tar.gz $(RPMPKGBUILD_DIR)/rpmbuild/SOURCES
	#
	# Fix up the rpmbuild package SPEC
	$(SED) -i 's/%_VERSION_%/$(VERSION)/g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec
	$(SED) -i 's/%_RELEASE_%/$(RELEASE)/g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec
	$(SED) -i 's|%_SOURCEURL_%|$(SOURCEURL)|g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec
	$(SED) -i 's/%_DATE_%/$(RPMDATE)/g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec
	$(SED) -i 's/%_USER_%/$(PKGUSER)/g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec
	$(SED) -i 's/%_EMAIL_%/$(PKGEMAIL)/g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec
	$(SED) -i 's|%_QUAGGAGIT_%|$(QUAGGAGIT)|g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec
	$(SED) -i 's/%_QUAGGAREV_%/$(QUAGGAREV)/g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec
	$(SED) -i 's|%_QTHRIFTGIT_%|$(QTHRIFTGIT)|g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec
	$(SED) -i 's/%_QTHRIFTREV_%/$(QTHRIFTREV)/g' $(RPMPKGBUILD_DIR)/rpmbuild/SPECS/opnfv-quagga.spec 
	#
	# Build the RPM Source and Binary Package
	#  - Need to add reference to local Capnproto as we can't assume correct version
	#    to be installed (needs 0.5.99 or higher)
	cd $(RPMPKGBUILD_DIR); PKG_CONFIG_PATH=$(TEMPDIR) PATH=$(TEMPDIR)/usr/bin:$$PATH \
		LD_LIBRARY_PATH=$(TEMPDIR)/usr/lib:$(TEMPDIR)/usr/lib64 CC=gcc \
		rpmbuild --define "_topdir `pwd`/rpmbuild" -ba rpmbuild/SPECS/opnfv-quagga.spec 
	#
	$(MKDIR) $(RPMPKGOUTPUT_DIR)
	$(MKDIR) $(EXTRAPACKAGES_DIR)
	$(MV) -f $(RPMPKGBUILD_DIR)/rpmbuild/RPMS/*/*devel*.rpm $(EXTRAPACKAGES_DIR) 2> /dev/null || true
	$(MV) -f $(RPMPKGBUILD_DIR)/rpmbuild/RPMS/*/*contrib*.rpm $(EXTRAPACKAGES_DIR) 2> /dev/null || true
	$(MV) -f $(RPMPKGBUILD_DIR)/rpmbuild/RPMS/*/*debuginfo*.rpm $(EXTRAPACKAGES_DIR) 2> /dev/null || true
	$(MV) -f $(RPMPKGBUILD_DIR)/rpmbuild/RPMS/*/*.rpm $(RPMPKGOUTPUT_DIR)

$(DEPPKGDIR)/capnproto-deb:
	@echo 
	@echo
	@echo Building capnproto Debian Pkg 0.5.99
	@echo    Using capnproto from $(CAPNPROTOGIT)
	@echo -------------------------------------------------------------------------
	@echo
	#
	# Create directory for depend packages and cleanup previous thriftpy packages
	$(MKDIR) $(DEPPKGDIR)
	rm -rf $(DEPPKGDIR)/capnproto*
	rm -rf $(DEPPKGDIR)/libcapnp*
	rm -rf $(DEBPKGOUTPUT_DIR)/capnproto*
	rm -rf $(DEBPKGOUTPUT_DIR)/libcapnp*
	#
	# Build debian package
	git clone $(CAPNPROTOGIT) $(DEPPKGDIR)/capnproto
	cd $(DEPPKGDIR)/capnproto; git checkout $(CAPNPROTOREV)
	cd $(DEPPKGDIR)/capnproto; tar czf capnproto_0.5.99.orig.tar.gz c++
	cd $(DEPPKGDIR)/capnproto/c++; $(DEBUILD) -us -uc
	#
	# Save Package to Output Directory
	$(MKDIR) $(DEBPKGOUTPUT_DIR)
	$(MKDIR) $(EXTRAPACKAGES_DIR)
	$(MV) -f $(DEPPKGDIR)/capnproto/capnproto*.deb $(EXTRAPACKAGES_DIR)
	$(MV) -f $(DEPPKGDIR)/capnproto/libcapnp-dev*.deb $(EXTRAPACKAGES_DIR)
	$(MV) -f $(DEPPKGDIR)/capnproto/libcapnp*.deb $(DEBPKGOUTPUT_DIR)
	# 
	# Create dummy flag file with filename for Makefile logic
	cd $(EXTRAPACKAGES_DIR); ls capnproto*.deb > $(DEPPKGDIR)/capnproto-deb
	cd $(EXTRAPACKAGES_DIR); ls libcapnp-dev*.deb > $(DEPPKGDIR)/libcapnp-dev-deb
	cd $(DEBPKGOUTPUT_DIR); ls libcapnp-[0-9]*.deb > $(DEPPKGDIR)/libcapnp-deb

$(DEPPKGDIR)/capnproto-rpm:
	@echo
	@echo
	@echo Building capnproto RPM Pkg 0.5.99
	@echo    Using capnproto from $(CAPNPROTOGIT)
	@echo -------------------------------------------------------------------------
	@echo
	#
	# Create directory for depend packages and cleanup previous thriftpy packages
	$(MKDIR) $(DEPPKGDIR)
	rm -rf $(DEPPKGDIR)/capnproto*
	rm -rf $(DEPPKGDIR)/libcapnp*
	rm -rf $(RPMPKGOUTPUT_DIR)/capnproto*
	rm -rf $(RPMPKGOUTPUT_DIR)/libcapnp*
	#
	# Build RPM package
	git clone $(CAPNPROTOGIT) $(DEPPKGDIR)/capnproto
	cd $(DEPPKGDIR)/capnproto; git checkout $(CAPNPROTOREV)
	cd $(DEPPKGDIR)/capnproto/c++; autoreconf -i
	cd $(DEPPKGDIR)/capnproto; tar czf capnproto_0.5.99.orig.tar.gz c++
	cd $(DEPPKGDIR)/capnproto; $(INSTALL) -d rpmbuild/{SPECS,SOURCES,SRPMS,BUILD,RPMS/$(ARCH)}
	cd $(DEPPKGDIR)/capnproto; mv capnproto_0.5.99.orig.tar.gz rpmbuild/SOURCES/
	cd $(DEPPKGDIR)/capnproto; cp $(THISDIR)/rpm_template/capnproto.spec rpmbuild/SPECS/
	$(RPMBUILD) --define "_topdir $(DEPPKGDIR)/capnproto/rpmbuild" -ba $(DEPPKGDIR)/capnproto/rpmbuild/SPECS/capnproto.spec
	#
	# Save Package to Output Directory
	$(MKDIR) $(RPMPKGOUTPUT_DIR)
	$(MKDIR) $(EXTRAPACKAGES_DIR)
	$(MV) -f $(DEPPKGDIR)/capnproto/rpmbuild/RPMS/*/capnproto*$(ARCH)*.rpm $(EXTRAPACKAGES_DIR)
	$(MV) -f $(DEPPKGDIR)/capnproto/rpmbuild/RPMS/*/libcapnp-dev*$(ARCH)*.rpm $(EXTRAPACKAGES_DIR)
	$(MV) -f $(DEPPKGDIR)/capnproto/rpmbuild/RPMS/*/libcapnp-[0-9]*$(ARCH)*.rpm $(RPMPKGOUTPUT_DIR)
	#
	# Create dummy flag file with filename for Makefile logic
	cd $(EXTRAPACKAGES_DIR); ls capnproto*.rpm > $(DEPPKGDIR)/capnproto-rpm
	cd $(EXTRAPACKAGES_DIR); ls libcapnp-dev*.rpm > $(DEPPKGDIR)/libcapnp-dev-rpm
	cd $(RPMPKGOUTPUT_DIR); ls libcapnp-[0-9]*.rpm > $(DEPPKGDIR)/libcapnp-rpm

$(DEPPKGDIR)/python-thriftpy-deb:
	@echo 
	@echo
	@echo Building Python thriftpy Debian Pkg
	@echo    Using thriftpy from $(THRIFTPYGIT)
	@echo -------------------------------------------------------------------------
	@echo
	#
	# Create directory for depend packages and cleanup previous thriftpy packages
	$(MKDIR) $(DEPPKGDIR)
	rm -rf $(DEPPKGDIR)/thriftpy*
	rm -rf $(DEPPKGDIR)/python-thriftpy*
	rm -rf $(DEBPKGOUTPUT_DIR)/python-thriftpy*
	#
	# Build debian package
	git clone $(THRIFTPYGIT) $(DEPPKGDIR)/thriftpy
	cd $(DEPPKGDIR)/thriftpy; git checkout $(THRIFTPYREV)
	cd $(DEPPKGDIR)/thriftpy; $(GBP) buildpackage --git-ignore-branch -us -uc
	#
	# Save Package to Output Directory
	$(MKDIR) $(DEBPKGOUTPUT_DIR)
	$(MV) -f $(DEPPKGDIR)/python-thriftpy*.deb $(DEBPKGOUTPUT_DIR)
	# 
	# Create dummy flag file with filename for Makefile logic
	cd $(DEBPKGOUTPUT_DIR); ls python-thriftpy*.deb > $(DEPPKGDIR)/python-thriftpy-deb

$(DEPPKGDIR)/python-thriftpy-rpm:
	@echo 
	@echo
	@echo Building Python thriftpy RPM Pkg
	@echo    Using thriftpy from $(THRIFTPYGIT)
	@echo -------------------------------------------------------------------------
	@echo
	#
	# Create directory for depend packages and cleanup previous thriftpy packages
	$(MKDIR) $(DEPPKGDIR)
	rm -rf $(DEPPKGDIR)/thriftpy*
	rm -rf $(DEPPKGDIR)/python-thriftpy*
	rm -rf $(RPMPKGOUTPUT_DIR)/python-thriftpy*
	#
	# Build debian package
	git clone $(THRIFTPYGIT) $(DEPPKGDIR)/thriftpy
	cd $(DEPPKGDIR)/thriftpy; git checkout $(THRIFTPYREV)
	cd $(DEPPKGDIR)/thriftpy; $(PATCH) < $(THISDIR)/patches/120-thriftpy-make-cython-optional.patch
	cd $(DEPPKGDIR)/thriftpy; python setup.py bdist --formats=rpm
	#
	# Save Package to Output Directory
	$(MKDIR) $(RPMPKGOUTPUT_DIR) 
	$(MKDIR) $(EXTRAPACKAGES_DIR)
	$(MV) -f $(DEPPKGDIR)/thriftpy/dist/thriftpy*debuginfo*$(ARCH).rpm  $(EXTRAPACKAGES_DIR) 2> /dev/null || true
	$(MV) -f $(DEPPKGDIR)/thriftpy/dist/thriftpy*$(ARCH)*.rpm  $(RPMPKGOUTPUT_DIR)
	# 
	# Create dummy flag file with filename for Makefile logic
	cd $(RPMPKGOUTPUT_DIR); ls thriftpy*.rpm > $(DEPPKGDIR)/python-thriftpy-rpm

$(DEPPKGDIR)/python-pycapnp-deb: $(DEPPKGDIR)/capnproto-deb
	@echo 
	@echo
	@echo Building Python pycapnp Debian Pkg
	@echo    Using pycapnp from $(PYCAPNPGIT)
	@echo -------------------------------------------------------------------------
	@echo
	#
	# Hack: We don't have capnproto installed yet (needs priv to install and we
	#       just built it. So we unpack library to temp directory and add it to paths
	#       from temp directory
	#
	rm -rf $(TEMPDIR)
	dpkg -x $(EXTRAPACKAGES_DIR)/$(shell cat $(DEPPKGDIR)/capnproto-deb) $(TEMPDIR)
	dpkg -x $(DEBPKGOUTPUT_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-deb) $(TEMPDIR)
	dpkg -x $(EXTRAPACKAGES_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-dev-deb) $(TEMPDIR)
	# Build capnp pkg_config temp config
	$(COPY) $(TEMPDIR)/usr/lib/pkgconfig/*.pc $(TEMPDIR)/
	$(SED) -i 's|prefix=/usr|prefix=$(TEMPDIR)/usr|g' $(TEMPDIR)/*.pc
	# Get shlib info from libcapnp
	dpkg -e $(DEBPKGOUTPUT_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-deb) $(TEMPDIR)/libcapnp-control
	#
	# Create directory for depend packages and cleanup previous thriftpy packages
	$(MKDIR) $(DEPPKGDIR)
	rm -rf $(DEPPKGDIR)/pycapnp*
	rm -rf $(DEPPKGDIR)/python-pycapnp*
	rm -rf $(DEBPKGOUTPUT_DIR)/python-pycapnp*
	#
	# Build debian package
	git clone $(PYCAPNPGIT) $(DEPPKGDIR)/pycapnp
	cd $(DEPPKGDIR)/pycapnp; git checkout $(PYCAPNPREV)
	# Remove capnproto build-dependency (we use temp unpacked version)
	$(SED) -i 's|cython, capnproto, libcapnp-dev|cython|g' $(DEPPKGDIR)/pycapnp/debian/control
	# Add capnproto library dependency
	$(SED) -i 's|misc:Depends}|misc:Depends}, libcapnp-0.5.99|g' $(DEPPKGDIR)/pycapnp/debian/control
	# Add shlibs from libcapnproto (can't be auto-determined as it's not installed at this time)
	cat $(TEMPDIR)/libcapnp-control/shlibs >> $(DEPPKGDIR)/pycapnp/debian/shlibs.local
	cd $(DEPPKGDIR); tar czf pycapnp_0.5.7.orig.tar.gz pycapnp
	cd $(DEPPKGDIR)/pycapnp; debuild  --prepend-path $(TEMPDIR)/usr/bin \
	    --set-envvar CPATH=$(TEMPDIR)/usr/include \
	    --set-envvar LIBRARY_PATH=$(TEMPDIR)/usr/lib \
	    --set-envvar LD_LIBRARY_PATH=$(TEMPDIR)/usr/lib -us -uc
	# cd $(DEPPKGDIR)/pycapnp; debuild  --prepend-path $(TEMPDIR)/usr/bin --set-envvar PKG_CONFIG_PATH=$(TEMPDIR) --set-envvar CPATH=$(TEMPDIR)/usr/include --set-envvar LIBRARY_PATH=$(TEMPDIR)/usr/lib --set-envvar LD_LIBRARY_PATH=$(TEMPDIR)/usr/lib -us -uc
	#
	# Save Package to Output Directory
	$(MKDIR) $(DEBPKGOUTPUT_DIR)
	$(MV) -f $(DEPPKGDIR)/python-pycapnp*.deb $(DEBPKGOUTPUT_DIR) 
	# 
	# Create dummy flag file with filename for Makefile logic
	cd $(DEBPKGOUTPUT_DIR); ls python-pycapnp*.deb > $(DEPPKGDIR)/python-pycapnp-deb

$(DEPPKGDIR)/python-pycapnp-rpm: $(DEPPKGDIR)/capnproto-rpm
	@echo 
	@echo
	@echo Building Python pycapnp RPM Pkg
	@echo    Using pycapnp from $(PYCAPNPGIT)
	@echo -------------------------------------------------------------------------
	@echo
	#
	# Hack: We don't have capnproto installed yet (needs priv to install and we
	#       just built it. So we unpack library to temp directory and add it to paths
	#       from temp directory
	#
	rm -rf $(TEMPDIR)
	$(MKDIR) $(TEMPDIR)
	cd $(TEMPDIR); rpm2cpio $(EXTRAPACKAGES_DIR)/$(shell cat $(DEPPKGDIR)/capnproto-rpm) | cpio -idmv
	cd $(TEMPDIR); rpm2cpio $(RPMPKGOUTPUT_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-rpm) | cpio -idmv
	cd $(TEMPDIR); rpm2cpio $(EXTRAPACKAGES_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-dev-rpm) | cpio -idmv
	# Build capnp pkg_config temp config
	$(COPY) $(TEMPDIR)/usr/lib*/pkgconfig/*.pc $(TEMPDIR)/
	$(SED) -i 's|prefix=/usr|prefix=$(TEMPDIR)/usr|g' $(TEMPDIR)/*.pc
	# Get shlib info from libcapnp
	$(MKDIR) $(TEMPDIR)/libcapnp-control
	cd $(TEMPDIR)/libcapnp-control; rpm2cpio $(RPMPKGOUTPUT_DIR)/$(shell cat $(DEPPKGDIR)/libcapnp-rpm) | cpio -idmv
	#
	# Create directory for depend packages and cleanup previous thriftpy packages
	$(MKDIR) $(DEPPKGDIR)
	rm -rf $(DEPPKGDIR)/pycapnp*
	rm -rf $(DEPPKGDIR)/python-pycapnp*
	rm -rf $(RPMPKGOUTPUT_DIR)/python-pycapnp*
	#
	# Build RPM package
	git clone $(PYCAPNPGIT) $(DEPPKGDIR)/pycapnp
	cd $(DEPPKGDIR)/pycapnp; git checkout $(PYCAPNPREV)
	cd $(DEPPKGDIR)/pycapnp;$(PATCH) < $(THISDIR)/patches/210-pycapnp-MANIFEST-add-all-dirs.patch
	# add local paths for building
	cd $(DEPPKGDIR)/pycapnp; CPATH=/usr/include:$(TEMPDIR)/usr/include \
	LIBRARY_PATH=/usr/lib:/usr/lib64:$(TEMPDIR)/usr/lib:$(TEMPDIR)/usr/lib64 \
	LD_LIBRARY_PATH=/usr/lib:/usr/lib64:$(TEMPDIR)/usr/lib:$(TEMPDIR)/usr/lib64 \
	python setup.py bdist --formats=rpm
	#
	# Save Package to Output Directory
	$(MKDIR) $(RPMPKGOUTPUT_DIR)
	$(MKDIR) $(EXTRAPACKAGES_DIR)
	$(MV) -f $(DEPPKGDIR)/pycapnp/dist/pycapnp*debuginfo*$(ARCH).rpm $(EXTRAPACKAGES_DIR) 2> /dev/null || true
	$(MV) -f $(DEPPKGDIR)/pycapnp/dist/pycapnp*$(ARCH).rpm $(RPMPKGOUTPUT_DIR)
	# 
	# Create dummy flag file with filename for Makefile logic
	cd $(RPMPKGOUTPUT_DIR); ls pycapnp*.rpm > $(DEPPKGDIR)/python-pycapnp-rpm

clean:
	@echo Cleaning files/directories for opnfv-quagga Package
	$(RMDIR) $(DEBPKGBUILD_DIR)
	$(RMDIR) $(DEBPKGOUTPUT_DIR)
	$(RMDIR) $(RPMPKGBUILD_DIR)
	$(RMDIR) $(RPMPKGOUTPUT_DIR)
	$(RMDIR) $(EXTRAPACKAGES_DIR)
	$(RMDIR) $(DEPPKGDIR)
	$(RMDIR) $(TEMPDIR)
	$(RM) *.deb
	$(RM) *.orig.tar.gz
	$(RM) *.debian.tar.gz
	$(RM) *.build
	$(RM) *.dsc
	$(RM) *.changes
