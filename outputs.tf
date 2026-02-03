
output "vault_instance_id" {
  value = aws_instance.vault.id
}

output "vault_public_ip" {
  value = aws_instance.vault.public_ip
}

output "vault_kms_key_arn" {
  value = aws_kms_key.vault_unseal.arn
}
