# List all available commands
default:
    @just --list

# Sync the project according to Manifest configuration
sync:
    repo sync -j4

# Detach and checkout all modules to the exact revision defined in XML (ignoring local branch state)
checkout:
    repo sync -d

# View detailed status of all tracked modules
status:
    repo status

# Start a new feature (create branch across all modules)
feature name:
    repo start {{name}} --all

# Clean untracked files across the entire project
clean:
    repo forall -c 'git clean -fd'

# Push active branches to their respective Remotes
push branch="main":
    repo forall -c 'git push origin {{branch}}'