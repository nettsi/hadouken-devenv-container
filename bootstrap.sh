#!/usr/bin/env bash

# ______________________________________________________
# Container bootstrap script.
#
# @file     bootstrap.sh
# @author   Mustafa Kemal GILOR <mgilor@nettsi.com>
# @date     09.05.2020
# 
# Copyright (c) Nettsi Informatics Technology Inc. 
# All rights reserved. Licensed under the Apache 2.0 License. 
# See LICENSE in the project root for license information.
# 
# SPDX-License-Identifier:	Apache 2.0
# ______________________________________________________

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" 
done

SCRIPT_ROOT="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"

# Enable abort on error
set -e

readonly apt_command='apt-get'
readonly apt_args='-y install --no-install-recommends'
readonly pip_command='pip3'
readonly pip_args='install'

# Packages to be installed via apt
# TODO(mgilor): In order to save space, it might be a good idead to separate these tools 
# to their own containers, then layer them as needed (make them opt-in).
apt_package_list=(
    # Prerequisites
    apt-utils dialog
    # Editors
    nano vim
    # Verify ssh, git, process tools, lsb-release (useful for CLI installs) installed
    ssh git git-flow iproute2 procps lsb-release
    # Install GNU GCC Toolchain, version 10
    gcc-10 g++-10 gdb libstdc++-10-dev libc6-dev
    # Install LLVM Toolchain, version 10
    llvm-10 lldb-10 clang-10 clangd libc++-10-dev
    # Install build generator & dependency resolution and build accelarator tools
    make ninja-build autoconf automake libtool m4 cmake ccache
    # Install python & pip
    python3 python3-pip
    # Install static analyzers, formatting, tidying,
    clang-format-10 clang-tidy-10 iwyu cppcheck
    # Debugging/tracing
    valgrind 
    # Install test framework & benchmark 
    libgtest-dev libgmock-dev libbenchmark-dev
    # Install code coverage
    lcov gcovr
    # Documentation & graphing
    doxygen doxygen-doxyparse graphviz
    # Miscallenaous utilities
    bash-completion
)

# Packages to be installed via pip
pip_package_list=(
    conan
)

apt-get update \
&& 
# Install apt packages
$apt_command $apt_args ${apt_package_list[@]} \
&& 
# Install pip packages
( ( which $pip_command && $pip_command $pip_args ${pip_package_list[@]}) || true ) \
&& 
# Create a non-root user to use if preferred - see https://aka.ms/vscode-remote/containers/non-root-user.
groupadd --gid $USER_GID $USERNAME \
&& 
useradd -s /bin/bash --uid $USER_UID --gid $USER_GID -m $USERNAME \
&& 
# [Optional] Add sudo support for the non-root user
apt-get install -y sudo \
&& echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
&& chmod 0440 /etc/sudoers.d/$USERNAME \
&& 
# Clean up
apt-get autoremove -y \
&& apt-get clean -y \
&& rm -rf /var/lib/apt/lists/*

git clone --depth=1 -- https://github.com/magicmonty/bash-git-prompt.git /home/vscode/.bash-git-prompt && \
cat <<EOF >> /home/vscode/.bashrc 
if [ -f "/home/vscode/.bash-git-prompt/gitprompt.sh" ]; then 
    GIT_PROMPT_ONLY_IN_REPO=1
    GIT_PROMPT_FETCH_REMOTE_STATUS=0 # (mgilor): Enabling it causes some weird loop on ssh authenticity dialog, rendering the shell useless.
    GIT_PROMPT_THEME=Crunch
    source /home/vscode/.bash-git-prompt/gitprompt.sh
fi
EOF

# Remove existing symlinks
sudo rm /usr/bin/gcc 2>/dev/null || true
sudo rm /usr/bin/g++ 2>/dev/null || true

# Create new symlinks 
sudo ln -sf /usr/bin/g++-10 /usr/bin/g++
sudo ln -sf /usr/bin/gcc-10 /usr/bin/gcc
