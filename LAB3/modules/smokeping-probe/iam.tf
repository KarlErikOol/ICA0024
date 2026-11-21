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

# Deliberately untagged: tagging needs iam:TagInstanceProfile, which restricted
# accounts (such as the shared TalTech student account) deny, failing the whole
# create. The name still carries the prefix, and the role it wraps is tagged.
resource "aws_iam_instance_profile" "probe" {
  name = "${var.name}-profile"
  role = aws_iam_role.probe.name
}
