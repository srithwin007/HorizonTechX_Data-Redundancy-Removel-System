output "api_endpoint_post" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/check"
  description = "POST to store/check data"
}

output "api_endpoint_get_all" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/check"
  description = "GET to view all stored records"
}

output "api_endpoint_get_check" {
  value       = "${aws_api_gateway_stage.prod.invoke_url}/check?data=YourTextHere"
  description = "GET to check if specific data exists"
}
