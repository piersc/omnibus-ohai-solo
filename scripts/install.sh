#!/bin/sh
#
# Author:: Tyler Cloke (tyler@opscode.com)
# Author:: Stephen Delano (stephen@opscode.com)
# Author:: Seth Chisamore (sethc@opscode.com)
# Author:: Lamont Granquist (lamont@opscode.com)
# Copyright:: Copyright (c) 2010-2013 Opscode, Inc.
# License:: Apache License, Version 2.0
#
# Portions of this file have been modified by:
# Author:: Ryan Walker (ryan.walker@rackspace.com)
# Copyright:: Copyright (c) 2014 Rackspace Hosting
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

prerelease="false"

project="ohai-solo"

download_domain="http://ohai.rax.io"

# Check whether a command exists - returns 0 if it does, 1 if it does not
exists() {
  if command -v $1 >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

report_bug() {
  echo "Project: Ohai-Solo"
  echo "Component: Packages"
  echo "Label: Omnibus"
  echo "Version: $version"
  echo " "
  echo "Please detail your operating system type, version and any other relevant details"
}

# Get command line arguments
while getopts f:d: opt
do
  case "$opt" in

    f)  cmdline_filename="$OPTARG";;
    d)  cmdline_dl_dir="$OPTARG";;
    \?)   # unknown flag
      echo >&2 \
      "usage: $0 [-f filename | -d download_dir]"
      exit 1;;
  esac
done
shift `expr $OPTIND - 1`

machine=`uname -m`
os=`uname -s`

# Retrieve Platform and Platform Version
if test -f "/etc/lsb-release" && grep -q DISTRIB_ID /etc/lsb-release; then
  platform=`grep DISTRIB_ID /etc/lsb-release | cut -d "=" -f 2 | tr '[A-Z]' '[a-z]'`
  platform_version=`grep DISTRIB_RELEASE /etc/lsb-release | cut -d "=" -f 2`
elif test -f "/etc/debian_version"; then
  platform="debian"
  platform_version=`cat /etc/debian_version`
elif test -f "/etc/redhat-release"; then
  platform=`sed 's/^\(.\+\) release.*/\1/' /etc/redhat-release | tr '[A-Z]' '[a-z]'`
  platform_version=`sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/redhat-release`

  # If /etc/redhat-release exists, we act like RHEL by default
  if test "$platform" = "fedora"; then
    # Change platform version for use below.
    platform_version="6.0"
  fi
  platform="el"
elif test -f "/etc/system-release"; then
  platform=`sed 's/^\(.\+\) release.\+/\1/' /etc/system-release | tr '[A-Z]' '[a-z]'`
  platform_version=`sed 's/^.\+ release \([.0-9]\+\).*/\1/' /etc/system-release | tr '[A-Z]' '[a-z]'`
  # amazon is built off of fedora, so act like RHEL
  if test "$platform" = "amazon linux ami"; then
    platform="el"
    platform_version="6.0"
  fi
# Apple OS X
elif test -f "/usr/bin/sw_vers"; then
  platform="mac_os_x"
  # Matching the tab-space with sed is error-prone
  platform_version=`sw_vers | awk '/^ProductVersion:/ { print $2 }'`

  major_version=`echo $platform_version | cut -d. -f1,2`
  case $major_version in
    "10.6") platform_version="10.6" ;;
    "10.7"|"10.8"|"10.9") platform_version="10.7" ;;
    *) echo "No builds for platform: $major_version"
       report_bug
       exit 1
       ;;
  esac

  # x86_64 Apple hardware often runs 32-bit kernels (see OHAI-63)
  x86_64=`sysctl -n hw.optional.x86_64`
  if test $x86_64 -eq 1; then
    machine="x86_64"
  fi
elif test -f "/etc/release"; then
  platform="solaris2"
  machine=`/usr/bin/uname -p`
  platform_version=`/usr/bin/uname -r`
