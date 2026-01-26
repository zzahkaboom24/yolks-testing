#!/bin/bash
set -e

cd /home/container

if [[ "$(uname -m)" == "aarch64" ]]; then
	HYTALE_DOWNLOADER="qemu-x86_64-static ./hytale-downloader/hytale-downloader-linux"
else
	HYTALE_DOWNLOADER="./hytale-downloader/hytale-downloader-linux"
fi

"$HYTALE_DOWNLOADER" -patchline "$HYTALE_PATCHLINE" -print-version
LATEST_VERSION=$("$HYTALE_DOWNLOADER" -patchline "$HYTALE_PATCHLINE" -print-version)

if [[ -f ./config.json || -f ./HytaleServer.jar || -f ./HytaleServer.aot || -f ./whitelist.json || -f ./bans.json || -f ./whitelist.json ]]; then
	if [[ ! -d "/home/container/Server" ]]; then
		mkdir -p /home/container/Server
	fi
	mv ./Licenses ./Server || true
	mv ./logs ./Server || true
	mv ./mods ./Server || true
	mv ./universe ./Server || true
	mv ./auth.enc ./Server || true
	mv ./bans.json ./Server || true
	mv ./config.json ./Server || true
	mv ./config.json.bak ./Server || true
	mv ./HytaleServer.jar ./Server || true
	mv ./HytaleServer.aot ./Server || true
	mv ./permissions.json ./Server || true
	mv ./whitelist.json ./Server || true
fi

# Respect the user's patchline wish, if they so choose to change it from the server console
if [[ -f ./Server/config.json ]]; then
	if [[ ! -z "$(jq -r '.Update.Patchline // ""' ./Server/config.json)" ]]; then
		CONFIG_PATCHLINE=$(jq -r '.Update.Patchline // ""' ./Server/config.json)
		if [[ "$HYTALE_PATCHLINE" != "$CONFIG_PATCHLINE" ]]; then
			HYTALE_PATCHLINE="$CONFIG_PATCHLINE"
		fi
	fi
fi

# Default to false; We don't assume people to be providing the files themselves
HYTALE_MOUNT=false
if [[ -f "./HytaleMount/HytaleServer.zip" || -f "./HytaleMount/Assets.zip" ]]; then
	HYTALE_MOUNT=true
fi

# Default to downloading (unless we find matching version)
NEEDS_DOWNLOAD=true

# If HYTALE_SERVER_SESSION_TOKEN isn't set, assume the user will log in themselves, rather than a host's GSP
if [[ -z "$HYTALE_SERVER_SESSION_TOKEN" ]]; then
	# Apply staged update if present
	if [[ -f "./updater/staging/Server/HytaleServer.jar" ]]; then
		echo "[Launcher] Applying $LATEST_VERSION update..."
		# Only replace update files, preserve config.json/universe/mods
		cp -f ./updater/staging/Server/HytaleServer.jar ./Server/
		if [[ -f "./updater/staging/Server/HytaleServer.aot" ]]; then
			cp -f ./updater/staging/Server/HytaleServer.aot ./Server/
		fi
		if [[ -d "./updater/staging/Server/Licenses" ]]; then
			rm -rf ./Server/Licenses
			cp -r ./updater/staging/Server/Licenses ./Server
		fi
		if [[ -f "./updater/staging/Assets.zip" ]]; then
			cp -f ./updater/staging/Assets.zip ./
		fi
		#if [[ -f ".updater/staging/start.sh" ]]; then
		#	cp -f ./updater/staging/start.sh ./
		#fi
		#if [[ -f ".updater/staging/start.bat" ]]; then
		#	cp -f ./updater/staging/start.bat ./
		#fi

		rm -rf ./updater/staging
		if [[ -f ./Server/config.json ]]; then
			jq --arg version "$LATEST_VERSION" '.ServerVersion = $version' ./Server/config.json > ./Server/config.tmp.json && mv ./Server/config.tmp.json ./Server/config.json
		fi
	elif [[ -f "./Server/HytaleServer.jar" ]]; then
		if [[ -f ./Server/config.json ]]; then
			if [[ "$(jq -r '.ServerVersion // ""' ./Server/config.json)" != "" ]]; then
				CURRENT_VERSION=$(jq -r '.ServerVersion' ./Server/config.json)
			else
				CURRENT_VERSION=$(java -jar ./Server/HytaleServer.jar --version | awk '{print $2}' | sed 's/^v//')
			fi
		else
			CURRENT_VERSION=$(java -jar ./Server/HytaleServer.jar --version | awk '{print $2}' | sed 's/^v//')
		fi
		if [[ "$CURRENT_VERSION" != "$LATEST_VERSION" ]]; then
			echo -e "Server is out-of-date!"
			echo -e "Currently installed: $CURRENT_VERSION"
			echo -e "Latest available: $LATEST_VERSION"
			NEEDS_DOWNLOAD=true
		else
			echo -e "Server is up-to-date!"
			echo -e "Currently installed: $CURRENT_VERSION"
			echo -e "Latest available: $LATEST_VERSION"
        	NEEDS_DOWNLOAD=false
		fi
	else
		echo -e "Server has not yet been installed!"
		echo -e "Attempting install!"
	fi

	if [[ "$NEEDS_DOWNLOAD" == true ]]; then
		if [[ -f "./Server/HytaleServer.jar" ]]; then
			rm -rf ./Assets.zip
			rm -rf ./Server/HytaleServer.jar
			rm -rf ./Server/HytaleServer.aot
			rm -rf ./Server/Licenses
		fi
		"$HYTALE_DOWNLOADER" -patchline "$HYTALE_PATCHLINE" -download-path ./HytaleServer.zip
	fi

	if [[ -f "./HytaleServer.zip" ]]; then
		unzip -o ./HytaleServer.zip -d .
		rm -f ./HytaleServer.zip
	fi
