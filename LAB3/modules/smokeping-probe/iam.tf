# --- iam -------------------------------------------------------------------

# The instance only needs SSM, which is the only way to get a shell on it
# (there is no SSH key or port 22).
resource "aws_iam_role" "probe" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Action    = "sts:AssumeRole"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })

  tags = merge(local.tags, { Name = "${var.name}-role" })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.probe.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "probe" {
  name = "${var.name}-profile"
  role = aws_iam_role.probe.name

  tags = merge(local.tags, { Name = "${var.name}-profile" })
}
