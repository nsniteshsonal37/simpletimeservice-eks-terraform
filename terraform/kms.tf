resource "aws_kms_key" "eks_cluster_encryption" {
  description             = "KMS key for EKS secret encryption"
  deletion_window_in_days = var.kms_deletion_window_in_days
  enable_key_rotation     = var.kms_enable_key_rotation

  tags = merge(
    local.common_tags,
    { Name = "${local.cluster_name}-kms" }
  )
}

resource "aws_kms_alias" "eks_cluster_encryption" {
  name          = "alias/eks/${local.cluster_name}"
  target_key_id = aws_kms_key.eks_cluster_encryption.key_id
}