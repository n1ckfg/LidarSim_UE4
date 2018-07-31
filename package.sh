#!/bin/bash
set -e

ARG_ZIP=
ARG_CLEAN=
for arg in "$@"; do
    case $arg in
        -z)
            ARG_ZIP="true";;
        -c)
            ARG_CLEAN="true";;
        -h)
            echo "Usage"
            echo ""
            echo "   bash package.sh [-h] [-c] [-z]"
            echo "     -h     display this usage information"
            echo "     -c     remove /opt prior to packaging"
            echo "     -z     zip /opt after packaging into anm_unreal_simulator.zip"
            echo ""
            exit;;
    esac
done

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SUBMODULES_DIR="$( dirname "$PROJECT_DIR" )"
UE_DIR=$SUBMODULES_DIR"/UnrealEngine"
PROJECT=$(basename "$PROJECT_DIR")
ANM_UNREAL_SIM_DIR="$( dirname "$SUBMODULES_DIR" )"

source $ANM_UNREAL_SIM_DIR/devel/setup.bash

if [ "$ARG_CLEAN" == "true" ]; then
    rm -rf "$PROJECT_DIR/opt/"
fi
mkdir -p "$PROJECT_DIR/opt/"

# without increasing this limit to 8192, Unreal will fail while cooking
# Unreal needs to watch a very large number of directories for changes
sudo sysctl fs.inotify.max_user_instances=8192
sudo sysctl fs.inotify.max_user_watches=8192

# build for distribution; required for packaging
$UE_DIR"/Engine/Build/BatchFiles/Linux/Build.sh" \
"$PROJECT" Development Linux \
-project=\""$PROJECT_DIR"/"$PROJECT".uproject\" \
-progress -NoHotReloadFromIDE


# build for editor; required for cooking
$UE_DIR"/Engine/Build/BatchFiles/Linux/Build.sh" \
"$PROJECT" Development Linux \
-project=\""$PROJECT_DIR"/"$PROJECT".uproject\" \
-progress -editorrecompile -NoHotReloadFromIDE


# This is the actual package command. Currently, this does not
# create a .pak file as it does not appear that UnrealPak is
# built automatically on Linux, so each uasset will be exposed.

$UE_DIR"/Engine/Build/BatchFiles/RunUAT.sh" BuildCookRun -nop4 \
-project=\""$PROJECT_DIR"/"$PROJECT".uproject\" \
-cook -compressed -allmaps -stage -archive -SkipCookingEditorContent \
-archivedirectory=\""$PROJECT_DIR"/opt/\""/" \
-package -LinuxNoEditor -clientconfig=Development -ue4exe=UE4Editor -clean \
-targetplatform=Linux -SkipCookingEditorContent -utf8output

# Copy plugin content over to packaged application

rsync -v -a --update "$PROJECT_DIR"/Plugins/sim_unreal_scenariomodules \
"$PROJECT_DIR"/opt/LinuxNoEditor/"$PROJECT"/Plugins/

# Symlink plugin configuration files
mkdir -p "$PROJECT_DIR"/opt/LinuxNoEditor/config
ln -sf ../base_unreal_project/Plugins/sim_unreal_scenariomodules/LaneletPlugin/Content/ "$PROJECT_DIR"/opt/LinuxNoEditor/config/Maps
ln -sf ../base_unreal_project/Plugins/sim_unreal_scenariomodules/ScenarioManager/Content/ "$PROJECT_DIR"/opt/LinuxNoEditor/config/Scenarios

# Rename into anm_unreal_simulator
TIMESTAMP=$(date +"%s")
mv "$PROJECT_DIR/opt/LinuxNoEditor" "$PROJECT_DIR/opt/anm_unreal_simulator_$TIMESTAMP"
echo "Successfully packaged the simulator into $PROJECT_DIR/opt/anm_unreal_simulator_$TIMESTAMP"

# Package ROS components
bash "$ANM_UNREAL_SIM_DIR/scripts/build_for_release.bash"

cp -r "$ANM_UNREAL_SIM_DIR/deploy/install/opt/ros" "$PROJECT_DIR/opt/"

echo "Successfully built and copied ros_unreal packages into $PROJECT_DIR/opt/ros_unreal"

# Scenarios folder
cp -r "$ANM_UNREAL_SIM_DIR/scenarios" "$PROJECT_DIR/opt/anm_unreal_simulator_$TIMESTAMP/"

# Overwrite the launch.bash with launch_packaged_simulator.bash
cp -f "$ANM_UNREAL_SIM_DIR/scripts/launch_packaged_simulator.bash" "$PROJECT_DIR/opt/anm_unreal_simulator_$TIMESTAMP/scenarios/launch.bash"

# Remove editor.bash because users will not have the editor
rm "$PROJECT_DIR/opt/anm_unreal_simulator_$TIMESTAMP/scenarios/editor.bash"

# Script for installing the dependencies on the target
cp "$ANM_UNREAL_SIM_DIR/scripts/prepare_target.bash" "$PROJECT_DIR/opt/anm_unreal_simulator_$TIMESTAMP/"

# Symlink the latest build
cd "$PROJECT_DIR/opt/"
ln -sf anm_unreal_simulator_$TIMESTAMP anm_unreal_simulator

echo "anm_unreal_simulator has been successfully packaged to $PROJECT_DIR/opt/"

if [ "$ARG_ZIP" == "true" ]; then
    cd "$PROJECT_DIR/"
    zip --symlinks -r anm_unreal_simulator.zip opt/
fi
