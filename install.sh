#!/bin/bash

# Enable error exit option
set -e
set -o pipefail

# Define colors
declare -A colors
colors=(
    ["black"]="\e[30m"
    ["red"]="\e[31m"
    ["green"]="\e[32m"
    ["yellow"]="\e[33m"
    ["blue"]="\e[34m"
    ["magenta"]="\e[35m"
    ["cyan"]="\e[36m"
    ["white"]="\e[37m"
    ["reset"]="\e[0m"
)

# Define icons
declare -A icons
icons=(
    ["celebrate"]="\xF0\x9F\x8E\x89"
    ["wrench"]="\xF0\x9F\x94\xA7"
    ["folder"]="\xF0\x9F\x93\x82"
    ["rocket"]="\xF0\x9F\x9A\x80"
)

# Format output
format_output() {
    # Parameter check
    if [ "$#" -lt 3 ] || [ "$#" -gt 6 ]; then
        echo "Usage: format_output <space num> <icon> <color> <text_part1> [<highlight_color> <text_part2>]"
        return 1
    fi

    local spaces=$(printf '%*s' "$1")
    local icon="$2"
    local color_name="$3"
    local text_part1="$4"
    local highlight_color_name="${5:-}"
    local text_part2="${6:-}"

    # Check if the color is valid
    if [[ -z "${colors[$color_name]}" ]]; then
        echo "Invalid color: $color_name"
        return 1
    fi

    # If there's only text_part1, output directly
    if [ -z "$text_part2" ]; then
        echo -e "${spaces}${icons[$icon]} ${colors[$color_name]}$text_part1${colors[reset]}"
        return 0
    fi

    # Check if the highlight color is valid
    if [[ -n "$highlight_color_name" && -z "${colors[$highlight_color_name]}" ]]; then
        echo "Invalid highlight color: $highlight_color_name"
        return 1
    fi

    # Find overlapping part between text_part1 and text_part2
    local overlap=$(echo "$text_part1" | grep -o "$text_part2")

    # If no overlap, output text_part1 directly
    if [ -z "$overlap" ]; then
        echo -e "${spaces}${icons[$icon]} ${colors[$color_name]}$text_part1${colors[reset]}"
        return 0
    fi

    # Replace overlapping part with highlighted text
    local highlighted_text=$(echo "$text_part1" | sed "s/$text_part2/\\${colors[$highlight_color_name]}${text_part2}\\${colors[$color_name]}/g")

    # Output formatted text
    echo -e "${spaces}${colors[$color_name]}${icons[$icon]} $highlighted_text${colors[reset]}"
}

# Define a function to check if a command exists
check_command_existence() {
    command -v "$1" > /dev/null 2>&1
    return $?
}

# Update hosts file
update_hosts() {
    # Define start and end markers
    start_marker="# GitHub520 Host Start"
    end_marker="# GitHub520 Host End"
    # Create a temporary file
    temp_file=$(mktemp)

    echo "Updating hosts file."
    # Find and delete content between start marker and end marker, save to temporary file
    sudo awk "NR==1 {print; next} /$start_marker/ {skip=1; next} /$end_marker/ {skip=0; next} !skip" /etc/hosts > "$temp_file" && sudo mv "$temp_file" /etc/hosts
    # Execute provided sed command and curl update operation
    sudo sh -c 'sed -i.bak "/# GitHub520 Host Start/d" /etc/hosts && curl https://raw.hellogithub.com/hosts >> /etc/hosts'
    echo "Hosts file updated successfully."
}

# Define disable_selinux function
disable_selinux() {
    if ! check_command_existence "getenforce"; then
        echo "getenforce is not exist, skip disable_selinux"
        return 0
    fi
    # Check current SELinux status
    current_status=$(getenforce)
    
    if [[ "$current_status" == "Disabled" || "$current_status" == "Permissive" ]]; then
        echo "SELinux is already disabled or in permissive mode."
    else
        echo "SELinux is enabled. Proceeding to disable it."
        # Temporarily disable SELinux (set to Permissive)
        sudo setenforce 0
        # Backup original configuration file
        sudo cp /etc/selinux/config /etc/selinux/config.bak
        # Modify SELinux configuration file, set SELINUX=disabled
        sudo sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
        echo "SELinux has been set to disabled."
    fi
}

install_nix() {
    if [ -d "/nix" ]; then
        echo "/nix is already exist."
        return 0
    fi
    echo "Installing Nix"
    sh <(curl https://mirrors.tuna.tsinghua.edu.cn/nix/latest/install) --daemon --no-channel-add --yes
    echo "Nix has been installed"
    # Initialize
    #. ~/.nix-profile/etc/profile.d/nix.sh
    source /etc/profile

    # Change Nix sources
    echo "Changing Nix substituters"
    mkdir -p ~/.config/nix
    echo "substituters = https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store https://cache.nixos.org/
    " > ~/.config/nix/nix.conf
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
    sudo bash -c "echo trusted-users = `id -un` >> /etc/nix/nix.conf"

    echo "Restarting Nix daemon"
    sudo systemctl restart nix-daemon.service
    echo "Nix daemon has been restarted"

    nix-channel --add https://mirrors.tuna.tsinghua.edu.cn/nix-channels/nixpkgs-unstable nixpkgs
    nix-channel --update
    echo "Nix substituters has been changed"
}

clone_nix_dev_repo() {
    # Define the target directory and repository URL
    local target_dir="$HOME/.nix-dev-conf"
    #local repo_url="https://github.com/smashell/nix-dev.git"
    local repo_url="git@github.com:smashell/nix-dev.git"

    # Check if the target directory already exists
    if [ -d "$target_dir" ]; then
        echo "Directory $target_dir already exists. Please remove it or choose another location."
        return 0
    fi

    # Clone the repository into the target directory
    git clone --recursive "$repo_url" "$target_dir"
    #cp "$target_dir/config-tmpl.toml" $HOME/.nix-dev-config.toml

    # Check if the cloning was successful
    if [ $? -eq 0 ]; then
        echo "Repository cloned successfully into $target_dir"
    else
        echo "Failed to clone the repository."
        return 1
    fi
}

show_tips() {
    format_output 0 "celebrate" "green" "Please follow these steps:"
    format_output 4 "wrench" "green" "1. According to your actual situation, modify the configuration file: ${HOME}/.nix-dev-config.toml"
    format_output 4 "rocket" "green" "2. cd $HOME/.nix-dev-conf and run command: nix run .#sysdo bootstrap" "red" "nix run .#sysdo bootstrap" 
}

# Call disable_selinux function
#update_hosts
disable_selinux
install_nix
clone_nix_dev_repo
show_tips
