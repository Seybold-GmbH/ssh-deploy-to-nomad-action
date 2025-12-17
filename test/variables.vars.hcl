# Variable definitions for test-service
# These use [[VAR]] placeholders that will be substituted at deployment time

# String values (will be quoted)
variable "service_name" {
  type = string
}

variable "service_image" {
  type = string
}

variable "environment" {
  type = string
}

variable "api_key" {
  type = string
}

# Number values (will be unquoted)
variable "service_count" {
  type = number
}

variable "service_cpu" {
  type = number
}

variable "service_memory" {
  type = number
}

# Boolean values (will be unquoted)
variable "debug_enabled" {
  type = bool
}

# List values (will be unquoted)
variable "datacenters" {
  type = list(string)
}

variable "service_tags" {
  type = list(string)
}

# Variable assignments with [[VAR]] placeholders
datacenters     = [[DATACENTERS]]
service_name    = [[SERVICE_NAME]]
service_image   = [[SERVICE_IMAGE]]
service_count   = [[SERVICE_COUNT]]
service_cpu     = [[SERVICE_CPU]]
service_memory  = [[SERVICE_MEMORY]]
environment     = [[ENVIRONMENT]]
debug_enabled   = [[DEBUG_ENABLED]]
api_key         = [[API_KEY]]
service_tags    = [[SERVICE_TAGS]]
