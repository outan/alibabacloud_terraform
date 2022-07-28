terraform {
  cloud {
    organization = "outanwang"

    workspaces {
      name = "alibabacloud_terraform"
    }
  }
}

provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

# network関連
resource "alicloud_vpc" "vpc" {
  vpc_name = "${var.project_name}-vpc"
  cidr_block = "192.168.1.0/24"
  description = "Enable RDS Setting Sample vpc"
}

resource "alicloud_vswitch" "vsw" {
  vswitch_name      = "${var.project_name}-vswitch"
  vpc_id            = "${alicloud_vpc.vpc.id}"
  cidr_block        = "192.168.1.0/28"
  zone_id           = "${var.zone}"
  description = "Enable RDS Setting Sample vswitch"
}

# RDS関連
resource "alicloud_db_instance" "primary_instance" {
  engine = "MySQL"
  engine_version = "5.7"
  instance_type = "rds.mysql.t1.small"
  instance_storage = 5
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  security_ips = ["192.168.1.0/28"]
}

resource "alicloud_db_database" "default" {
  name = "${var.database_name}"
  instance_id = "${alicloud_db_instance.primary_instance.id}"
  character_set = "utf8"
}

resource "alicloud_db_account" "default" {
  db_instance_id = "${alicloud_db_instance.primary_instance.id}"
  account_name = "${var.db_user}"
  account_password = "${var.db_password}"
}

resource "alicloud_db_account_privilege" "default" {
  instance_id = "${alicloud_db_instance.primary_instance.id}"
  account_name = "${alicloud_db_account.default.name}"
  db_names = ["${alicloud_db_database.default.name}"]
  privilege = "ReadWrite"
}

resource "alicloud_db_connection" "default" {
  instance_id = "${alicloud_db_instance.primary_instance.id}"
  connection_prefix = "rds-sample"
  port = "3306"
}

resource "alicloud_db_readonly_instance" "readonly_instance" {
  master_db_instance_id = "${alicloud_db_instance.primary_instance.id}"
  zone_id               = alicloud_db_instance.primary_instance.zone_id
  engine_version        = "${alicloud_db_instance.primary_instance.engine_version}"
  instance_type         = "${alicloud_db_instance.primary_instance.instance_type}"
  instance_storage      = "30"
  instance_name         = "${var.database_name}ro"
  vswitch_id            = "${alicloud_vswitch.vsw.id}"
}

resource "alicloud_db_read_write_splitting_connection" "splitting_connection" {
  instance_id       = "${alicloud_db_instance.primary_instance.id}"
  connection_prefix = "t-con-123"
  distribution_type = "Standard"
  depends_on = [alicloud_db_readonly_instance.readonly_instance]
}

# ECS関連
resource "alicloud_security_group" "sg" {
  name   = "${var.project_name}_security_group"
  description = "Enable RDS Setting Sample security group"
  vpc_id = "${alicloud_vpc.vpc.id}"
}

resource "alicloud_security_group_rule" "allow_ssh" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "22/22"
  priority          = 1
  security_group_id = "${alicloud_security_group.sg.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_security_group_rule" "allow_http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = "${alicloud_security_group.sg.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_instance" "ECS_instance" {
  instance_name   = "${var.project_name}-ECS-instance"
  host_name   = "${var.project_name}-ECS-instance"
  instance_type   = "ecs.sn1.medium"
  image_id        = "centos_7_04_64_20G_alibase_201701015.vhd"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  availability_zone = "${var.zone}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  password = "${var.ecs_password}"
  internet_max_bandwidth_out = 20
  user_data = "${file("provisioning.sh")}"
}

# SLB関連
resource "alicloud_slb_load_balancer" "default" {
  load_balancer_name = "${var.project_name}-slb"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  address_type = "internet"
  internet_charge_type = "PayByTraffic"
  load_balancer_spec = "slb.s2.small"
}

resource "alicloud_slb_listener" "http" {
  load_balancer_id = "${alicloud_slb_load_balancer.default.id}"
  backend_port              = 80
  frontend_port             = 80
  health_check_connect_port = 80
  bandwidth                 = 10
  protocol = "http"
  sticky_session = "on"
  sticky_session_type = "insert"
  cookie = "slblistenercookie"
  cookie_timeout = 86400
}

resource "alicloud_slb_attachment" "default" {
  load_balancer_id = "${alicloud_slb_load_balancer.default.id}"
  instance_ids = ["${alicloud_instance.ECS_instance.id}"]
}

data "template_file" "user_data" {
  template = "${file("provisioning.sh")}"
  vars = {
    DB_HOST_IP = "${alicloud_db_instance.primary_instance.connection_string}"
    DB_NAME = "${var.database_name}"
    DB_USER = "${var.db_user}"
    DB_PASSWORD = "${var.db_password}"
  }
}
