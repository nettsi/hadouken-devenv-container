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
set -eu

echo "Current user is $(whoami)"

# run bash function as super user
# no params
function sufu {
    local firstArg=$1
    if [ $(type -t $firstArg) = function ]
    then
        shift && command sudo bash -c "$(declare -f $firstArg);$firstArg $*"
    elif [ $(type -t $firstArg) = alias ]
    then
        alias sudo='\sudo '
        eval "sudo $@"
    else
        command sudo "$@"
    fi
}

# username useruid usergid
function add_user {
    ( groupadd --gid ${3} ${1} && useradd -s /bin/bash --uid ${2} --gid ${3} -m ${1} ) || return $?
    return 0
}
# username
function make_user_sudoer {
    ( echo ${1} ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/${1} && chmod 0440 /etc/sudoers.d/${1} ) || return $?
    return 0
}

# username
function switch_to_user {
    ( su - $1 ) || return $?
    return 0
}
# no params
function apt_cleanup {
    ( $apt_command autoremove -y && $apt_command clean -y && rm -rf /var/lib/apt/lists/* ) || return $?
    return 0
}
# no params
function pip_cleanup {
    return pip cache purge || true
}

#;
# cleanup()
# perform package manager cleanup and remove temporary files
# @return void
#"
function cleanup {
    sufu apt_cleanup
    sufu pip_cleanup 
    pip_cleanup 
    # Clean all temporary files
    sudo rm -rf /tmp/*
}

#;
# install_bash_git_prompt()
# install bash-git-prompt
# @param user: user to install bash-git-prompt-for
# @return error code
#"
function install_bash_git_prompt {
    readonly BASH_GIT_PROMPT_REPO_URL=https://github.com/magicmonty/bash-git-prompt.git
    # Install "bash git prompt"
    git clone --depth=1 -- ${BASH_GIT_PROMPT_REPO_URL} /home/$1/.bash-git-prompt && \
 cat <<EOF >> /home/${1}/.bashrc 
if [ -f "/home/${1}/.bash-git-prompt/gitprompt.sh" ]; then 
    GIT_PROMPT_ONLY_IN_REPO=1
    GIT_PROMPT_FETCH_REMOTE_STATUS=0 # (mgilor): Enabling it causes some weird loop on ssh authenticity dialog, rendering the shell useless.
    # GIT_PROMPT_THEME=Crunch # (mgilor): This theme causes terminal input to loop on same line
    source /home/${1}/.bash-git-prompt/gitprompt.sh
fi
EOF
    return $?
}

function install_apt_packages {
    readonly apt_command='apt-get'
    readonly apt_args='-y install --no-install-recommends'
    # Packages to be installed via apt
    # TODO(mgilor): In order to save space, it might be a good idea to separate these tools 
    # to their own containers, then layer them as needed (make them opt-in).
    readonly apt_package_list=(
        # Prerequisites
        apt-utils dialog sudo
        # Editors
        nano vim
        # Verify ssh, git, git-flow, git-lfs process tools, lsb-release (useful for CLI installs) installed
        ssh git git-flow git-lfs iproute2 procps lsb-release
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
        # Unit test, mock and benchmark
        libgtest-dev libgmock-dev libbenchmark-dev
        # Debugging/tracing
        valgrind
        # Install code coverage
        lcov gcovr
        # Documentation & graphing
        doxygen doxygen-doxyparse graphviz
        # Miscallenaous utilities
        bash-completion
    )

    echo "Installing apt packages..."
    ( ${apt_command} update && ${apt_command} ${apt_args} ${apt_package_list[@]} ) || return $?
    return 0
}

function install_pip_packages {
    readonly pip_command='pip3'
    readonly pip_args='install'
    # Packages to be installed via pip
    readonly pip_package_list=(
        conan
        requests
    )
    echo "Installing pip packages..."
    ( $pip_command $pip_args ${pip_package_list[@]} ) || return $?
    return 0
}

#;
# install_conan_packages()
# install conan packages
# @param user: user to install conan packages for
# @return error code
#"
function install_conan_packages {
    readonly conan_command='conan'
    echo "Installing conan packages..."
    # Create new default conan profile
    ( sudo su ${1} -c "${conan_command} profile new default --detect" \
    &&
    sudo su ${1}-c "${conan_command} profile update settings.os_target=Linux default" \
    &&
    sudo su ${1} -c "${conan_command} profile update settings.arch_target=x86_64 default" \
    &&
    sudo su ${1} -c "${conan_command} profile update settings.compiler.libcxx=libstdc++11 default" \
    &&
    sudo su ${1} -c "${conan_command} profile update env.CC=/usr/bin/gcc-10 default" \
    &&
    sudo su ${1} -c "${conan_command} profile update env.CXX=/usr/bin/g++-10 default" \
    &&
    sudo su ${1} -c "${conan_command} profile update settings.cppstd=20 default" \
    &&
    sudo su ${1} -c "${conan_command} profile update settings.build_type=RelWithDebInfo default" \
    &&
    sudo su ${1} -c "${conan_command} install gtest/1.10.0@_/_ --build missing"  \
    &&
    sudo su ${1} -c "${conan_command} install gtest/1.10.0@_/_ -s build_type=Debug --build missing" \
    &&
    sudo su ${1} -c "${conan_command} install benchmark/1.5.2@_/_ --build missing" \
    &&
    sudo su ${1} -c "${conan_command} install benchmark/1.5.2@_/_ -s build_type=Debug --build missing" ) \
    || return $?
    return 0
}

function adjust_symlinks {
    # Remove existing symlinks
    sudo rm /usr/bin/gcc 2>/dev/null || true
    sudo rm /usr/bin/g++ 2>/dev/null || true
    sudo rm /usr/bin/gcov 2>/dev/null || true
    sudo rm /usr/bin/python 2>/dev/null || true

    # Create new symlinks 
    sudo ln -sf /usr/bin/g++-10 /usr/bin/g++
    sudo ln -sf /usr/bin/gcc-10 /usr/bin/gcc
    sudo ln -sf /usr/bin/gcov-10 /usr/bin/gcov
    sudo ln -sf /usr/bin/python3 /usr/bin/python
}

( install_apt_packages \
&&
add_user ${USERNAME} ${USER_UID} ${USER_GID} \
&&
make_user_sudoer $USERNAME \
&&
switch_to_user $USERNAME \
&& 
install_pip_packages \
&&
install_bash_git_prompt $USERNAME \
&& 
install_conan_packages $USERNAME \
&& 
adjust_symlinks \
&&
cleanup) || exit 1

echo "Current user is $(whoami)"