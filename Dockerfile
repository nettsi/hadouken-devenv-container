# ______________________________________________________
# Development environment container docker file.
#
# @file     Dockerfile
# @author   Mustafa Kemal GILOR <mgilor@nettsi.com>
# @date     09.05.2020
# 
# Copyright (c) Nettsi Informatics Technology Inc. 
# All rights reserved. Licensed under the Apache 2.0 License. 
# See LICENSE in the project root for license information.
# 
# SPDX-License-Identifier:	Apache 2.0
# ______________________________________________________

FROM debian:sid-slim

# Labels
LABEL version="1.0.3" maintainer="Mustafa Kemal Gılor <mgilor@nettsi.com>" license="Apache 2.0"

# Avoid warnings by switching to noninteractive
ENV DEBIAN_FRONTEND=noninteractive

# This Dockerfile adds a non-root user with sudo access. Use the "remoteUser"
# property in devcontainer.json to use it. On Linux, the container user's GID/UIDs
# will be updated to match your local UID/GID (when using the dockerFile property).
# See https://aka.ms/vscode-remote/containers/non-root-user for details.
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

COPY bootstrap.sh /scripts/

# Configure apt and install packages
RUN chmod +x /scripts/bootstrap.sh
RUN env
RUN /scripts/bootstrap.sh  

# Switch back to dialog for any ad-hoc use of apt-get
ENV DEBIAN_FRONTEND=dialog
