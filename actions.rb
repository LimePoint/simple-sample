require 'mintpress-infrastructure-oci'

host_name = 'asdf'

action :default do
  log.warn "#{host_name}: fqdn is nil — VM may not exist or OCI did not return a hostname"
end
