#!/bin/bash

# Function to check the success of a command
check_command_success() {
    if [ $? -ne 0 ]; then
        echo "Error during: $1"
        exit 1
    fi
}

# Function to create a git tag
create_tag() {
    echo "Creating tag $VERSION with annotation \"$ANNOTATION\""
    ./git.sh "$VERSION" "$ANNOTATION"
    check_command_success "tag creation"
}

# Function to switch git branch
switch_branch() {
    echo "Switching to the $1 branch"
    git checkout $1
    check_command_success "switching to $1 branch"
}

# Check if the correct number of arguments is provided
if (( $# != 2 )); then
    printf "%b" "Usage: git.sh <version> <annotation>\n" >&2
    exit 1
fi

# Assign command-line arguments to variables
VERSION="$1"
ANNOTATION="$2"

# Create tag
create_tag

# Switch to main branch
switch_branch "main"

# Merge development branch into main
echo "Merging development branch into main"
git merge development
check_command_success "merging development into main"

# Create tag again
create_tag

# Switch back to development branch
switch_branch "development"

# Show current status after operations
git status
check_command_success "git status"