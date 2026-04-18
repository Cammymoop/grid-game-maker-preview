#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
PROJECT_FILE="${PROJECT_DIR}/project.godot"
BUILD_DIR="${PROJECT_DIR}/build"
EXPORT_LIST="${SCRIPT_DIR}/exports.txt"
GODOT_BIN="godot4.6"

echo "Running godot version: "
"$GODOT_BIN" --version

if [[ ! -f "${PROJECT_FILE}" ]]; then
  echo "Error: project.godot not found at ${PROJECT_FILE}" >&2
  exit 1
fi

if [[ ! -f "${EXPORT_LIST}" ]]; then
  echo "Error: export list not found at ${EXPORT_LIST}" >&2
  exit 1
fi

cd "${PROJECT_DIR}"

VERSION="$(
  awk -F'"' '/^config\/version=/ { print $2; exit }' "${PROJECT_FILE}"
)"

if [[ -z "${VERSION}" ]]; then
  echo "Error: could not read config/version from project.godot" >&2
  exit 1
fi

EXPORTED_SUBDIRS=()

# Read export definitions from exports.txt via fd 3.
exec 3<"${EXPORT_LIST}"

while IFS='|' read -r PRESET_NAME OUT_SUBDIR OUT_FILE <&3; do
  if [[ -z "${PRESET_NAME// }" ]]; then
    continue
  fi

  if [[ "${PRESET_NAME}" =~ ^[[:space:]]*# ]]; then
    continue
  fi

  if [[ -z "${OUT_SUBDIR:-}" || -z "${OUT_FILE:-}" ]]; then
    echo "Error: invalid export entry in ${EXPORT_LIST}:" >&2
    echo "  ${PRESET_NAME}|${OUT_SUBDIR:-}|${OUT_FILE:-}" >&2
    exec 3<&-
    exit 1
  fi

  DEST_DIR="${BUILD_DIR}/${OUT_SUBDIR}"
  DEST_PATH="${DEST_DIR}/${OUT_FILE}"

  mkdir -p "${DEST_DIR}"

  echo "Exporting ${PRESET_NAME} -> ${DEST_PATH}"
  "${GODOT_BIN}" --headless --path "${PROJECT_DIR}" \
    --export-release "${PRESET_NAME}" "${DEST_PATH}"

  EXPORTED_SUBDIRS+=("${OUT_SUBDIR}")
done

exec 3<&-

if [[ "${#EXPORTED_SUBDIRS[@]}" -eq 0 ]]; then
  echo "Error: no exports were defined in ${EXPORT_LIST}" >&2
  exit 1
fi

for OUT_SUBDIR in "${EXPORTED_SUBDIRS[@]}"; do
  ZIP_NAME="${OUT_SUBDIR}-v${VERSION}.zip"

  echo "Creating archive ${BUILD_DIR}/${ZIP_NAME}"
  rm -f "${BUILD_DIR:?}/${ZIP_NAME}"
  (
    cd "${BUILD_DIR}"
    zip -r "${ZIP_NAME}" "${OUT_SUBDIR}"
  )
done

echo "Exports and archives completed for version ${VERSION}"

