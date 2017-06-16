#!/bin/bash

ANDOCK_CI_VERSION=0.0.3

REQUIREMENTS_ANDOCK_CI_BUILD='0.0.1'
REQUIREMENTS_ANDOCK_CI_TAG='0.0.1'
REQUIREMENTS_ANDOCK_CI_FIN='0.0.2'


ANDOCK_CI_PATH="/usr/local/bin/acp"
ANDOCK_CI_PATH_UPDATED="/usr/local/bin/acp.updated"
ANDOCK_CI_INVENTORY="~/.andock-ci/hosts"

URL_REPO="https://raw.githubusercontent.com/andock-ci/pipeline"
URL_ANDOCK_CI="${URL_REPO}/master/bin/acp"


export ANSIBLE_ROLES_PATH="~/.andock-ci/roles"
export ANSIBLE_HOST_KEY_CHECKING=False

# @author Leonid Makarov
# Console colors
red='\033[0;91m'
red_bg='\033[101m'
green='\033[0;32m'
green_bg='\033[42m'
yellow='\033[1;33m'
NC='\033[0m'

#------------------------------ Help functions --------------------------------

# Yes/no confirmation dialog with an optional message
# @param $1 confirmation message
# @author Leonid Makarov
_confirm ()
{
  # Skip checks if not running interactively (not a tty or not on Windows)
  while true; do
    read -p "$1 [y/n]: " answer
       case "$answer" in
       [Yy]|[Yy][Ee][Ss] )
       break
    ;;
    [Nn]|[Nn][Oo] )
   exit 1
;;
* )
echo 'Please answer yes or no.'
esac
done
}

# Nicely prints command help
# @param $1 command name
# @param $2 description
# @param $3 [optional] command color
# @author Oleksii Chekulaiev
printh ()
{
  local COMMAND_COLUMN_WIDTH=25;
  case "$3" in
  yellow)
    printf "  ${yellow}%-${COMMAND_COLUMN_WIDTH}s${NC}" "$1"
    echo -e "  $2"
  ;;
  green)
    printf "  ${green}%-${COMMAND_COLUMN_WIDTH}s${NC}" "$1"
    echo -e "  $2"
  ;;
  *)
    printf "  %-${COMMAND_COLUMN_WIDTH}s" "$1"
    echo -e "  $2"
  ;;
esac

}

# @author Leonid Makarov
echo-red () { echo -e "${red}$1${NC}"; }
echo-green () { echo -e "${green}$1${NC}"; }
echo-green-bg () { echo -e "${green_bg}$1${NC}"; }
echo-yellow () { echo -e "${yellow}$1${NC}"; }
echo-error () {
	echo -e "${red_bg} ERROR: ${NC} ${red}$1${NC}";
	local unused="$2$3" # avoid IDE warning
	shift
	# Echo other parameters indented. Can be used for error description or suggestions.
	while [[ "$1" != "" ]]; do
		echo -e "         $1";
		shift
	done
}

# rewrite previous line
echo-rewrite ()
{
	echo -en "\033[1A"
	echo -e "\033[0K\r""$1"
}
echo-rewrite-ok ()
{
	echo-rewrite "$1 ${green}[OK]${NC}"
}


# Like if_failed but with more strict error
# @author Leonid Makarov
if_failed_error ()
{
  if [ ! $? -eq 0 ]; then
    echo-error "$@"
    exit 1
  fi
}

# Yes/no confirmation dialog with an optional message
# @param $1 confirmation message
_ask ()
{
	# Skip checks if not running interactively (not a tty or not on Windows)
	read -p "$1 : " answer
	echo $answer
}


#------------------------------ SETUP --------------------------------

# Installs ansible galaxy roles
install_pipeline()
{
  export ANSIBLE_RETRY_FILES_ENABLED="False"

  echo-green ""
  echo-green "Install andock-ci version: ${ANDOCK_CI_VERSION} ..."
  echo-green ""
  echo-green "Install roles:"
  ansible-galaxy install andock-ci.build,v${REQUIREMENTS_ANDOCK_CI_BUILD} --force
  ansible-galaxy install andock-ci.tag,v${REQUIREMENTS_ANDOCK_CI_TAG} --force
  ansible-galaxy install andock-ci.fin,v${REQUIREMENTS_ANDOCK_CI_FIN} --force
  echo-green ""
}

