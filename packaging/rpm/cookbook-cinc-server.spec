Name: cookbook-cinc-server
Version: %{__version}
Release: %{__release}%{?dist}
BuildArch: noarch
Summary: Cinc server cookbook to install and configure it in redborder environments

License: AGPL 3.0
URL: https://github.com/redBorder/cookbook-cinc-server
Source0: %{name}-%{version}.tar.gz

%description
%{summary}

%prep
%setup -qn %{name}-%{version}

%build

%install
mkdir -p %{buildroot}/var/chef/cookbooks/cinc-server
cp -f -r  resources/* %{buildroot}/var/chef/cookbooks/cinc-server/
chmod -R 0755 %{buildroot}/var/chef/cookbooks/cinc-server
install -D -m 0644 README.md %{buildroot}/var/chef/cookbooks/cinc-server/README.md

%pre
if [ -d /var/chef/cookbooks/cinc-server ]; then
    rm -rf /var/chef/cookbooks/cinc-server
fi

%post
case "$1" in
  1)
    # This is an initial install.
    :
  ;;
  2)
    # This is an upgrade.
    if systemctl is-active --quiet opscode-erchef; then
      su - -s /bin/bash -c 'source /etc/profile && rvm gemset use default && env knife cookbook upload cinc-server'
    fi
  ;;
esac

%postun
# Deletes directory when uninstall the package
if [ "$1" = 0 ] && [ -d /var/chef/cookbooks/cinc-server ]; then
  rm -rf /var/chef/cookbooks/cinc-server
fi

%files
%defattr(0644,root,root)
%attr(0755,root,root)
/var/chef/cookbooks/cinc-server
%defattr(0644,root,root)
/var/chef/cookbooks/cinc-server/README.md

%doc

%changelog
* Wed Nov 25 2026 Miguel Negrón <manegron@redborder.com>
- First version: cookbook-chef-server ported to Cinc Server 15.10 (/opt/cinc-project, /etc/cinc-project, user cinc)