elif test -f "/etc/SuSE-release"; then
  if grep -q 'Enterprise' /etc/SuSE-release;
  then
      platform="sles"
      platform_version=`awk '/^VERSION/ {V = $3}; /^PATCHLEVEL/ {P = $3}; END {print V "." P}' /etc/SuSE-release`
  else
      platform="suse"
      platform_version=`awk '/^VERSION =/ { print $3 }' /etc/SuSE-release`
  fi
elif test "x$os" = "xFreeBSD"; then
  platform="freebsd"
  platform_version=`uname -r | sed 's/-.*//'`
elif test "x$os" = "xAIX"; then
  platform="aix"
  platform_version=`uname -v`
  machine="ppc"
fi

if test "x$platform" = "x"; then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

# Mangle $platform_version to pull the correct build
# for various platforms
major_version=`echo $platform_version | cut -d. -f1`
case $platform in
  "ubuntu")
    case $major_version in
      "9") platform_version="10.04";;
      "10") platform_version="10.04";;
      "11") platform_version="10.04";;
      "12") platform_version="12.04";;
      "13") platform_version="12.04";;
      "14") platform_version="14.04";;
    esac
    ;;
  "el")
    case $major_version in
      "7") platform_version="6";;
      *) platform_version=$major_version;;
    esac
    ;;
  "debian")
    case $major_version in
      "5") platform_version="6";;
      "6") platform_version="6";;
      "7") platform_version="7";;
    esac
    ;;
  "freebsd")
    platform_version=$major_version
    ;;
  "sles")
    platform_version=$major_version
    ;;
  "suse")
    platform_version=$major_version
    ;;
esac

if test "x$platform_version" = "x"; then
  echo "Unable to determine platform version!"
  report_bug
  exit 1
fi

if test "x$platform" = "xsolaris2"; then
  # hack up the path on Solaris to find wget
  PATH=/usr/sfw/bin:$PATH
  export PATH
fi

checksum_mismatch() {
  echo "Package checksum mismatch!"
  report_bug
  exit 1
}

unable_to_retrieve_package() {
  echo "Unable to retrieve a valid package!"
  report_bug
  echo "Metadata URL: $metadata_url"
  if test "x$download_url" != "x"; then
    echo "Download URL: $download_url"
  fi
  if test "x$stderr_results" != "x"; then
    echo "\nDEBUG OUTPUT FOLLOWS:\n$stderr_results"
  fi
  exit 1
}

capture_tmp_stderr() {
  # spool up /tmp/stderr from all the commands we called
  if test -f "/tmp/stderr"; then
    output=`cat /tmp/stderr`
    stderr_results="${stderr_results}\nSTDERR from $1:\n\n$output\n"
    rm /tmp/stderr
  fi
}

# do_wget URL FILENAME
do_wget() {
  echo "trying wget..."
  wget -O "$2" "$1" 2>/tmp/stderr
  rc=$?
  # check for 404
  grep "ERROR 404" /tmp/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
    unable_to_retrieve_package
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "wget"
    return 1
  fi

  return 0
}

# do_curl URL FILENAME
do_curl() {
  echo "trying curl..."
  curl -sL -D /tmp/stderr "$1" > "$2"
  rc=$?
  # check for 404
  grep "404 Not Found" /tmp/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
    unable_to_retrieve_package
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "curl"
    return 1
  fi

  return 0
}

# do_fetch URL FILENAME
do_fetch() {
  echo "trying fetch..."
  fetch -o "$2" "$1" 2>/tmp/stderr
  # check for bad return status
  test $? -ne 0 && return 1
  return 0
}

# do_curl URL FILENAME
do_perl() {
  echo "trying perl..."
  perl -e 'use LWP::Simple; getprint($ARGV[0]);' "$1" > "$2" 2>/tmp/stderr
  rc=$?
  # check for 404
  grep "404 Not Found" /tmp/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
    unable_to_retrieve_package
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "perl"
    return 1
  fi

  return 0
}