# Based on docksal update script
# @author Leonid Makarov
self_update()
{
  echo-green "Updating andock_ci..."
  local new_andock_ci
  new_andock_ci=$(curl -kfsSL "$URL_ANDOCK_CI?r=$RANDOM")
  if_failed_error "andock_ci download failed."

# Check if fin update is required and whether it is a major version
  local new_version=$(echo "$new_andock_ci" | grep "^ANDOCK_CI_VERSION=" | cut -f 2 -d "=")
  if [[ "$new_version" != "$ANDOCK_CI_VERSION" ]]; then
    local current_major_version=$(echo "$ANDOCK_CI_VERSION" | cut -d "." -f 1)
    local new_major_version=$(echo "$new_version" | cut -d "." -f 1)
    if [[ "$current_major_version" != "$new_major_version" ]]; then
      echo -e "${red_bg} WARNING ${NC} ${red}Non-backwards compatible version update${NC}"
      echo -e "Updating from ${yellow}$ANDOCK_CI_VERSION${NC} to ${yellow}$new_version${NC} is not backward compatible."
      _confirm "Continue with the update?"
    fi

    # saving to file
    echo "$new_andock_ci" | sudo tee "$ANDOCK_CI_PATH_UPDATED" > /dev/null
    if_failed_error "Could not write $ANDOCK_CI_PATH_UPDATED"
    sudo chmod +x "$ANDOCK_CI_PATH_UPDATED"
    echo-green "andock-ci $new_version downloaded..."

  # overwrite old fin
    sudo mv "$ANDOCK_CI_PATH_UPDATED" "$ANDOCK_CI_PATH"
    install
    exit
  else
    echo-rewrite "Updating andock-ci... $ANDOCK_CI_VERSION ${green}[OK]${NC}"
  fi
}


#------------------------------ HELP --------------------------------
show_help ()
{
    printh "Andock-ci Pipeline command reference" "${ANDOCK_CI_VERSION}" "green"

	echo
	printh "build/tag" "Project build management on ansible host \"andock-ci-build-server\"" "yellow"
    printh "build" "Build project on ansible host andock-ci-build-server and commit it to branch-build on target git repository"
    printh "tag" "Create git tags on both source repository and target repository"
    echo

	printh "fin <command>" "Docksal instance management on ansible host \"andock-ci-fin-server\"" "yellow"
	printh "fin up"  "Clone target git repository and start project services for your builded branch"
	printh "fin update"  "Update target git repository and project services "
	printh "fin test"  "Run tests on target project services"
	printh "fin stop" "Stop project services"
	printh "fin rm" "Remove cloned repository and project services"
	echo
	echo
	printh "version (v, -v)" "Print andock-ci version. [v, -v] - prints short version"
	echo
    printh "self-update" "${yellow}Update andock-ci${NC}" "yellow"
}
# Display fin version
# @option --short - Display only the version number
version ()
{
	if [[ $1 == '--short' ]]; then
		echo "$ANDOCK_CI_VERSION"
	else
		echo "andock-ci pipeline (acp) version: $ANDOCK_CI_VERSION"
		echo "Roles:"
		echo "andock-ci.build: $REQUIREMENTS_ANDOCK_CI_BUILD"
		echo "andock-ci.fin: $REQUIREMENTS_ANDOCK_CI_FIN"
		echo "andock-ci.tag: $REQUIREMENTS_ANDOCK_CI_FIN"
	fi

}

#----------------------- ENVIRONMENT HELPER FUNCTIONS ------------------------

# Returns the path of andock-ci.yml file
get_settings_path ()
{
	echo "$PWD/.andock-ci/andock-ci.yml"
}

