#!/bin/zsh

# Ensure a variable is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <name> [<feature>]"
  exit 1
fi

# Assign the provided variable, lowercase it. get rid of everything if URL
domain=$(echo "${(L)1}" | sed -E 's|https://([^.]+).*|\1|')
name=$(echo "$domain" | sed -E 's/(.*)--/\1/') # foo--bar -> foo

# Check if a second argument is provided for module name
if [ -n "$2" ]; then
  feature="$2"
else
  feature="{$name}-module"
fi

# Get the script's root directory
root_dir="$(cd "$(dirname "$0")" && pwd)"

# Get the script's name
script_name="$(basename "$0")"

# Rename project .iml
mv "${root_dir}/.idea/sf-template.iml" "${root_dir}/.idea/${name}.iml"

# Recursively replace all mentions of "sf-template" with the variable
find "${root_dir}" -type d -name '.git' -prune -o  -type f -not -name "${script_name}" -exec sed -i '' -e "s/sf-template/${name}/g" {} \;
find "${root_dir}" -type d -name '.git' -prune -o  -type f -not -name "${script_name}" -exec sed -i '' -e "s/sf_template/${name//-/_}/g" {} \;

# Create the module directory
mkdir "src/main/${feature}"

# Report the changes
echo "Project renamed to ${name}, created ${feature}"

# Remove the script and commit changes
rm -f "${script_name}"

git add -A
git commit -m "Init ${name}"
git push

echo "Org Authentication..."

url="https://"
alias="${domain//--/-}"

if [[ $domain =~ '--' ]]; then
  # sf org login web --instance-url https://foo--bar.sandbox.my.salesforce.com --alias foo-bar --set-default
  url+="$domain.sandbox"
elif [[ $domain =~ 'dev-ed' ]]; then
  # sf org login web --instance-url https://foo-dev-ed.develop.my.salesforce.com --alias foo-dev-ed --set-default
else
  # sf org login web --instance-url https://foo.my.salesforce.com --alias foo-prod --set-default
  url+="$domain"
  alias="${domain}-prod"
fi

sf org login web --instance-url $url.my.salesforce.com --alias $alias --set-default