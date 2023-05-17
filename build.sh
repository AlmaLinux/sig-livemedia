#!/bin/bash

declare -gxr default_cachedir="$PWD/pkg-cache-alma"
declare -gxr default_desktop="gnome"
declare -gxr default_size="full"

print_usage() {
	cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS
 -c <dir>       Cache RPM packages in <dir> (default: $default_cachedir)
 -d <desktop>   Desktop environment (one of gnome, kde, xfce; default: $default_desktop)
 -h             Print this text
 -n             Show what would be done (dry run)
 -s <size>      Size of the image (full or mini; default: $default_size)
 -v <ver>       AlmaLinux version to generate live disk for
EOF
}

info() {
	echo "INFO: $*" 1>&2
}

error() {
	echo "ERROR: $*" 1>&2
}

runcmd() {
	local cmd=("$@")

	info "Executing: ${cmd[*]}"

	if (( dryrun )); then
		return 0
	fi

	"${cmd[@]}"
	return "$?"
}

get_script_location() {
	local scriptpath

	if ! scriptpath=$(realpath "${BASH_SOURCE[0]}"); then
		error "Could not determine script location"
		return 1
	fi

	echo "${scriptpath%/*}"
}

regex_validate() {
	local data="$1"
	local regex="$2"

	[[ "$data" =~ $regex ]]
}

get_package_list() {
	local major_version="$1"
	local desktop="$2"
	local suffix="$3"

	local -A map
	local package_list

	map["8-gnome"]="packages-gnome-full.txt"
	map["8-gnome-mini"]="packages-gnome-mini.txt"
	map["9-gnome"]="packages-gnome-full-al9.txt"
	map["9-gnome-mini"]="packages-gnome-al9.txt"

	package_list="${map[$major_version-$desktop$suffix]}"

	if [[ -z "$package_list" ]]; then
		return 1
	fi

	echo "$package_list"
	return 0
}

prepare_package_lists() {
	local major_version="$1"
	local desktop="$2"
	local suffix="$3"

	local loc
	local package_list

	if ! loc=$(get_script_location); then
		return 1
	fi

	package_list=$(get_package_list "$major_version" "$desktop" "$suffix")

	if ! runcmd ln -sf "$loc/kickstarts/repos-${major_version}.txt" "$loc/kickstarts/repos.txt"; then
		error "Could not prepare repository list"
		return 1
	fi

	if package_list=$(get_package_list "$major_version" "$desktop" "$suffix") &&
	   ! runcmd ln -sf "$loc/kickstarts/$package_list" "$loc/kickstarts/packages-$desktop.txt"; then
		error "Could not prepare package list"
		return 1
	fi

	return 0
}

get_kickstart_config() {
	local version="$1"
	local desktop="$2"

	local major_version
	local input_config
	local output_config
	local loc

	if ! loc=$(get_script_location); then
		return 1
	fi

	major_version="${version%%.*}"

	if ! output_config=$(mktemp --suffix=".ks"); then
		error "Could not make temporary file for kickstart configuration"
		return 1
	fi

        input_config="$loc/kickstarts/almalinux-${major_version}-live-${desktop}.ks"

	if ! runcmd ksflatten --config "$input_config" --output "$output_config" 1>&2; then
		error "Could not flatten $input_config"
		rm -f "$output_config"
		return 1
	fi

	echo "$output_config"
	return 0
}

build_liveiso() {
	local version="$1"
	local desktop="$2"
	local variant="$3"
	local cachedir="$4"

	local major_version
	local kickstart_config
	local fs_label
	local title
	local product
	local -i error
	declare -A suffix

	suffix["full"]=""
	suffix["mini"]="-mini"
	major_version="${version%%.*}"

	info "Building $variant AlmaLinux $version LiveDVD with $desktop"
	info "Caching packages in $cachedir"

	if ! prepare_package_lists "$major_version" "$desktop" "${suffix[$variant]}"; then
		return 1
	fi

	if ! kickstart_config=$(get_kickstart_config "$version" "$desktop"); then
		return 1
	fi

	title="AlmaLinux-${major_version}-LiveDVD"
	fs_label="${title}-${desktop^^}"
	product="AlmaLinux Live ${version}"

	runcmd sudo livecd-creator          \
	       --config "$kickstart_config" \
	       --fslabel "$fs_label"        \
	       --title="$title"             \
	       --product="$product"         \
	       --cache="$cachedir"          \
	       --releasever="$version"
	error="$?"

	rm -f "$kickstart_config"
	return "$error"
}

main() {
	local version
	local desktop
	local size
	local cachedir
	local arg
	local OPTARG
	declare -gxi dryrun

	version=""
	desktop="$default_desktop"
        size="$default_size"
	dryrun=0
	cachedir="$default_cachedir"

	while getopts 'v:d:s:c:hn' arg; do
		case "$arg" in
			"v")
				version="$OPTARG"
				;;

			"d")
				desktop="$OPTARG"
				;;

			"s")
				size="$OPTARG"
				;;

			"c")
				if ! cachedir=$(realpath "$OPTARG"); then
					error "Could not get absolute path of $OPTARG"
					return 1
				fi
				;;

			"h")
				print_usage
				return 1
				;;

			"n")
				dryrun=1
				;;

			*)
				print_usage
				return 2
				;;
		esac
	done

	if ! regex_validate "$version" '^[0-9]+\.[0-9]+$'; then
		error "Need a valid version"
		return 1

	elif ! regex_validate "$desktop" '^(gnome|kde|xfce)$'; then
		error "Invalid desktop environment"
		return 1

	elif ! regex_validate "$size" '^(full|mini)$'; then
		error "Invalid image size"
		return 1
	fi

	build_liveiso "$version" "$desktop" "$size" "$cachedir"
	return "$?"
}

{
	main "$@"
	exit "$?"
}
