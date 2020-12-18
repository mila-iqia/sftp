#!/bin/bash
set -o errexit -o pipefail -o noclobber

function main {
	while [[ $# -gt 0 ]]
	do
		local arg="$1"; shift
		case "${arg}" in
			--username) local USERNAME="$1"; shift ;;
			--ca) local CA="$1"; shift ;;
			--quota) local QUOTA="$1"; shift ;;
			--data-size) local DATA_SIZE="$1"; shift ;;
			--days) local DAYS="$1"; shift ;;
			--dir) local KEY_DIR="$1"; shift ;;
			--users-file) local USERS_FILE="$1"; shift ;;
			--) break ;;
			-h | --help | *)
			if [[ "${arg}" != "-h" ]] && [[ "${arg}" != "--help" ]]
			then
				>&2 echo "Unknown option [${arg}]"
			fi
			>&2 echo "Options for $(basename "$0") are:"
			>&2 echo "--username USERNAME user for which a temporary access is to be granted"
			>&2 echo "--ca CERTIFICATE_AUTHORITY CA to use. It will be generated if not found"
			>&2 echo "--quota QUOTA user quota. Used with --data-size to compute the duration \
of the granted access"
			>&2 echo "--data-size SIZE total size of the data to be transfered. Used with \
--data-size to compute the duration of the granted access"
			>&2 echo "[--days DAYS] forces the number of days of granted access (optional)"
			>&2 echo "[--dir KEY_DIR] directory to use to generate the SSH key file. If not \
specified, the default location will be used (optional)"
			>&2 echo "[--users-files FILE] file to append the user if it is not already \
included (optional)"
			exit 1
			;;
		esac
	done

	if [[ -z ${USERNAME} ]] || [[ -z ${DAYS} && -z ${QUOTA} && -z ${DATA_SIZE} ]] || [[ -z ${CA} ]]
	then
		>&2 echo "--username USERNAME user for which a temporary access is to be granted"
		>&2 echo "--ca CERTIFICATE_AUTHORITY CA to use. It will be generated if not found"
		>&2 echo "--quota QUOTA user quota. Used with --data-size to compute the duration \
of the granted access"
		>&2 echo "--data-size SIZE total size of the data to be transfered. Used with \
--data-size to compute the duration of the granted access"
		>&2 echo "[--days DAYS] forces the number of days of granted access (optional)"
		>&2 echo "[--dir KEY_DIR] directory to use to generate the SSH key file. If not \
specified, the default location will be used (optional)"
		>&2 echo "[--users-files FILE] file to append the user if it is not already \
included (optional)"
		>&2 echo "Missing --username, --quota, --data-size and/or --ca options"
		exit 1
	fi

	if [[ -z ${DAYS} ]]
	then
		DAYS=$((${DATA_SIZE} / ${QUOTA}))
		DAYS=$(((${DAYS} * 2) / 7 + 1))
		DAYS=$((${DAYS} * 7))
	fi

	if [[ ${DAYS} -lt 1 ]]
	then
		DAYS=1
	fi

	if [[ ! -f ${CA} ]]
	then
		mkdir -p `dirname "${CA}"`
		ssh-keygen -b 4096 -f "${CA}" -P ""
	fi

	if [[ -z ${KEY_DIR} ]]
	then
		local KEY_DIR="~/.ssh"
	fi

	mkdir -p "${KEY_DIR}"
	local KEY_FILE="${KEY_DIR}/${USERNAME}__id_ed25519"
	if [[ -f ${KEY_FILE} && ! -f ${KEY_FILE}.pub ]]
	then
		ssh-keygen -y -f "${KEY_FILE}" > "${KEY_FILE}.pub"
	fi
	if [[ ! -f ${KEY_FILE} && ! -f ${KEY_FILE}.pub  ]]
	then
		ssh-keygen -t ed25519 -f "${KEY_FILE}" -P ""
	fi
	if [[ -f ${KEY_FILE} ]]
	then
		echo "It is not recommended to have the private key generated here \
as it then requires to send it to the user. If possible, the user should only send \
it's public here for it to be signed then sent back."
	fi

	umask 077
	ssh-keygen -s "${CA}" -I "${USERNAME}" -n "${USERNAME}" -V +${DAYS}d "${KEY_FILE}.pub"
	# Verify the expiry date and other details of the signed key with
	# `ssh-keygen -L -f ${KEY_FILE}-cert.pub`

	umask 000
	if [[ ! -z ${USERS_FILE} ]] && [[ -z "`grep "^${USERNAME}:" "${USERS_FILE}"`" ]]
	then
		mkdir -p `dirname "${USERS_FILE}"`
		echo "${USERNAME}::::" >> "${USERS_FILE}"
		echo "Appended \`${USERNAME}::::\` to ${USERS_FILE}"
	fi
}

main "$@"
