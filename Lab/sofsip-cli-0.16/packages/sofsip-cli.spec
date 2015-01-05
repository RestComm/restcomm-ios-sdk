#
# Template for Sofia SIP UA RPM spec file
#
# Options:
# -none-
#

Summary: Console mode SIP client
Name: sofsip-cli
Version: 0.16
Release: 1%{?dist}
License: Lesser GNU Public License 2.1
Group: System Environment/Libraries
URL: http://sf.net/projects/sofia-sip
Source0: %{name}-%{version}.tar.gz
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-root
Packager: Kai.Vehmanen@nokia.com

Requires: sofia-sip >= 1.11.0
BuildRequires: sofia-sip-devel >= 1.11.0

%description
A simple example client (sofsip_cli) demonstrating 
how to use the Sofia-SIP libsofia-sip-ua library in 
a VoIP/IM client.

%prep
%setup -q -n sofsip-cli-%{version}

%build
%configure --with-pic --enable-shared --disable-dependency-tracking --with-aclocal=aclocal
make 

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT

%clean
rm -rf $RPM_BUILD_ROOT

%files
%defattr(-,root,root,-)
%{_prefix}/%{_bin}/sofsip_cli
%doc AUTHORS COPYING NEWS README TODO
%{_mandir}/man1/sof*

%changelog
* Fri Feb 10 2006 Kai Vehmanen <kai.vehmanen@nokia.com>
- Added manpage to files list, fixed package name in 
  setup section.

* Fri Feb  3 2006 Kai Vehmanen <kai.vehmanen@nokia.com>
- Initial build.