# do_curl URL FILENAME
do_python() {
  echo "trying python..."
  python -c "import sys,urllib2 ; sys.stdout.write(urllib2.urlopen(sys.argv[1]).read())" "$1" > "$2" 2>/tmp/stderr
  rc=$?
  # check for 404
  grep "HTTP Error 404" /tmp/stderr 2>&1 >/dev/null
  if test $? -eq 0; then
    echo "ERROR 404"
    unable_to_retrieve_package
  fi

  # check for bad return status or empty output
  if test $rc -ne 0 || test ! -s "$2"; then
    capture_tmp_stderr "python"
    return 1
  fi
  return 0
}

do_checksum() {
  if exists sha256sum; then
    checksum=`sha256sum $1 | awk '{ print $1 }'`
    if test "x$checksum" != "x$2"; then
      checksum_mismatch
    else
      echo "Checksum compare with sha256sum succeeded."
    fi
  elif exists shasum; then
    checksum=`shasum -a 256 $1 | awk '{ print $1 }'`
    if test "x$checksum" != "x$2"; then
      checksum_mismatch
    else
      echo "Checksum compare with shasum succeeded."
    fi
  elif exists md5sum; then
    checksum=`md5sum $1 | awk '{ print $1 }'`
    if test "x$checksum" != "x$3"; then
      checksum_mismatch
    else
      echo "Checksum compare with md5sum succeeded."
    fi
  elif exists md5; then
    checksum=`md5 $1 | awk '{ print $4 }'`
    if test "x$checksum" != "x$3"; then
      checksum_mismatch
    else
      echo "Checksum compare with md5 succeeded."
    fi
  else
    echo "WARNING: could not find a valid checksum program, pre-install shasum, md5sum or md5 in your O/S image to get valdation..."
  fi
}

# do_format_metadata FILENAME TMPFILE
do_format_metadata() {

  # Reformat metadata file for easier Bash parsing
  `tr , '\n' < $1|sed 's/^ //g'|sed 's/[{,},"]//g'|sed 's/:/ /g' > $2 && cat $2 > $1 && rm $2`
}

# do_download URL FILENAME
do_download() {
  echo "downloading $1"
  echo "  to file $2"

  # we try all of these until we get success.
  # perl, in particular may be present but LWP::Simple may not be installed

  if exists wget; then
    do_wget $1 $2 && return 0
  fi

  if exists curl; then
    do_curl $1 $2 && return 0
  fi

  if exists fetch; then
    do_fetch $1 $2 && return 0
  fi

  if exists perl; then
    do_perl $1 $2 && return 0
  fi

  if exists python; then
    do_python $1 $2 && return 0
  fi

  unable_to_retrieve_package
}

tar_unpack() {
  tarfile = "$1"
  if test -d ~rack; then
    workdir=~rack/rs-automations
    tar -C "$workdir" -zxvvf "$tarfile"||report_bug
    cat > "$workdir/ohai-solo/bin/ohai-solo" << HEREDOC
#!
export LD_LIBRARY_PATH=\$LD_LIBRARY_PATH:$workdir/ohai-solo/embedded/lib/
export GEM_PATH=\$GEM_PATH:$workdir/ohai-solo/embedded/lib/ruby/site_ruby/2.1.0/
export RUBYLIB=\$RUBYLIB:$workdir/ohai-solo/embedded/lib/ruby/2.1.0/:/home/rack/rs-automations/ohai-solo/embedded/lib/ruby/2.1.0/x86_64-linux
$workdir/ohai-solo/bin/ohai -d $workdir/ohai-solo/plugins
HEREDOC
    sed -i "s:#!/opt/ohai-solo/embedded/bin/ruby:#!$workdir/ohai-solo/embedded/bin/ruby:" "$workdir/ohai-solo/bin/ohai"
  else
    tar -C /opt -zxvvf "$tarfile"||report_bug
  fi
}
# install_file TYPE FILENAME
# TYPE is "rpm", "deb", "solaris", or "sh"
install_file() {
  echo "Installing Ohai-Solo $version"
  case "$1" in
    "rpm")
      echo "installing with rpm..."
      rpm -Uvh --nodeps --oldpackage --replacepkgs "$2"
      ;;
    "deb")
      echo "installing with dpkg..."
      dpkg -i "$2"
      ;;
    "solaris")
      echo "installing with pkgadd..."
      echo "conflict=nocheck" > /tmp/nocheck
      echo "action=nocheck" >> /tmp/nocheck
      echo "mail=" >> /tmp/nocheck
      pkgrm -a /tmp/nocheck -n ohaisolo >/dev/null 2>&1 || true
      pkgadd -n -d "$2" -a /tmp/nocheck ohaisolo
      ;;
    "sh" )
      echo "installing with sh..."
      sh "$2"
      ;;
    "gz" )
      echo "Unpacking .tar.gz..."
      tar_unpack "$2"
    *)
      echo "Unknown filetype: $1"
      report_bug
      exit 1
      ;;
  esac
  if test $? -ne 0; then
    echo "Installation failed"
    report_bug
    exit 1
  fi
}

