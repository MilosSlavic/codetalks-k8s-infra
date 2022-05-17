terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.11.0"
    }
  }
}

resource "kubernetes_config_map" "global" {
  metadata {
    name      = "global"
    namespace = "default"
  }

  data = {
    "ASPNETCORE_ENVIRONMENT"                                            = "Test"
    "Logging__LogLevel__Microsoft.EntityFrameworkCore.Database.Command" = "Error"
    "Serilog__MinimumLevel__Override__Microsoft.EntityFrameworkCore.Database.Command" : "Error"
    "Kestrel__Endpoints__http__Url"                = "http://+:80"
    "Kestrel__Endpoints__http__Protocols"          = "Http1"
    "Kestrel__Endpoints__grpc__Url"                = "http://+:90"
    "Kestrel__Endpoints__grpc__Protocols"          = "Http2"
    "ASPNETCORE_HOSTBUILDER__RELOADCONFIGONCHANGE" = "false"
    "COMPlus_gcServer"                             = "0"
    "DOTNET_gcServer"                              = "0"
  }
}

resource "kubernetes_config_map" "employee" {
  metadata {
    name      = "employee"
    namespace = "default"
  }

  data = {
    "ConnectionStrings__DefaultConnection" = var.employeedb
  }
}

resource "kubernetes_config_map" "knowledge" {
  metadata {
    name      = "knowledge"
    namespace = "default"
  }

  data = {
    "ConnectionStrings__DefaultConnection" = var.knowledgedb
  }
}

resource "kubernetes_config_map" "employeesearchbff" {
  metadata {
    name      = "employeesearchbff"
    namespace = "default"
  }

  data = {
    "EMPLOYEE_GRPC_API"  = "http://employee.api:90/"
    "KNOWLEDGE_GRPC_API" = "http://knowledge.api:90/"
  }
}