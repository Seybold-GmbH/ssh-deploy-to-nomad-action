# Variable definitions for test-service
# These use ENV_ placeholders that will be substituted at deployment time

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

# Variable assignments with ENV placeholders
datacenters     = ENV_DATACENTERS
service_name    = "ENV_SERVICE_NAME"
service_image   = "ENV_SERVICE_IMAGE"
service_count   = ENV_SERVICE_COUNT
service_cpu     = ENV_SERVICE_CPU
service_memory  = ENV_SERVICE_MEMORY
environment     = "ENV_ENVIRONMENT"
debug_enabled   = ENV_DEBUG_ENABLED
api_key         = "ENV_API_KEY"
service_tags    = ENV_SERVICE_TAGS
