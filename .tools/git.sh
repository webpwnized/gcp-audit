#!/bin/bash

# Check if the correct number of arguments is provided
if (( $# != 2 )); then
    printf "%b" "Usage: git.sh <version> <annotation>\n" >&2
    exit 1
fi

# Assign command-line arguments to variables
VERSION="$1"
ANNOTATION="$2"

# Validate input
if [[ -z "$VERSION" || -z "$ANNOTATION" ]]; then
    echo "Error: Version and annotation cannot be empty."
    exit 1
fi

# Inform user about the tag creation
echo "Creating tag $VERSION with annotation \"$ANNOTATION\""
# Create annotated tag with version and annotation
git tag -a "$VERSION" -m "$ANNOTATION"

# Inform user about committing the version to the local branch
echo "Committing version $VERSION to the local branch"
# Commit version with annotation message
git commit -a -m "$VERSION $ANNOTATION"

# Inform user about pushing the tag
echo "Pushing tag $VERSION"
# Push the created tag
git push --tag

# Inform user about pushing the version to the upstream
echo "Pushing version $VERSION to the upstream"
# Push the committed changes to the upstream
git push
