terraform {
  required_version = ">= 0.11.2"
}

resource "aws_instance" "alertmanager" {
  ami                    = "${var.ami_id}"
  instance_type          = "t2.micro"
  subnet_id              = "${var.prom_subnet_id}"
  user_data              = "${data.template_file.user_data_script.rendered}"
  private_ip             = "${var.am_priv_ip}"
  vpc_security_group_ids = ["${var.prom_security_groups}"]

  tags {
    Name = "alertmanager"
  }
}

data "template_file" "user_data_script" {
  template = "${file("${path.module}/cloud.conf")}"

  vars {
    alertmanager_version = "${var.alertmanager_version}"
    domain_name          = "${var.domain_name}"
    lets_encrypt_email   = "${var.lets_encrypt_email}"
    real_certificate     = "${var.real_certificate=="yes" ? "-v" : "--staging"}"
    logstash_endpoint    = "${var.logstash_endpoint}"
    logstash_port        = "${var.logstash_port}"
  }
}

resource "aws_eip" "eip_alertmanager" {
  vpc = true
}

resource "aws_eip_association" "eip_assoc" {
  instance_id   = "${aws_instance.alertmanager.id}"
  allocation_id = "${aws_eip.eip_alertmanager.id}"
}

resource "aws_route53_record" "alertmanager_www" {
  zone_id = "${var.reliability_engineering_zone_id}"
  name    = "alerts.gds-reliability.engineering"
  type    = "A"
  ttl     = "3600"
  records = ["${aws_eip.eip_alertmanager.public_ip}"]
}
