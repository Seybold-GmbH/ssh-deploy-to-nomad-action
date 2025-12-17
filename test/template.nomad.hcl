job "test-service" {
  datacenters = var.datacenters
  type        = "service"

  group "app" {
    count = var.service_count

    network {
      port "http" {
        to = 8080
      }
    }

    task "app" {
      driver = "docker"

      config {
        image = var.service_image
        ports = ["http"]
      }

      env {
        ENVIRONMENT = var.environment
        DEBUG       = var.debug_enabled
        API_KEY     = var.api_key
      }

      resources {
        cpu    = var.service_cpu
        memory = var.service_memory
      }

      service {
        name = var.service_name
        port = "http"
        
        tags = var.service_tags

        check {
          type     = "http"
          path     = "/health"
          interval = "10s"
          timeout  = "2s"
        }
      }
    }
  }
}
