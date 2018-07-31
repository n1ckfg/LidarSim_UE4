#!/bin/bash

PROJECT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SUBMODULES_DIR="$( dirname "$PROJECT_DIR" )"
#UE_DIR=$SUBMODULES_DIR"/UnrealEngine"
UE_DIR="$HOME/UnrealEngine"

PROJECT=$(basename "$PROJECT_DIR")

$UE_DIR"/Engine/Build/BatchFiles/Linux/Build.sh" \
"$PROJECT" Development Linux \
-project=\""$PROJECT_DIR"/"$PROJECT".uproject\" \
-progress -editorrecompile -NoHotReloadFromIDE
