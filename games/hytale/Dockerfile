#
# Copyright (c) 2026 Pterodactyl
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#

FROM 		--platform=$TARGETOS/$TARGETARCH ghcr.io/pterodactyl/yolks:java_25

LABEL       author="William V." maintainer="william.venner@infraly.co"

LABEL       org.opencontainers.image.source="https://github.com/pterodactyl/yolks"
LABEL       org.opencontainers.image.licenses=MIT

USER		root

RUN 		printf '%s\n' \
			'#!/bin/bash' \
			'# Default the TZ environment variable to UTC.' \
			'TZ=${TZ:-UTC}' \
			'export TZ' \
			'' \
			'# Set environment variable that holds the Internal Docker IP' \
			"INTERNAL_IP=\$(ip route get 1 | awk '{print \$(NF-2);exit}')" \
			'export INTERNAL_IP' \
			'' \
			"# Switch to the container's working directory" \
			'cd /home/container/Server || exit 1' \
			'' \
			'# Print Java version' \
			'printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0mjava -version\n"' \
			'java -version' \
			'' \
			'# Convert all of the "{{VARIABLE}}" parts of the command into the expected shell' \
			'# variable format of "${VARIABLE}" before evaluating the string and automatically' \
			'# replacing the values.' \
			"PARSED=\$(echo \"\${STARTUP}\" | sed -e 's/{{/\${/g' -e 's/}}/}/g' | eval echo \"\$(cat -)\")" \
			'' \
			"# Display the command we're running in the output, and then execute it with the env" \
			'# from the container itself.' \
			'printf "\033[1m\033[33mcontainer@pterodactyl~ \033[0m%s\n" "$PARSED"' \
			'# shellcheck disable=SC2086' \
			'exec env ${PARSED}' > /java.sh

RUN 		chmod +x /java.sh

RUN			apt-get update -y \
				&& apt-get install -y unzip jq \
				&& rm -rf /var/lib/apt/lists/*

RUN 		bash -c 'if [ "$(uname -m)" = "aarch64" ]; then apt update && apt upgrade -y && apt install -y libc++-dev libc6 git wget curl tar zip unzip binutils xz-utils liblzo2-2 cabextract iproute2 net-tools libatomic1 libsdl1.2debian libsdl2-2.0-0 libfontconfig libicu72 icu-devtools libunwind8 libssl-dev sqlite3 libsqlite3-dev libmariadb-dev libmariadb-dev-compat libduktape207 locales ffmpeg gnupg2 apt-transport-https software-properties-common ca-certificates libz3-dev rapidjson-dev tzdata libevent-dev libzip4 libsdl2-mixer-2.0-0 libsdl2-image-2.0-0 build-essential cmake libgdiplus libstdc++6 && update-locale LANG=en_US.UTF-8 && dpkg-reconfigure --frontend noninteractive locales && wget https://ryanfortner.github.io/box64-debs/box64.list -O /etc/apt/sources.list.d/box64.list && wget -qO- https://ryanfortner.github.io/box64-debs/KEY.gpg | gpg --dearmor -o /etc/apt/trusted.gpg.d/box64-debs-archive-keyring.gpg && apt update -y && apt install -y box64-generic-arm && rm -rf /var/lib/apt/lists/*; fi'


USER        container
ENV         USER=container HOME=/home/container
WORKDIR     /home/container

COPY 		./entrypoint.sh /entrypoint.sh

CMD         [ "/bin/bash", "/entrypoint.sh" ]
