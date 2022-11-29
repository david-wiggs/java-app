terraform {
  required_providers {
    github = {
      source  = "integrations/github"
      version = "~>5.10.0"
    }
  }
}


provider "github" {
  token = var.github_token
  owner = var.target_repository.owner
}


resource "github_repository" "repository" {
  name                   = var.target_repository.repo
  description            = "Bookstore security demo repository for @${var.actor}"
  visibility             = "private"
  has_issues             = true
  has_projects           = false
  delete_branch_on_merge = true
  vulnerability_alerts   = true
  template {
    owner      = var.template_repository.owner
    repository = var.template_repository.repo
  }
}

resource "github_team" "repository_admins" {
  name                      = "${github_repository.repository.name}-admins"
  description               = "Admins for the ${github_repository.repository.name} repository"
  create_default_maintainer = true
}

resource "github_team_repository" "repository_admins" {
  team_id = github_team.repository_admins.id
  repository = github_repository.repository.name
  permission = "admin"
}

resource "github_team_membership" "actor_repository_admin" {
  team_id = github_team.repository_admins.id
  username = var.actor
  role = "maintainer"
}

resource "github_issue_label" "deploy_to_test" {
  repository  = github_repository.repository.name
  name        = "deploy to test"
  description = "Trigger a deploy event targeting the test environment"
  color       = "7d5c01"
}

resource "github_actions_secret" "azure_app_plan" {
  repository      = github_repository.repository.name
  secret_name     = "AZURE_APP_PLAN_NAME"
  plaintext_value = var.azure.service_plan_name
}

resource "github_actions_secret" "azure_resource_group" {
  repository      = github_repository.repository.name
  secret_name     = "AZURE_RESOURCE_GROUP_NAME"
  plaintext_value = var.azure.resource_group_name
}

resource "github_branch_protection" "protect_default_branch" {
  repository_id  = github_repository.repository.name
  pattern        = "main"
  enforce_admins = false

  required_status_checks {
    strict = false
    # The following is tied into the workflow actions for the builds in the base template repository
    contexts = [
      "Container Build - application / build_and_publish_container",
      "CodeQL Code Scanning",
      "CodeQL",
      "Container Vulnerabilty Scan - app"
    ]
  }
  required_pull_request_reviews {
    dismiss_stale_reviews           = true
    required_approving_review_count = 1
  }
}


output "repository_url" {
  value       = github_repository.repository.html_url
  description = "The HTML URL for the newly created repository"
}

output "repository_full_name" {
  value       = github_repository.repository.full_name
  description = "The name for the newly created repository in 'owner/repo_name' form"
}