fi

if [[ "$HYTALE_MOUNT" == true ]]; then
	if [[ -f "./HytaleMount/HytaleServer.zip" ]]; then
		unzip -o ./HytaleMount/HytaleServer.zip -d .
	fi
	if [[ -f "./HytaleMount/Assets.zip" ]]; then
		ln -s -f ./HytaleMount/Assets.zip Assets.zip
	fi
else
	if [[ -f "./Server/Assets.zip" ]]; then
		ln -s -f ./Server/Assets.zip Assets.zip
	fi
	if [[ -f "./HytaleServer.zip" ]]; then
		unzip -o ./HytaleServer.zip -d .
	fi
fi

# Removing launch scripts, because I don't believe them to be necessary.
# Updating server via /update download will cry about
# "Expected Assets.zip and launcher scripts in parent directory."
# But one can force it with /update download --force.
# If auto-update is the goal, just delete or comment the bottom 2 if-blocks.
if [[ -f start.bat ]]; then
	rm start.bat
fi
if [[ -f start.sh ]]; then
	rm start.sh
fi

# Download the latest hytale-sourcequery plugin if enabled
if [[ "${INSTALL_SOURCEQUERY_PLUGIN}" == "1" ]]; then
	mkdir -p ./Server/mods
	echo -e "Downloading latest hytale-sourcequery plugin..."
	LATEST_URL=$(curl -sSL https://api.github.com/repos/physgun-com/hytale-sourcequery/releases/latest \
		| grep -oP '"browser_download_url":\s*"\K[^"]+\.jar' || true)
	if [[ -n "$LATEST_URL" ]]; then
		curl -sSL -o ./Server/mods/hytale-sourcequery.jar "$LATEST_URL"
		echo -e "Successfully downloaded hytale-sourcequery plugin to mods folder."
	else
		echo -e "Warning: Could not find hytale-sourcequery plugin download URL."
	fi
fi

# This section restores custom values in the config.json
# Custom values are lost if an user runs /auth persistence Memory/Encrypted
if [[ -f ./Server/config.json && -f ./Server/config.json.bak ]]; then
	# Restore AheadOfTimeCacheTrained
	if [[ -z "$(jq -r '.AheadOfTimeCacheTrained // ""' ./Server/config.json)" ]]; then
		if [[ ! -z "$(jq -r '.AheadOfTimeCacheTrained // ""' ./Server/config.json.bak)" ]]; then
			AOT_BACKUP_FLAG=$(jq -r '.AheadOfTimeCacheTrained' ./Server/config.json.bak)
			jq --argjson trainaot "$AOT_BACKUP_FLAG" '.AheadOfTimeCacheTrained = $trainaot' ./Server/config.json > ./Server/config.tmp.json && mv ./Server/config.tmp.json ./Server/config.json
		fi
	fi
	# Restore ServerVersion
	if [[ "$(jq -r '.ServerVersion // ""' ./Server/config.json)" == "" ]]; then
		if [[ "$(jq -r '.ServerVersion // ""' ./Server/config.json.bak)" != "" ]]; then
			SV_BACKUP_FLAG=$(jq -r '.ServerVersion // ""' ./Server/config.json.bak)
			jq --arg version "$SV_BACKUP_FLAG" '.ServerVersion = $version' ./Server/config.json > ./Server/config.tmp.json && mv ./Server/config.tmp.json ./Server/config.json
		fi
	fi
fi

if [[ ! -d "/home/container/Server" ]]; then
	mkdir -p /home/container/Server
fi
cd /home/container/Server

