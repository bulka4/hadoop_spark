output "public_key" {
  value = azapi_resource_action.ssh_public_key_gen.output.publicKey
}

output "private_key" {
  value = azapi_resource_action.ssh_public_key_gen.output.privateKey
}