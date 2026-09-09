# Initialize an Offline-First Monorepo Workspace automatically
# Usage: just -f tools/repo_scaffold.just run <path> [--force-sync]
run TARGET_WORKSPACE_PATH FORCE_SYNC="false":
    #!/usr/bin/env python3
    # Note: Using Python 3 here is 100% safe and cross-platform (Linux/macOS).
    # The Google Repo Tool strictly requires Python 3.6+, meaning any environment 
    # capable of running this Offline-First architecture already has Python 3 installed.
    import xml.etree.ElementTree as ET
    import os, subprocess, shutil, tempfile

    # Just sets cwd to the directory of the justfile (tools/). Move up to project root.
    os.chdir("..")

    target_workspace = os.path.abspath("{{TARGET_WORKSPACE_PATH}}")
    force_sync_arg = "{{FORCE_SYNC}}".strip()
    is_force = force_sync_arg == "--force-sync"
    
    git_server = os.path.join(target_workspace, ".local", "local-git-server")
    os.makedirs(git_server, exist_ok=True)

    print(f"🚀 Starting Auto-Scaffold Workspace at: {target_workspace}")

    # 1. Parse XML to get a list of projects using local_fs
    if not os.path.exists("default.xml"):
        print("❌ Error: default.xml not found in current directory.")
        exit(1)

    tree = ET.parse("default.xml")
    root = tree.getroot()
    local_projects = [p.get('name') for p in root.findall('project') if p.get('remote') == 'local_fs']
    
    # Ensure local-manifests.git is always included even if not explicitly marked with local_fs (though it should be)
    if "local-manifests.git" not in local_projects:
        local_projects.append("local-manifests.git")
    
    # 2. Function to create bare repo with an initial empty commit
    def init_bare(repo_name):
        repo_path = os.path.join(git_server, repo_name)
        if os.path.exists(repo_path):
            print(f"⏩ Repo {repo_name} already exists, skipping initialization...")
            return
            
        print(f"📦 Initializing Bare Repo: {repo_name}")
        subprocess.run(['git', 'init', '--bare', repo_path], check=True, capture_output=True)
        
        # Seed a root commit to prevent 0-commit fetch errors in Repo tool (Skip local-manifests.git)
        if repo_name != "local-manifests.git":
            with tempfile.TemporaryDirectory() as tmpdir:
                subprocess.run(['git', '-C', tmpdir, 'init'], check=True, capture_output=True)
                subprocess.run(['git', '-C', tmpdir, 'commit', '--allow-empty', '-m', 'chore: root commit'], check=True, capture_output=True)
                subprocess.run(['git', '-C', tmpdir, 'push', repo_path, 'HEAD:main'], check=True, capture_output=True)

    for proj in local_projects:
        init_bare(proj)

    # 3. Package current template configuration and push to local-manifests.git
    print("🌱 Pushing configuration template to local-manifests.git...")
    manifest_repo = os.path.join(git_server, "local-manifests.git")
    
    # Remove downloaded template's .git history to ensure a clean start
    if os.path.exists(".git"):
        shutil.rmtree(".git")
    
    subprocess.run(['git', 'init'], check=True, capture_output=True)
    subprocess.run(['git', 'add', '.'], check=True, capture_output=True)
    subprocess.run(['git', 'commit', '-m', 'chore: auto-scaffolded manifest architecture'], check=True, capture_output=True)
    subprocess.run(['git', 'branch', '-M', 'main'], check=True, capture_output=True)
    subprocess.run(['git', 'push', '-f', manifest_repo, 'main'], check=True, capture_output=True)

    # 4. Execute Repo Init and Sync at the target workspace
    print("🔄 Synchronizing workspace using Google Repo Tool...")
    manifest_url = f"file://{manifest_repo}"
    subprocess.run(['repo', 'init', '-u', manifest_url, '-b', 'main'], cwd=target_workspace, check=True)
    
    sync_cmd = ['repo', 'sync']
    if is_force:
        print("⚠️ Force sync enabled. Overwriting existing work trees if necessary...")
        sync_cmd.append('--force-sync')
        
    subprocess.run(sync_cmd, cwd=target_workspace, check=True)

    print(f"\n✅ Scaffold complete! Start developing by running:")
    print(f"   cd {target_workspace}")
    print(f"   just feature initial-setup")
