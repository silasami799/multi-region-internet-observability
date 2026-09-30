variable "central_region" {
  description = "Merkezi DynamoDB tablosunun bulunacağı bölge"
  type        = string
  default     = "eu-north-1" # Stockholm
}
variable "probe_regions" {
  description = "Probeların dağıtılacağı hedef bölgeler"
  type        = list(string)
  default     = ["eu-north-1", "eu-central-1", "us-east-1"]
}
variable "table_name" {
  description = "DynamoDB tablo adı"
  type        = string
  default     = "InternetLatencyMetrics"
}