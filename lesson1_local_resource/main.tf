resource "local_file" "hello_world" {
  filename = "${path.module}/demo.txt"

  content = <<-EOF
    Hello World!!!
    Welcome to the fascinating world of OpenTofu!!
  EOF
}
