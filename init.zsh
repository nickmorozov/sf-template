#!/bin/zsh

# Ensure a variable is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <project-name> [<module-name>]"
  exit 1
fi

# Assign the provided variable, lowercase it
replacement="${(L)1}"

# Check if a second argument is provided for module name
if [ -n "$2" ]; then
  module_name="$2"
else
  module_name="{$replacement}-module"
fi

# Get the script's root directory
root_dir="$(cd "$(dirname "$0")" && pwd)"

# Get the script's name
script_name="$(basename "$0")"

# Rename project .iml
mv "${root_dir}/.idea/sf-template.iml" "${root_dir}/.idea/${replacement}.iml"

# Recursively replace all mentions of "sf-template" with the variable
find "${root_dir}" -type d -name '.git' -prune -o  -type f -not -name "${script_name}" -exec sed -i '' -e "s/sf-template/${replacement}/g" {} \;
find "${root_dir}" -type d -name '.git' -prune -o  -type f -not -name "${script_name}" -exec sed -i '' -e "s/sf_template/${replacement//-/_}/g" {} \;

# Create the module directory
mkdir "src/main/${module_name}"

# Report the changes
echo "Project renamed to ${replacement}, module created as ${module_name}"

# Remove the script and commit changes
rm -f "${script_name}"

git add -A
git commit -m "Init ${replacement}"
git push
