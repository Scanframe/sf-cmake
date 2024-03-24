#!/usr/bin/env bash
# Needed for this script is pip library 'pip install python-gitlab'
# Quoted strings are ignored by python.
"exec" "$(dirname ${BASH_SOURCE[0]})/venv/bin/python" "$0" "$@"
import os
import configparser
from gitlab import Gitlab
from datetime import datetime, timedelta


def find_up(filename, start_path=os.getcwd()):
	"""
	Searches for a file in the current directory and its parent directories.

	Args:
			filename: The name of the file to search for.
			start_path: The starting directory for the search (defaults to current working directory).

	Returns:
			The full path to the file if found, otherwise None.
	"""
	current_dir = start_path
	while True:
		full_path = os.path.join(current_dir, filename)
		if os.path.isfile(full_path):
			return full_path
		parent_dir = os.path.dirname(current_dir)
		if parent_dir == current_dir:  # Reached root directory
			return None
		current_dir = parent_dir


def get_age(date, reference_date=datetime.today()):
	"""
	Calculates age in years, months, and days given two datetime objects.

	Args:
			date: The datetime object representing the date.
			reference_date (optional): The datetime object representing the reference date (defaults to today).

	Returns:
			A string representing the age in a readable format (e.g., 23 years, 4 months, 11 days).
	"""
	# Extract year, month, day from birthdate and reference date
	birth_year, birth_month, birth_day = date.year, date.month, date.day
	ref_year, ref_month, ref_day = reference_date.year, reference_date.month, reference_date.day
	# Create datetime objects representing only the dates (without time)
	birth_date = datetime(birth_year, birth_month, birth_day)
	ref_date = datetime(ref_year, ref_month, ref_day)
	# Calculate age components (years, months, days) using timedelta
	age = ref_date - birth_date
	years = age.days // 365
	months = (age.days % 365) // 30
	days = age.days % 30
	# Construct and return the readable age string
	age_str = ""
	if years > 0:
		age_str += f"{years} years"
	if months > 0:
		if age_str:
			age_str += ", "
		age_str += f"{months} months"
	if days > 0:
		if age_str:
			age_str += ", "
		age_str += f"{days} days"
	return age_str


def pretty(d, indent=0):
	for key, value in d.items():
		print('\t' * indent + str(key))
		if isinstance(value, dict):
			pretty(value, indent + 1)
		else:
			print('\t' * (indent + 1) + str(value))


def get_gitlab_api():
	"""
	Gets the initialized GitLab API instance.
	:return: Gitlab
	"""
	section = "token"
	parser = configparser.ConfigParser()
	filename = ".gitlab-credentials.ini"
	# Find the token file in one of the parents from the working directory.
	file = find_up(filename)
	# When file not found bailout.
	if not file:
		raise Exception(f"Missing credential file '{filename}' !")
	# Read the file
	parser.read(file)
	# When section not found bailout.
	if section not in parser:
		raise Exception(f"Credential file missing section '{section}'!")
	server = parser[section].get("server")
	token = parser[section].get("value")
	return Gitlab(url=server, private_token=token)


def cleanup_pipelines_and_jobs(project_id, day_age=7, for_real=False):
	"""
	Cleans up Pipelines from jobs older than a week.
	"""
	gl = get_gitlab_api()
	before_data = datetime.utcnow() - timedelta(days=day_age)
	project = gl.projects.get(project_id)
	# Pipelines to delete.
	pipelines_to_del: set[int] = set()
	if True:
		# Iterate through pipelines
		for pl in project.pipelines.list(iterator=True):
			created = datetime.fromisoformat(pl.created_at[:-1])
			print(f"Pipeline ID/Name/Status/Age/URL: {pl.id}, {pl.name}, {pl.status}, {get_age(created)}, {pl.web_url}")
			# Check if pipeline creation time is older than a week
			if created < before_data:
				print(f"Deleting pipeline ID {pl.id}")
				if for_real:
					pl.delete()
	if True:
		for job in project.jobs.list(iterator=True):
			created = datetime.fromisoformat(job.created_at[:-1])
			# Check if pipeline creation time is older than a week
			# if created < one_week_ago and job.status != "success":
			if created < before_data:
				print(f"Job/Pipline/Status/Age/URL: {job.id}, {job.pipeline['id']}, {job.status}, {get_age(created)}, {job.web_url}")
				print(f"Adding pipeline to Deleting job ID {job.id}")
				if job.pipeline['id'] not in pipelines_to_del:
					pipelines_to_del.add(job.pipeline['id'])
	print(f"Pipline ID's({len(pipelines_to_del)}): {pipelines_to_del}")
	# Delete all unique pipelines.
	for pl_id in pipelines_to_del:
		pl = project.pipelines.get(pl_id)
		created = datetime.fromisoformat(pl.created_at[:-1])
		print(f"Pipeline ID/Name/Status/Age/URL: {pl.id}, {pl.name}, {pl.status}, {get_age(created)}, {pl.web_url}")
		if for_real:
			pl.delete()

# TODO: Must be configurable using command line arguments.
cleanup_pipelines_and_jobs(project_id=53, day_age=3, for_real=False)
# cleanup_pipelines_and_jobs(project_id=53, day_age=3, for_real=True)
# cleanup_pipelines_and_jobs(project_id=50, day_age=2, for_real=True)
# cleanup_pipelines_and_jobs(project_id=53, day_age=3, for_real=True)