# Returns the git branch name
# of the current working directory
get_current_branch ()
{
if [ "${TRAVIS}" = "true" ]; then
  echo $TRAVIS_BRANCH
else
  branch_name="$(git symbolic-ref HEAD 2>/dev/null)" ||
  branch_name="(unnamed branch)"     # detached HEAD
  branch_name=${branch_name##refs/heads/}
  echo $branch_name
fi
}

#----------------------- ANSIBLE PLAYBOOK WRAPPERS ------------------------

# Connect to andock-ci server
run_connect ()
{
  if [ "$1" = "" ]; then
    local host=$(_ask "Specify andock-ci server host name or ip?")
  else
    local host=$1
    shift
  fi

  echo "
[andock-ci-build-server]
localhost   ansible_connection=local

[andock-ci-fin-server]
$host
ansible_ssh_user=andock-ci
" > /tmp/hosts

}

# Ansible playbook wrapper to execute andock-ci.build role
run_build ()
{
  local settings_path=$(get_settings_path)
  local branch_name=$(get_current_branch)

  local skip_tags=""
  if [ "${TRAVIS}" = "true" ]; then
    skip_tags="--skip-tags=\"setup,checkout\""
  else
    printh "Starting build for branch <${branch_name}>..." "" "green"
  fi

  ansible-playbook -i $ANDOCK_CI_INVENTORY -e "@${settings_path}" -e "project_path=$PWD build_path=$PWD branch=$branch_name" $skip_tags "$@" /dev/stdin <<END
---
- hosts: andock-ci-build-server
  roles:
    - { role: andock-ci.build }

END

}


# Ansible playbook wrapper to execute andock-ci.tag role
run_tag ()
{
local settings_path=$(get_settings_path)
local branch_name=$(get_current_branch)
ansible-playbook -i $ANDOCK_CI_INVENTORY -e "@${settings_path}" -e "build_path=${PWD}/.andock-ci/tag_source branch=${branch_name}" "$@" /dev/stdin <<END
---
- hosts: andock-ci-build-server
  roles:
    - { role: andock-ci.tag, git_repository_path: "{{ git_source_repository_path }}" }

END

ansible-playbook -i $ANDOCK_CI_INVENTORY -e "@${settings_path}" -e "build_path=${PWD}/.andock-ci/tag_target branch=${branch_name}-build" "$@" /dev/stdin <<END
---
- hosts: andock-ci-build-server
  roles:
    - { role: andock-ci.tag, git_repository_path: "{{ git_target_repository_path }}" }

END
}


# Ansible playbook wrapper to execute andock-ci.fin role
run_fin ()
{
local settings_path=$(get_settings_path)
local branch_name=$(get_current_branch)
local tag=$1

case $tag in
init|update|test|rm)
echo starting
;;
*)
echo-yellow "Unknown tag '$tag'. See 'acp help' for list of available commands" && \
exit 1
;;
esac

shift
ansible-playbook -i $ANDOCK_CI_INVENTORY --tags $tag -e "@${settings_path}" -e "project_path=$PWD branch=${branch_name}" "$@" /dev/stdin <<END
---
- hosts: andock-ci-fin-server
  gather_facts: no
  roles:
    - { role: andock-ci.fin, git_repository_path: "{{ git_target_repository_path }}" }

END

}




#----------------------------------- MAIN -------------------------------------

case "$1" in
  _install-pipeline)
    shift
    install_pipeline "$@"
  ;;

  self-update)
    shift
    shift
    self_update "$@"
  ;;
   connect)
	shift
	run_connect "$@"
  ;;
   build)
	shift
	run_build "$@"
  ;;
  tag)
    shift
	run_tag "$@"
  ;;
  fin)
	shift
	run_fin "$@"
  ;;
  help|"")
	shift
    show_help
  ;;
  -v | v)
    version --short
  ;;
    version)
	version
  ;;
	*)
		[ ! -f "$command_script" ] && \
			echo-yellow "Unknown command '$*'. See 'acp help' for list of available commands" && \
			exit 1
		shift
		exec "$command_script" "$@"
esac