MAX_HEAP=31744
AOT_TRAINED=false
# Re-train the Ahead-of-Time cache, because the one provided by Hytale can't load due to an "timestamp has changed" error
train_aot() {
	if [[ -f "./HytaleServer.aot" ]]; then
		rm -f ./HytaleServer.aot
	fi
	if [[ -f "./HytaleServer.aot.conf" ]]; then
		rm -f ./HytaleServer.aot.conf
	fi
	if [[ -f "./training.log" ]]; then
		rm -f ./training.log
	fi

	touch ./training.log

	(
		tail -f ./training.log | while read -r LINE; do
			echo "$LINE"
			if [[ "$LINE" == *"Hytale Server Booted"* ]]; then
				echo -e "Detected 'Hytale Server Booted'..."
				break
			fi
		done

		PID=$(pgrep -f "./HytaleServer.jar")
		echo -e "Triggering shutdown to generate AOT cache..."
		kill -TERM "$PID"
		echo -e "Training finished. Waiting for creation of AOT cache file..."
	) &

	if (( SERVER_MEMORY > MAX_HEAP )); then
		MAX_HEAP=31744
	elif (( SERVER_MEMORY == 0 )); then
		MAX_HEAP=$(free -m | awk '/Mem:/ {print $2}')
		if (( MAX_HEAP > 31744 )); then
			MAX_HEAP=31744
		fi
	else
		MAX_HEAP=$SERVER_MEMORY
	fi
	
	java -XX:AOTCacheOutput=./HytaleServer.aot -Xms128M -Xmx"${MAX_HEAP}"M -jar ./HytaleServer.jar --auth-mode "${HYTALE_AUTH_MODE}" --assets ../Assets.zip --bind "0.0.0.0:${SERVER_PORT}" 2>&1 | tee ./training.log

	TIMEOUT=30
	while [[ ! -f "./HytaleServer.aot" ]] && (( TIMEOUT > 0 )); do
		sleep 1
		(( TIMEOUT-- ))
	done
	if [[ ! -f "./HytaleServer.aot" ]]; then
		echo -e "AOT file not found after 30s."
	else
		echo -e "AOT cache created: HytaleServer.aot. Restarting server..."
	fi
}

if [[ "${USE_AOT_CACHE}" == "1" ]]; then
	if (( SERVER_MEMORY > 31744 )); then
		export JAVA_TOOL_OPTIONS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers"
	elif (( SERVER_MEMORY == 0 )); then
		MAX_HEAP=$(free -m | awk '/Mem:/ {print $2}')
		if (( MAX_HEAP > 31744 )); then
			export JAVA_TOOL_OPTIONS="-XX:-UseCompressedOops -XX:-UseCompressedClassPointers"
		else
			export JAVA_TOOL_OPTIONS="-XX:+UseCompressedOops -XX:+UseCompressedClassPointers"
		fi
	else
		export JAVA_TOOL_OPTIONS="-XX:+UseCompressedOops -XX:+UseCompressedClassPointers"
	fi
	if [[ ! -f ./config.json || ! -f ./HytaleServer.aot || "$NEEDS_DOWNLOAD" == true ]]; then
		train_aot
	elif [[ -f ./config.json && "$NEEDS_DOWNLOAD" == false ]]; then
		if [[ "$(jq -r '.AheadOfTimeCacheTrained // ""' ./config.json)" != "true" ]]; then
			train_aot
		fi
	fi
else
	AOT_TRAINED=false
	jq --argjson trainaot "$AOT_TRAINED" '.AheadOfTimeCacheTrained = $trainaot' ./config.json > ./config.tmp.json && mv ./config.tmp.json ./config.json
fi

if [[ -f ./training.log && -f ./config.json ]]; then
		AOT_TRAINED=true
		jq --argjson trainaot "$AOT_TRAINED" '.AheadOfTimeCacheTrained = $trainaot' ./config.json > ./config.tmp.json && mv ./config.tmp.json ./config.json
		rm -f ./training.log
fi

if [[ -f ./config.json ]]; then
	if [[ -n "$HYTALE_MAX_VIEW_RADIUS" ]]; then
		jq --argjson maxviewradius "$HYTALE_MAX_VIEW_RADIUS" '.MaxViewRadius = $maxviewradius' ./config.json > ./config.tmp.json && mv ./config.tmp.json ./config.json
	fi
	jq --arg version "$LATEST_VERSION" '.ServerVersion = $version' ./config.json > ./config.tmp.json && mv ./config.tmp.json ./config.json
fi

if [[ "${STARTUP:-}" =~ -jar\ Server/HytaleServer\.jar || "${0}" =~ -jar\ Server/HytaleServer\.jar ]]; then
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "!!                        OUTDATED STARTUP DETECTED                  !!"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo ""
  echo "ERROR: Your startup command still uses 'Server/HytaleServer.jar'"
  echo "       That's an outdated path from early versions of this Hytale egg."
  echo ""
  echo "What would happen on continued use:"
  echo " - Server files (universe/, config.json, logs/, backups/, etc.) are"
  echo "   generated in the wrong directory: /home/container"
  echo "   instead of the intended /home/container/Server directory."
  echo "   Ever since Hytale version 2026.01.24-6e2d4fc36"
  echo "   server files must be located in /home/container/Server"
  echo "   Additionally, the Server will not boot"
  echo "   because we run exit 1 upon detecting Server/HytaleServer.jar used"
  echo ""
  echo "To do:"
  echo " 1. Update to the latest Hytale egg version"
  echo ""
  echo "Server startup aborted to prevent usage on wrong path."
  echo "Update the egg and restart."
  echo ""
  exit 1
fi

/java.sh $@