echo "Downloading Ohai-Solo $version for ${platform}..."

if test "x$TMPDIR" = "x"; then
  tmp="/tmp"
else
  tmp=$TMPDIR
fi

# Remove any old install directories
rm -rf $tmp/ohai_solo_install.sh*

# secure-ish temp dir creation without having mktemp available (DDoS-able but not expliotable)
tmp_dir="$tmp/ohai_solo_install.sh.$$"
(umask 077 && mkdir $tmp_dir) || exit 1

metadata_filename="$tmp_dir/metadata.txt"

metadata_url="${download_domain}/latest.${platform}.${platform_version}.${machine}.json"

if test "x$platform" = "xsolaris2"; then
  if test "x$platform_version" = "x5.9" -o "x$platform_version" = "x5.10"; then
    # solaris 9 lacks openssl, solaris 10 lacks recent enough credentials - your base O/S is completely insecure, please upgrade
    metadata_url=`echo $metadata_url | sed -e 's/https/http/'`
  fi
fi

do_download "$metadata_url"  "$metadata_filename"

tmpfile="${TMPDIR}/${project}_metadata_temp.txt"

do_format_metadata "$metadata_filename" "$tmpfile"

cat "$metadata_filename"

# check that all the mandatory fields in the downloaded metadata are there
if grep '^basename' $metadata_filename > /dev/null && grep '^sha256' $metadata_filename > /dev/null && grep '^md5' $metadata_filename > /dev/null; then
  echo "downloaded metadata file looks valid..."
else
  echo "downloaded metadata file is corrupted or an uncaught error was encountered in downloading the file..."
  # this generally means one of the download methods downloaded a 404 or something like that and then reported a successful exit code,
  # and this should be fixed in the function that was doing the download.
  report_bug
  exit 1
fi

download_url="${download_domain}/`awk '$1 == "basename" { print $2 }' ${metadata_filename}`"

if test "x$platform" = "xsolaris2"; then
  if test "x$platform_version" = "x5.9" -o "x$platform_version" = "x5.10"; then
    # solaris 9 lacks openssl, solaris 10 lacks recent enough credentials - your base O/S is completely insecure, please upgrade
    download_url=`echo $download_url | sed -e 's/https/http/'`
  fi
fi

filename=`echo $download_url | sed -e 's/^.*\///'`
filetype=`echo $filename | sed -e 's/^.*\.//'`

if test "x$cmdline_filename" != "x"; then
  download_filename="$cmdline_filename"
elif test "x$cmdline_dl_dir" != "x"; then
  download_filename="$cmdline_dl_dir/$filename"
else
  download_filename="$tmp_dir/$filename"
fi

do_download "$download_url"  "$download_filename"

sha256=`awk '$1 == "sha256" { print $2 }' "$metadata_filename"`
md5=`awk '$1 == "md5" { print $2 }' "$metadata_filename"`

do_checksum "$download_filename" "$sha256" "$md5"

install_file $filetype "$download_filename"

if test "x$tmp_dir" != "x"; then
  rm -r "$tmp_dir"
fi
