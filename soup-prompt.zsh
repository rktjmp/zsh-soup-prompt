#
# A delicious bisque.
#
# Authors:
#   Soup
# Insperation:
#   Pure sindresorhus/pure
#   Jack Chen <chendo@gmail.com>
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

#
# Apparently this is the fastest way to find out of our working
# dir is dirty. vcs_info doesn't give enough information.
#
# via pure
function prompt_soup_git_dirty() {
  # use cd -q to avoid side effects of changing directory, e.g. chpwd hooks
	cd -q "$*"

  test -z "$(command git rev-parse -q --show-toplevel 2> /dev/null)"
  if (($? == 1)); then
    # we are in a git dir, run the dirty check
    test -z "$(command git status --porcelain --ignore-submodules -unormal)"
  fi

  (( $? )) && echo "*"
}

#
# From pure prompt
#
function  prompt_soup_human_time() {
	local tmp=$1
	local days=$(( tmp / 60 / 60 / 24 ))
	local hours=$(( tmp / 60 / 60 % 24 ))
	local minutes=$(( tmp / 60 % 60 ))
	local seconds=$(( tmp % 60 ))
	(( $days > 0 )) && echo -n "${days}d "
	(( $hours > 0 )) && echo -n "${hours}h "
	(( $minutes > 0 )) && echo -n "${minutes}m "
	echo "${seconds}s"
}

#
# Normally the first two-three chars of a folder is enough with context
# to know where we are. This keeps our prompt short.
#
# We will show git-repo names in full and underlined, just for fun.
#
function prompt_soup_pwd() {
  # Get repo root dir name if its present in our path
  local repo="${$(git rev-parse -q --show-toplevel 2> /dev/null):t}"
  n=1 # n = number of directories to show in full (n = 3, /u/b/c/dfull/efull/ffull)
  pwd=${${PWD}/#${HOME}/\~}

  # split our path on /
  dirs=("${(s:/:)pwd}")
  dirs_length=$#dirs

  if [[ $dirs_length -ge $n ]]; then
    # we have more dirs than we want to show in full, so compact those down
    ((max=dirs_length - n))
    for (( i = 1; i <= $max; i++ )); do
      local step="$dirs[$i]"
      if [[ -z $step ]]; then
        continue
      fi
      if [[ "$step" == "$repo" ]]; then
        # don't contract our repo dir
        dirs[$i]=$step
      else
        if [[ $step =~ "^\." ]]; then
          dirs[$i]=$step[0,3] #make .mydir => .my
        else
          dirs[$i]=$step[0,2] # make mydir => my
        fi
      fi
    done
  fi

  # underline our git repo root dir if present
  for (( i = 1; i <= $dirs_length; i++ )); do
    local step="$dirs[$i]"
    if [[ "$step" == "$repo" ]]; then
      # underline seems to stop path color
      dirs[$i]="%F{cyan}%U$step%u%F{cyan}"
    fi
  done

  _prompt_soup_pwd="%F{cyan}${(j:/:)dirs}%{$reset_color%}"
}

function prompt_soup_precmd() {
  # Save option state
  # Any options will be reverted when this function ends.
  setopt LOCAL_OPTIONS

  local is_dirty=$(prompt_soup_git_dirty)
  if test -z "$is_dirty"; then
    zstyle ':vcs_info:git*' formats '%F{white}%b %F{green}✔%f'
    zstyle ':vcs_info:git*' actionformats '%F{white}%b|%a %F{green}✔%f'
  else
    zstyle ':vcs_info:git*' formats '%F{white}%b %F{red}⚡%f'
    zstyle ':vcs_info:git*' actionformats '%F{white}%b|%a %F{red}⚡%f'
  fi

  # note: set format per dirty repo status, then get vcs info
  vcs_info

  # set pwd variable
  prompt_soup_pwd

  if [ $_prompt_soup_timer_start ]; then
    local stop=$SECONDS
    local start=$_prompt_soup_timer_start
    local elapsed
    ((elapsed = $stop - $start))
    if (($elapsed > 5)); then
      local human_timer
      human_timer=$(prompt_soup_human_time $elapsed)
      _prompt_soup_execute_time="%F{white}◷ $human_timer%f
"
    else
      _prompt_soup_execute_time=""
    fi
    unset _prompt_soup_timer_start
	else
		_prompt_soup_execute_time=""
  fi
}
function prompt_soup_preexec(){
  _prompt_soup_timer_start=${_prompt_soup_timer_start:-$SECONDS}
}

function prompt_soup_setup() {
  setopt LOCAL_OPTIONS
  setopt prompt_subst

  zmodload zsh/datetime
	autoload -Uz add-zsh-hook
	autoload -Uz vcs_info
	# autoload -Uz async && async

	add-zsh-hook precmd prompt_soup_precmd
	add-zsh-hook preexec prompt_soup_preexec

	zstyle ':vcs_info:*' enable git
  # zstyle ':vcs_info:*+*:*' debug true
	zstyle ':vcs_info:*' use-simple true
  zstyle ':vcs_info:*' check-for-changes true
  # vcs_info formats are set in precmd after checking dirty status

	# show username@host if logged in through SSH
  _prompt_soup_username=''
	[[ "$SSH_CONNECTION" != '' ]] && _prompt_soup_username='%F{242}%n@%m%f '

	# show username@host if root, with username in white
	[[ $UID -eq 0 ]] && _prompt_soup_username=' %F{white}%n%f%F{242}@%m%f '

	# prompt turns red if the previous command didn't exit with 0
  # λ ∆ △ ▶
	PROMPT='
${_prompt_soup_execute_time}${_prompt_soup_username}${_prompt_soup_pwd} ${vcs_info_msg_0_}
%(?.%F{magenta}.%F{red})λ%f%{$reset_color%} '
  PS2="       ... "
  SPROMPT='zsh: correct %F{red}%R%f to %F{green}%r%f [nyae]? '
}

# auto call our setup method after file load.
prompt_soup_setup "$@"
