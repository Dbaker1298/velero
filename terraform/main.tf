resource "null_resource" "example" {
  provisioner "local-exec" {
    command = "echo 'Test resource created'"
  }
}