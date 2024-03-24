#!/usr/bin/python3
# !/usr/bin/env bash
# Quoted strings are ignored by python.
# "exec" "$(dirname ${BASH_SOURCE[0]})/venv/bin/python" "$0" "$@"
import os
import git

def analyze_commit_messages(git_repo, tag, commit_sha):
	"""
	Analyzes commit message texts from a tag to a more recent commit.

	Args:
			git_repo (git.Repo): The Git repository object.
			tag (str): The name of the tag to start analysis from.
			commit_sha (str): The SHA of the more recent commit (exclusive).
	"""
	# Get commits between the tag and recent commit (excluding recent commit)
	tag = git_repo.tags[tag]
	commits = list(git_repo.iter_commits(rev=tag.commit.hexsha, until=commit_sha))

	# Analyze commit messages (replace with your desired analysis logic)
	for commit in commits:
		message = commit.message.strip()
		print(f"Commit SHA: {commit.hexsha}")
		print(f"Message: {message}")

		# Add your analysis logic here (e.g., word count, keyword search)
		# Example: word count
		word_count = len(message.split())
		print(f"Word count: {word_count}")
		print("---")


if __name__ == "__main__":
	# Replace with your repository path
	repo_path = os.getcwd()
	# Replace with your desired tag
	tag_name = "v0.1.0"
	# Analyze up to the most recent commit (excluding)
	recent_commit_sha = "HEAD~"
	# Open the Git repository
	repo = git.Repo(repo_path)
	# Make the call.
	analyze_commit_messages(repo, tag_name, recent_commit_sha)
