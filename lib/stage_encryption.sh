#!/bin/bash

cryptsetup luksFormat "${ROOT_PART}"
cryptsetup open "${ROOT_PART}" "${LUKS_NAME}"
