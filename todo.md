add .session to .claude on new session start, so that i can resume it on crush

Tip: Use /agents to optimize specific tasks. Eg. Software Architect, Code Writer, Code Reviewer
add script to check if anything should be updated in template based on project files

org-custom-metadata-templates
Specifies either a local directory or a cloned GitHub repository that contains the default custom code templates used by the project generate command. The GitHub URL points to either the root directory that contains your templates or to a subdirectory on a branch in the repo that contains your templates. For example:

sf config set org-custom-metadata-templates https://github.com/mygithubacct/salesforcedx-templates
Environment variable: SF_ORG_CUSTOM_METADATA_TEMPLATES

SF_ORG_CUSTOM_METADATA_TEMPLATES=https://github.com/mygithubacct/salesforcedx-templates

sf config set org-metadata-rest-deploy true --global
sf config set org-capitalize-record-types false --global
sset SF_DISABLE_SOURCE_MEMBER_POLLING to false in cicd
