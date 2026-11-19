variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "scanpilot"
}

variable "demo_api_key" {
  description = "Demo customer API key. Only its SHA-256 hash is stored in DynamoDB."
  type        = string
  default     = "sp-demo-key-123"
  sensitive   = true
}

variable "enable_nat" {
  description = "The NAT gateway costs money per hour. Set false for sessions that don't need pentest egress."
  type        = bool
  default     = true
}

variable "alert_email" {
  description = "Email for failed-run alerts. Leave empty to skip the subscription."
  type        = string
  default     = ""
}
