#!/bin/bash

# 启用错误退出选项
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
     # 参数检查
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

    # 检查颜色是否有效
    if [[ -z "${colors[$color_name]}" ]]; then
        echo "Invalid color: $color_name"
        return 1
    fi

    # 如果只有text_part1，则直接输出
    if [ -z "$text_part2" ]; then
        echo -e "${spaces}${icons[$icon]} ${colors[$color_name]}$text_part1${colors[reset]}"
        return 0
    fi

    # 检查强调色是否有效
    if [[ -n "$highlight_color_name" && -z "${colors[$highlight_color_name]}" ]]; then
        echo "Invalid highlight color: $highlight_color_name"
        return 1
    fi

    # 找到text_part1中与text_part2重合的部分
    local overlap=$(echo "$text_part1" | grep -o "$text_part2")

    # 如果没有重合部分，则直接输出text_part1
    if [ -z "$overlap" ]; then
        echo -e "${spaces}${icons[$icon]} ${colors[$color_name]}$text_part1${colors[reset]}"
        return 0
    fi

    # 替换重合部分为带强调色的文本
    local highlighted_text=$(echo "$text_part1" | sed "s/$text_part2/\\${colors[$highlight_color_name]}${text_part2}\\${colors[$color_name]}/g")

    # 输出格式化的文本
    echo -e "${spaces}${colors[$color_name]}${icons[$icon]} $highlighted_text${colors[reset]}"
}

# 定义检查命令是否存在的函数
check_command_existence() {
    command -v "$1" > /dev/null 2>&1
    return $?
}

# 设置hosts
update_hosts() {
    # 定义开始和结束标记
    start_marker="# GitHub520 Host Start"
    end_marker="# GitHub520 Host End"
    # 创建临时文件
    temp_file=$(mktemp)

    echo "Updating hosts file."
    # 查找并删除从开始标记到结束标记之间的内容，并保存到临时文件
    sudo awk "NR==1 {print; next} /$start_marker/ {skip=1; next} /$end_marker/ {skip=0; next} !skip" /etc/hosts > "$temp_file" && sudo mv "$temp_file" /etc/hosts
    # 执行提供的sed命令和curl更新操作
    sudo sh -c 'sed -i.bak "/# GitHub520 Host Start/d" /etc/hosts && curl https://raw.hellogithub.com/hosts >> /etc/hosts'
    echo "Hosts file updated successfully."
}

# 定义 disable_selinux 函数
disable_selinux() {
    if ! check_command_existence "getenforce"; then
	    echo "getenforce is not exist, skip disable_selinux"
		return 0
	fi
    # 检查 SELinux 当前状态
    current_status=$(getenforce)
    
    if [[ "$current_status" == "Disabled" || "$current_status" == "Permissive" ]]; then
        echo "SELinux is already disabled or in permissive mode."
    else
        echo "SELinux is enabled. Proceeding to disable it."
        # 临时关闭 SELinux (设置为 Permissive)
        sudo setenforce 0
        # 备份原始配置文件
        sudo cp /etc/selinux/config /etc/selinux/config.bak
        # 修改 SELinux 配置文件，设置 SELINUX=disabled
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
  # 初始化
  #. ~/.nix-profile/etc/profile.d/nix.sh
  source /etc/profile

  # 更换Nix源
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
    local repo_url="https://github.com/smashell/nix-dev.git"
    #local repo_url="git@github.com:smashell/nix-dev.git"

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


# 调用 disable_selinux 函数
update_hosts
disable_selinux
install_nix
#clone_nix_dev_repo
show_tips
