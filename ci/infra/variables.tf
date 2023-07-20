variable "project" {
  description = "Name of project"

  type     = string
  nullable = false
}

variable "environment" {
  description = "Environment of project"

  type     = string
  nullable = false
}

variable "user" {
  description = "Name of CI user"

  type     = string
  nullable = false
}

variable "bucket" {
  description = "Name of AWS S3 bucket"

  type     = string
  nullable = false
}

variable "pgp_pub_key" {
  description = "Path of the Public PGP key for encryption"

  type     = string
  nullable = false
}
