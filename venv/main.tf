resource "aws_instance" "web_server" {
  ami           = data.aws_ami.example.id
  instance_type = var.instance_type
}