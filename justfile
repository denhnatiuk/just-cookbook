#!/usr/bin/env just --justfile

set shell := ["zsh", "-cu"] 
# set tempdir := ".temporary"
set dotenv-load 
set positional-arguments 

TIMESTAMP := `date +"%T"`
DATE := `date +%Y-%m-%d`

@_default: 
  just find_receipes

# find receipe files in project by shebang
find_receipes:
  #!/usr/bin/bash
  shebang="#!/usr/bin/env just --justfile"
  [ -z $PRJ_ROOT ] && just _check_env_variables
  find "$PRJ_ROOT" -type f -print0 | while IFS= read -r -d '' file; do
    # Check if the first line of the file matches the shebang
    if [[ $(head -n 1 "$file" 2>/dev/null | tr -d '\0') == "$shebang" ]]; then
      echo $(basename "$file")
      
      just --justfile $file --list --unsorted --list-heading '' --list-prefix '    '
    fi
  done

_check_env_variables:
  #!/usr/bin/bash
  [ -z $PRJ_NAME ] && just --justfile {{justfile_directory()}}/dotenv update PRJ_NAME "`node -p "require('./package.json').name"`" project
  [ -z $PRJ_VERSION ] && just --justfile {{justfile_directory()}}/dotenv update PRJ_VERSION "`node -p "require('./package.json').version"`" project
  [ -z $PRJ_ROOT ] && just --justfile {{justfile_directory()}}/dotenv update PRJ_ROOT "`git rev-parse --show-toplevel`" project
  if [ -z $PRJ_TYPE ]; then
    echo "Please enter project type:"
    read type
    just --justfile {{justfile_directory()}}/dotenv update PRJ_TYPE "$type" project
  fi

# Add recipe into shell aliases | alias receipe justfile
@alias *args="":
  alias $1="just --justfile $2 $1"

# Add aliases for all receipes in justfile
@alias_justfile +FILE:
  #!/usr/bin/bash
  for recipe in `just --justfile {{FILE}} --summary`; do
    alias $recipe="just --justfile {{FILE}} --working-directory . $recipe"
  done

# Remove aliases for all receipes in justfile
@remove_receipes-shell-alias +FILE:
  #!/usr/bin/bash
  for recipe in `just --justfile {{FILE}} --summary`; do
    unalias $recipe
  done

# Update version using node: npm version <update_type> : major.minor.patch
@increment_version +type:
  npm version {{type}}
  just --justfile {{justfile_directory()}}/dotenv update PRJ_VERSION "`node -p "require('./package.json').version"`" project

# Set project version manually
@set_version +new_version:
  #!/usr/bin/bash
  [ -z $PRJ_VERSION ] && just _check_env_variables
  jq '. |= . + { "version": "{{new_version}}" }' package.json > package.json.tmp
  mv package.json.tmp package.json
  just --justfile {{justfile_directory()}}/dotenv update PRJ_VERSION {{new_version}} project
  echo "version updated to {{new_version}}"

@changelog +MSG:
  mkdir -p "$PRJ_ROOT/docs" && touch "$PRJ_ROOT/docs/changelog.txt" && echo -e "\n{{DATE}}\n$PRJ_VERSION - {{MSG}}" >> "$PWD/docs/changelog.txt"
