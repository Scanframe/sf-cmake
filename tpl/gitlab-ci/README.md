# GitLab-CI

## Configuration

### Operate - Environments

Add the environments `staging` and `stable` needed for upcoming variables.  
Allows different variables per environment.

### Settings - Access Tokens

The coverage pipeline can create a merge-request comment message on the generated report.  
To add this comment a token named `Merge Request Comments` with only `api` access is created.  
This token is added as a masked variable `SF_PROJECT_TOKEN`.

### Settings - CI/CD - Variables

Go to **Settings > CI/CD > Variables**
and add this list of variables needed for the pipeline to execute the pipelines.

| Name                | Value                       | Environ | Description                                                            |
|:--------------------|:----------------------------|:--------|:-----------------------------------------------------------------------|
| NEXUS_APT_REPO      | develop                     | default | Nexus apt repository name to upload the packages to.                   |
| NEXUS_APT_REPO      | staging                     | staging | Nexus apt repository name to upload the packages to.                   |
| NEXUS_APT_REPO      | stable                      | stable  | Nexus apt repository name to upload the packages to.                   |
| NEXUS_RAW_REPO      | shared                      | *       | Nexus raw repository name to upload packages to.                       |
| NEXUS_EXCHANGE_REPO | exchange                    | *       | Nexus raw repository for exchange.                                     |
| NEXUS_RAW_SUBDIR    | dist/develop                | default | Nexus raw repository subdirectory to upload packages to.               |
| NEXUS_RAW_SUBDIR    | dist/staging                | staging | Nexus raw repository subdirectory to upload packages to.               |
| NEXUS_RAW_SUBDIR    | dist/stable                 | stable  | Nexus raw repository subdirectory to upload packages to.               |
| NEXUS_SERVER_URL    | https://nexus.scanframe.com | *       | Nexus server base URL containing protocol and hostname only.           |
| NEXUS_USER          | uploader                    | *       | Nexus account username for uploading packages.                         |
| NEXUS_PASSWORD      | &lt;uploader-password&gt;   | *       | Nexus account password for uploading packages.                         |
| SF_PROJECT_TOKEN    | &lt;project-token&gt;       | *       | Project token with access to API.                                      |
| SF_RELEASE_BRANCH   | main                        | *       | Branch to which the deploy stage is executable.                        |
| SF_SIGNAL           | &lt;empty-by-default&gt;    | *       | Signal for testing a pipeline with values 'test', 'deploy' and 'skip'. |

> Make sure the **NEXUS_PASSWORD** and **SF_PROJECT_TOKEN** are masked for security reasons.





