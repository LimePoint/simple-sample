# syntax = docker/dockerfile:1.4

ARG OPSCHAIN_BASE_RUNNER

# The repo (including the .git directory) is extracted into a scratch layer for improved caching.
FROM scratch as repo
ADD ./repo.tar .

# OpsChain Step Runner Docker images must be based on an opschain-runner(-*) base image.
FROM ${OPSCHAIN_BASE_RUNNER}

# Run any Dockerfile commands that don't rely on the contents of the Git repository here to avoid rerunning them when the Git repo changes.

# The step below adds the Project Git repository (including the .git directory).
# Specific files can be copied instead, e.g. `COPY --from=repo /Gemfile* .`, to improve caching and build performance.
COPY --link --from=repo / .

# Optional - the Git rev this change was created with. Useful when running automated changes to know the current branch.
ARG GIT_REV
ENV GIT_REV=$GIT_REV

# The following steps are an internal OpsChain requirement to configure the Git repository. These must be present after adding the repo.tar file.
ARG GIT_SHA
RUN opschain_configure_project_repo.sh "$GIT_SHA"

# Add customer licence to runner
COPY opschain.lic /

# Run any Dockerfile commands that rely on the contents of the Git repository here.

# Run any Dockerfile commands that rely on using `opschain-exec` here. Copy the --mount used in the "opschain-exec bundle install" RUN
# command below if you require access to OpsChain secrets and/or properties environment variables.

# Run `bundle install` to install the Ruby dependencies into the image.
# The use of `opschain-exec` with the env_context_json secret, means that any OpsChain secrets, or properties environment variables
# will be available for Bundler configuration (eg for authentication details).
USER opschain
RUN --mount=type=secret,required=true,id=env_context_json,uid=10001,gid=10001,target=/opt/opschain/.opschain/step_context.json \
    opschain-exec bundle install

# Lint OpsChain files to look for errors before execution, this step is optional
RUN opschain-lint

# Run any Dockerfile commands that rely on using Ruby/Bundler here.
