# ubi-hive

2021-12-14 update: The image here was converted to a standalone metastore with the postgres jdbc interface. The new standalone images will include `metastore` in their tag name.

Docker Image build of Hive from RHEL UBI base image. This includes mysql, postgresql jdbc interfaces.

# Workflow

## Basic workflow

1. Branch from `main`
2. Make changes
3. Increment build number file value
4. Commit and Push
5. Create PR merging into `main`
6. Get reviewed and approved

## Build new version of Hive

1. Check available releases [here](https://downloads.apache.org/hive/). If current version is desired version, then stop unless you need a different hadoop image tag.
2. Checkout `main` and pull
3. Update `Dockerfile` : `ENV METASTORE_VERSION` setting it to the version required.
5. Execute `get_metastore_version.sh` to make sure that the output matches the new hive version.
6. Increment the value in `image_build_num.txt` using the `make bump-image-tag` command.
7. Run a test build by executing `pr_check.sh`.
8. If successful, remove `LABEL quay.expires-after=3d` from `Dockerfile` then commit changes and push branch.
9. Create a PR, this should execute a PR check script.
10. If successful, get approval and merge.

# Utility Scripts

* `get_metastore_version.sh` : Get the current hive standalone-metastore version from the `Dockerfile`.
* `get_image_tag.sh` : Return the image tag made from the metastore version and the build number from `image_build_num.txt`
* `docker-build-dev.sh` : Executes a local test build of the docker image.

# Integration Scripts

* `pr_check.sh` : PR check script (You should not need to modify this)
* `build_deploy.sh` : Build and deploy to Red Hat cloudservices quay org. (You should not need to modify this script)

# Usage

This image supports [arbitrary user ids](https://docs.openshift.com/container-platform/4.7/openshift_images/create-images.html#use-uid_create-images)
by using the packaged `/entrypoint.sh` as container command to add UID and
username.

**Notice**: the default username is `hadoop`, customize it by providing an
environment variable named `USER_NAME`.