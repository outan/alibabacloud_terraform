output "ECS_instance_ip" {
  value = "${alicloud_instance.ECS_instance.*.public_ip}"
}
output "slb_ip" {
  value = "${alicloud_slb_load_balancer.default.address}"
}
output "rds_primary_host" {
  value = "${alicloud_db_instance.primary_instance.connection_string}"
}
output "rds_readonly_host" {
  value = "${alicloud_db_readonly_instance.readonly_instance.connection_string}"
}
