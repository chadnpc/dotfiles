#! /bin/bash
set -eu

# Arch Linux (post-)install scripts
# Copyright (C) 2020
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.


#
# Check that all the packages in ../packages actually exist.
#

PKGDIR=../packages
MISSING=false

for FILE in "${PKGDIR}"/*; do
  basename "${FILE}"

  # Skip the wine list if multilib is not enabled.
  if [[ "${FILE}" = "../packages/wine.list" ]]; then
    if ! pacman -Sl multilib >/dev/null 2>&1; then
      echo "[multilib] not enabled. Skipping."
      echo
      continue
    fi
  fi

  while read -r PACKAGE; do
    if pacman -Ss ^"${PACKAGE//+/\\\+}"$ >/dev/null; then
      echo -e "\033[1;35m✓\033[0m" "${PACKAGE}"
    else
      MISSING=true
      echo -e "\033[1;31m✗ ${PACKAGE}\033[m"
    fi
  done < "${FILE}"

  echo
done

if ${MISSING}; then
  exit 1
fi
