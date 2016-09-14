#!/usr/bin/env bash

# ------------------------------------------------------
# Usage:
function print_help(){
   echo "Usage: build.sh PATH_TO_SEARCH REGISTRY BASE_NAME BRANCH [DEFAULT_BRANCH=master [TAG_REQUIRED_FOR_BRANCH=false]]"
}

# ------------------------------------------------------
# Defaults:
PATH_TO_SEARCH="../docker-images/"
REGISTRY='master-dr.co'
BASE_NAME="operations/some-thing"
BRANCH="feature"
DEFAULT_BRANCH="master"
TAG_REQUIRED=false
TAG=""
# ------------------------------------------------------
if [ -n "$1" ]; then PATH_TO_SEARCH="$1"; else print_help; exit 1; fi
if [ -n "$2" ]; then REGISTRY="$2"; else print_help; exit 1; fi
if [ -n "$3" ]; then BASE_NAME="$3"; else print_help; exit 1; fi
if [ -n "$4" ]; then BRANCH="$4"; else print_help; exit 1; fi
if [ -n "$5" ]; then DEFAULT_BRANCH="$5"; fi
if [ -n "$6" ]; then TAG_REQUIRED="$6"; fi

# ------------------------------------------------------

BRANCH=`echo $BRANCH | tr '[:upper:]' '[:lower:]'`
PATH_TO_SEARCH=`pwd`"/$PATH_TO_SEARCH"
set -e

# Backup path
BACKUP_PATH=`pwd`
cd $PATH_TO_SEARCH

# Build images
BUILT_IMAGES=()


IFS=$'\n'
for DOCKER_FILE in `find * -regex '.*Dockerfile$'`; do
    MESSAGE="Building container for file $DOCKER_FILE"
    echo "##teamcity[blockOpened name='$MESSAGE']"


        # getting parts of image name
    NAME_PARTS=`echo $DOCKER_FILE | sed -e 's/\/*\.*Dockerfile$//g' -e 's/ /_/g' -e 's/\//,/g' | tr '[:upper:]' '[:lower:]'`

    IFS=',' read -r -a NAME_PARTS_ARRAY <<< "$NAME_PARTS"



    # getting tag if required
    # in case we work in feature branch
    if $TAG_REQUIRED; then

        if  [ "$BRANCH" != "$DEFAULT_BRANCH" ]; then
            TAG=`echo $BRANCH | tr '[:upper:]' '[:lower:]'`
        else
            # PARTS_LEN=${#NAME_PARTS_ARRAY[@]}
            # if (( "$PARTS_LEN" > 0 )); then
            #     TAG=${NAME_PARTS_ARRAY[${#NAME_PARTS_ARRAY[@]} - 1]}
            #     unset NAME_PARTS_ARRAY[$PARTS_LEN-1]
            # fi
            TAG="latest"
        fi       
    else
        if [ "$BRANCH" != "$DEFAULT_BRANCH" ]; then
            NAME_PARTS_ARRAY+=("$BRANCH")
        fi
    fi

    echo "TAG: '$TAG'"

    # getting name
    NAME=$(printf "/%s" "${NAME_PARTS_ARRAY[@]}")
    NAME=${NAME:1}

    if [ "$NAME" != "" ]; then
        NAME="$BASE_NAME/$NAME"
    else
        NAME=$BASE_NAME
    fi
    echo "NAME: '$NAME'"

    #getting full image name
    IMAGE_NAME="$REGISTRY/$NAME"
    
    if [ "$TAG" != "" ]; then
        IMAGE_NAME="$IMAGE_NAME:$TAG"
    fi

    echo "IMAGE_NAME: '$IMAGE_NAME'"


    #Building
    CONTEXT=$(dirname "${DOCKER_FILE}")
    DOCKER_FILE_ABS=`pwd`"/$DOCKER_FILE"
    cd $CONTEXT 
    #echo "---------------Build from context "`pwd`
    docker build --rm=true -t "$IMAGE_NAME" -f "$DOCKER_FILE_ABS" .
    echo "Add image '$IMAGE_NAME' to array for push"

    BUILT_IMAGES+=("$IMAGE_NAME")
    cd $PATH_TO_SEARCH

    echo "##teamcity[blockClosed name='$MESSAGE']"
done

# Unique names for images
eval BUILT_IMAGES=($(printf "%q\n" "${BUILT_IMAGES[@]}" | sort -u))

# Push images
for IMAGE_NAME in ${BUILT_IMAGES[@]}; do
    echo "##teamcity[blockOpened name='Push image $IMAGE_NAME']"
    docker push "$IMAGE_NAME"
    echo "##teamcity[blockClosed name='Push image $IMAGE_NAME']"
done

# Remove local images
for IMAGE_NAME in ${BUILT_IMAGES[@]}; do
    echo "##teamcity[blockOpened name='Remove image $IMAGE_NAME']"
    docker rmi -f "$IMAGE_NAME"
    echo "##teamcity[blockClosed name='Remove image $IMAGE_NAME']"
done
TAG_SUFFIX
cd $BACKUP_PATH
