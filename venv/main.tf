resource "aws_instance" "web_server" {
  ami                  = data.aws_ami.example.id
  instance_type        = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.web_server.name
  monitoring           = true
  ebs_optimized        = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = "gp3"
    volume_size           = 8 # GiB
    encrypted             = true
    kms_key_id            = aws_kms_key.ebs.arn
    delete_on_termination = true
  }
}

resource "aws_ebs_volume" "data" {
  availability_zone = aws_instance.web_server.availability_zone # must be in the same AZ as the instance
  size              = var.data_volume_size
  type              = "gp3"
  encrypted         = true
  kms_key_id        = aws_kms_key.ebs.arn

  tags = {
    Name = "web-server-data"
  }
}

resource "aws_volume_attachment" "data" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.data.id
  instance_id = aws_instance.web_server.id
}

# Trust policy: allows the EC2 service to assume this role
data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "web_server" {
  name               = "web-server-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
}

# Permissions: what the instance is allowed to do
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.web_server.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile: the container EC2 actually attaches
resource "aws_iam_instance_profile" "web_server" {
  name = "web-server-profile"
  role = aws_iam_role.web_server.name
}

data "aws_caller_identity" "current" {}

# Key policy: account administrators keep full control of the key
data "aws_iam_policy_document" "ebs_kms" {
  # checkov:skip=CKV_AWS_109: KMS key policy - resource "*" means this key only
  # checkov:skip=CKV_AWS_111: KMS key policy - resource "*" means this key only
  # checkov:skip=CKV_AWS_356: KMS key policy - resource "*" means this key only
  statement {
    sid       = "EnableRootAccountPermissions"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}


resource "aws_kms_key" "ebs" {
  description             = "KMS key for web server EBS volumes"
  enable_key_rotation     = true
  deletion_window_in_days = 30
  policy                  = data.aws_iam_policy_document.ebs_kms.json
}

resource "aws_kms_alias" "ebs" {
  name          = "alias/web-server-ebs"
  target_key_id = aws_kms_key.ebs.key_id
}