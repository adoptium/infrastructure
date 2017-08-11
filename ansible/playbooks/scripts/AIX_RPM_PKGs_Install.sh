#!/bin/bash
#########################################################
# AdoptOpenJDK - Script to install RPM packages for AIX #
#########################################################
#
# Ansible requires 'python' to be available on the remote AIX system when exectuing a playbook
# Removing 'python' within the playbook will cause Ansible to error out.
# This script provides a workaround to uninstalling and upgrading 'python' along with installing all other required packages
#
cd /tmp/playbook_tmp/rpms/
#
rpm -e $(rpm -qa | grep cloud-init)					# Remove 'cloud-init' 
rpm -Uvh libsigsegv-*
rpm -Uvh m4-1.4.18-1.aix5.1.ppc.rpm
rpm -Uvh autoconf-2.69-2.aix5.1.ppc.rpm
rpm -Uvh readline-*
rpm -Uvh bc-1.07.1-1.aix5.1.ppc.rpm 
rpm -Uvh bison-*
rpm -Uvh bzip2-1.0.5-3.aix5.3.ppc.rpm 
rpm -Uvh libgcc-4.9.4-1.aix7.2.ppc.rpm
rpm -Uvh libstdc++-*
rpm -Uvh gmp-*
rpm -Uvh libiconv-1.15-1.aix5.1.ppc.rpm 
rpm -Uvh coreutils-8.26-1.aix5.1.ppc.rpm 
rpm -Uvh cpio-2.12-1.aix5.1.ppc.rpm 
rpm -Uvh openssl-*
rpm -Uvh libffi-3.2.1-2.aix5.1.ppc.rpm 
rpm -Uvh glib2-2.34.3-1.aix5.1.ppc.rpm 
rpm -Uvh pkg-config-0.29.1-1.aix5.1.ppc.rpm 
rpm -Uvh libffi-devel-3.2.1-2.aix5.1.ppc.rpm 
rpm -Uvh libidn-*
rpm -Uvh libssh2-*
rpm -Uvh libzip-*
rpm -Uvh libpng-1.6.30-1.aix5.1.ppc.rpm 
rpm -Uvh freetype2-2.7.1-1.aix5.1.ppc.rpm
rpm -Uvh mpfr-*
rpm -Uvh gawk-4.1.4-1.aix5.1.ppc.rpm 
rpm -Uvh less-487-1.aix5.1.ppc.rpm
rpm -Uvh popt-*
rpm -Uvh rsync-3.1.2-1.aix5.1.ppc.rpm 
rpm -Uvh libmpc-*
rpm -Uvh sed-4.4-1.aix5.1.ppc.rpm 
rpm -Uvh openldap-2.4.44-0.1.aix5.1.ppc.rpm
rpm -Uvh sudo-1.8.20p2-1.aix5.1.ppc.rpm 
rpm -Uvh unzip-6.0-6.aix5.1.ppc.rpm
rpm -Uvh vim-minimal-7.4.460-1.aix5.1.ppc.rpm 
rpm -Uvh vim-common-7.4.460-1.aix5.1.ppc.rpm
rpm -Uvh pcre-*
rpm -Uvh wget-1.19.1-1.aix5.1.ppc.rpm 
rpm -Uvh zip-3.0-2.aix5.1.ppc.rpm 
rpm -Uvh perl-5.8.8-2.aix5.1.ppc.rpm 
rpm -Uvh perl-Text-CSV_XS-0.52-1.aix5.1.ppc.rpm
rpm -Uvh perl-Text-Glob-0.08-1.aix5.1.noarch.rpm
rpm -Uvh perl-gettext-1.05-1.aix5.1.ppc.rpm 
rpm -Uvh curl-7.54.1-1.aix5.1.ppc.rpm 
rpm -Uvh expat-*
rpm -Uvh sqlite-3.19.3-1.aix5.1.ppc.rpm
rpm -Uvh gdbm-*
rpm -e $(rpm -qa | grep python)						# Remove old versions 'python' if installed
rpm -Uvh python-libs-2.7.13-1.aix6.1.ppc.rpm 
rpm -e $(rpm -qa | grep db-4)						# Remove old versions 'db' if installed
rpm -Uvh db4-4.8.30-1.aix5.1.ppc.rpm 
rpm -Uvh python-2.7.13-1.aix6.1.ppc.rpm 
rpm -Uvh tcl-8.6.6-1.aix5.1.ppc.rpm 
rpm -Uvh fontconfig-2.12.4-1.aix5.1.ppc.rpm 
rpm -Uvh libXrender-0.9.10-1.aix6.1.ppc.rpm 
rpm -Uvh libXft-2.3.2-1.aix5.1.ppc.rpm 
rpm -Uvh tk-8.6.6-1.aix5.1.ppc.rpm 
rpm -Uvh tkinter-2.7.13-1.aix6.1.ppc.rpm 
rpm -Uvh python-tools-2.7.13-1.aix6.1.ppc.rpm
rpm -Uvh git-2.2.2-3.aix5.1.ppc.rpm 
