resource "aws_instance" "web_server" {
  ami           = data.aws_ami.example.id
  instance_type = var.instance_type

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }
}

resource "aws_instance" "web_server" {
  monitoring = true
}
