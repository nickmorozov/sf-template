#!/bin/zsh

# Ensure a variable is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <replacement-text>"
  exit 1
fi

# Assign the provided variable
replacement="$1"

# Create underscore version by replacing dashes with underscores
replacement_underscore="${replacement//-/_}"

# Get the script's root directory
root_dir="$(cd "$(dirname "$0")" && pwd)"

# Get the script's name
script_name="$(basename "$0")"

# Rename project .iml
mv "${root_dir}/.idea/sf-template.iml" "${root_dir}/.idea/${replacement}.iml"

# Recursively replace all mentions of "sf-template" with the variable
find "${root_dir}" -type d -name '.git' -prune -o  -type f -not -name "${script_name}" -exec sed -i '' -e "s/sf-template/${replacement}/g" {} \;
find "${root_dir}" -type d -name '.git' -prune -o  -type f -not -name "${script_name}" -exec sed -i '' -e "s/sf_template/${replacement_underscore}/g" {} \;

echo "Replacement completed."

# Remove the script and commit changes

rm -f "${script_name}"

git add -A

git commit -m "init ${replacement}"

git push
