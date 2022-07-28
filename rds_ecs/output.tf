output "ECS_instance_ip" {
  value = "${alicloud_instance.ECS_instance.*.public_ip}"
}
output "slb_ip" {
  value = "${alicloud_slb_load_balancer.default.address}"
}
output "rds_primary_host" {
  value = "${alicloud_db_instance.db_instance.connection_string}"
}
