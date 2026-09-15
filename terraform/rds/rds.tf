resource "aws_db_subnet_group" "rds" {
  name       = "${var.projectName}-rds"
  subnet_ids = local.public_subnet_ids
}

resource "aws_security_group" "allow_postgres_traffic" {
  name        = "${var.projectName}-allow-postgres"
  description = "Allow Postgres traffic"
  vpc_id      = local.vpc_id

  ingress {
    description = "allow Postgres"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow postgres"
  }
}

resource "aws_db_instance" "wrench_db" {
  allocated_storage       = var.rds_database_allocated_storage
  identifier              = var.rds_database_identifier
  db_name                 = var.rds_database_name
  engine                  = var.rds_database_engine
  engine_version          = var.rds_database_engine_version
  instance_class          = var.rds_database_instance_class
  username                = var.rds_database_username
  password                = var.rds_database_password
  db_subnet_group_name    = aws_db_subnet_group.rds.name
  vpc_security_group_ids  = [aws_security_group.allow_postgres_traffic.id]
  publicly_accessible     = true
  skip_final_snapshot     = true
  backup_retention_period = 7
}

resource "cloudflare_dns_record" "db" {
  zone_id = var.cloudflare_zone_id
  name    = "prod-db"
  content = aws_db_instance.wrench_db.address
  type    = "CNAME"
  ttl     = 300
  proxied = false
}
