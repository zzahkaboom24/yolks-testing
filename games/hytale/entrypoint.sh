#!/bin/bash
set -e

cd /home/container

if [[ "$(uname -m)" = "aarch64" ]]; then
	HYTALE_DOWNLOADER="qemu-x86_64-static ./hytale-downloader/hytale-downloader-linux"
else
	HYTALE_DOWNLOADER="./hytale-downloader/hytale-downloader-linux"
fi

# Default to false; We don't assume people to be providing the files themselves
HYTALE_MOUNT=false
if [[ -f "./HytaleMount/HytaleServer.zip" || -f "./HytaleMount/Assets.zip" ]]; then
	HYTALE_MOUNT=true
fi

LATEST_VERSION=$($HYTALE_DOWNLOADER -print-version)

# If HYTALE_SERVER_SESSION_TOKEN isn't set, assume the user will log in themselves, rather than a host's GSP
if [[ -z "$HYTALE_SERVER_SESSION_TOKEN" ]]; then
	
	# Default to downloading (unless we find matching version)
	NEEDS_DOWNLOAD=true
	if [[ -f "./Server/HytaleServer.jar" && -f config.json ]]; then
		CURRENT_VERSION=$(jq -r '.ServerVersion // ""' config.json)
		if [[ "$CURRENT_VERSION" == "$LATEST_VERSION" ]]; then
			NEEDS_DOWNLOAD=false
		fi
	fi

	if [[ "$NEEDS_DOWNLOAD" = true ]]; then
		if [[ -f "./Server/HytaleServer.jar" ]]; then
			rm -rf ./Server/*
		fi
		$HYTALE_DOWNLOADER -patchline "$HYTALE_PATCHLINE" -download-path HytaleServer.zip
	fi

	if [[ -f "HytaleServer.zip" ]]; then
		unzip -o HytaleServer.zip -d .
		rm -f HytaleServer.zip
	fi
fi

if [[ "$HYTALE_MOUNT" = true ]]; then
	if [[ -f "HytaleMount/HytaleServer.zip" ]]; then
		unzip -o HytaleMount/HytaleServer.zip -d .
	elif [[ -f "HytaleMount/Assets.zip" ]]; then
		ln -s -f HytaleMount/Assets.zip Assets.zip
	fi
else
	if [[ -f "Server/Assets.zip" ]]; then
		ln -s -f Server/Assets.zip Assets.zip
	elif [[ -f "HytaleServer.zip" ]]; then
		unzip -o HytaleServer.zip -d .
	fi
fi

if [[ -f config.json ]]; then
	if [[ -n "$HYTALE_MAX_VIEW_RADIUS" ]]; then
		jq --argjson maxviewradius "$HYTALE_MAX_VIEW_RADIUS" '.MaxViewRadius = $maxviewradius' config.json > config.tmp.json && mv config.tmp.json config.json
	fi
	jq --arg version "$LATEST_VERSION" '.ServerVersion = $version' config.json > config.tmp.json && mv config.tmp.json config.json
fi

# Download the latest hytale-sourcequery plugin if enabled
if [[ "${INSTALL_SOURCEQUERY_PLUGIN}" == "1" ]]; then
	mkdir -p mods
	echo -e "Downloading latest hytale-sourcequery plugin..."
	LATEST_URL=$(curl -sSL https://api.github.com/repos/physgun-com/hytale-sourcequery/releases/latest \
		| grep -oP '"browser_download_url":\s*"\K[^"]+\.jar' || true)
	if [[ -n "$LATEST_URL" ]]; then
		curl -sSL -o mods/hytale-sourcequery.jar "$LATEST_URL"
		echo -e "Successfully downloaded hytale-sourcequery plugin to mods folder."
	else
		echo -e "Warning: Could not find hytale-sourcequery plugin download URL."
	fi
fi

AOT_TRAINED=false
# Re-train the Ahead-of-Time cache, because the one provided by Hytale can't load due to an "timestamp has changed" error
train_aot() {
	if [[ -f "./Server/HytaleServer.aot" ]]; then
		rm -f ./Server/HytaleServer.aot
	fi
	
	exec 3< <(
		java -XX:AOTCacheOutput=Server/HytaleServer.aot -Xms128M $( ((SERVER_MEMORY)) && printf %s "-Xmx${SERVER_MEMORY}M" ) -jar Server/HytaleServer.jar $( ((HYTALE_ALLOW_OP)) && printf %s "--allow-op" ) $( ((HYTALE_ACCEPT_EARLY_PLUGINS)) && printf %s "--accept-early-plugins" ) $( ((DISABLE_SENTRY)) && printf %s "--disable-sentry" ) --auth-mode "${HYTALE_AUTH_MODE}" --assets Assets.zip --bind "0.0.0.0:${SERVER_PORT}" 2>&1
	)
	PID=$!

	while IFS= read -r LINE <&3; do
		echo "$LINE"
		if [[ "$LINE" == *"Hytale Server Booted"* ]]; then
			echo -e "Detected 'Hytale Server Booted'..."
			AOT_TRAINED=true
			jq --argjson trainaot "$AOT_TRAINED" '.AheadOfTimeCacheTrained = $trainaot' config.json > config.tmp.json && mv config.tmp.json config.json
			break
		fi
	done

	kill -TERM "$PID"
	echo -e "Training finished. Waiting for creation of AOT cache file..."
	wait "$PID"
	while [[ ! -f "./Server/HytaleServer.aot" ]]; do
    	sleep 1
	done
	echo -e "AOT cache created: HytaleServer.aot. Restarting server..."
	exec 3<&-
}

if [[ "${USE_AOT_CACHE}" == "1" ]]; then
	if [ "$(jq -r '.AheadOfTimeCacheTrained // ""' config.json)" != "true" ]; then
    	train_aot
	fi
fi

/java.sh $@
