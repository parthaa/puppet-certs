# Katello specific certs settings
class certs::katello (
  $hostname                      = $fqdn,
  $deployment_url                = undef,
  $rhsm_port                     = 443,
  $server_ca_name                = $::certs::server_ca_name,
  $default_ca_name               = $::certs::default_ca_name,
  $candlepin_cert_rpm_alias_filename = undef
  ){

  $candlepin_cert_rpm_alias = $candlepin_cert_rpm_alias_filename ? {
    undef   => 'katello-ca-consumer-latest.noarch.rpm',
    default => $candlepin_cert_rpm_alias_filename,
  }

  $katello_www_pub_dir            = '/var/www/html/pub'

  $rhsm_ca_dir                    = '/etc/rhsm/ca'
  $katello_rhsm_setup_script      = "katello-rhsm-consumer"

  $candlepin_consumer_name        = "katello-ca-consumer-${::fqdn}"
  $candlepin_consumer_summary     = "Subscription-manager consumer certificate for Katello instance ${::fqdn}"
  $candlepin_consumer_description = 'Consumer certificate and post installation script that configures rhsm.'

  $sub_manager_cert_file_name     = "${certs::server_ca_name}.pem"

  $katello_default_ca_data = file("${certs::pki_dir}/certs/${certs::default_ca_name}.crt")
  $katello_server_ca_data = file("${certs::pki_dir}/certs/${certs::server_ca_name}.crt")

  include ::trusted_ca
  trusted_ca::ca { 'katello_server-host-cert':
    source  => $certs::katello_server_ca_cert,
    require => File[$certs::katello_server_ca_cert],
  }

  file { $katello_www_pub_dir:
    ensure => directory,
    owner  => 'apache',
    group  => 'apache',
    mode   => '0755',
  } ->
  # Placing the CA in the pub dir for trusting by a user in their browser
  file { "${katello_www_pub_dir}/${certs::server_ca_name}.crt":
    ensure  => file,
    source  => "${certs::pki_dir}/certs/${certs::server_ca_name}.crt",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File["${certs::pki_dir}/certs/${certs::server_ca_name}.crt"],
  } ~>
  # Placing the rhsm setup script in the pub dir for rhsm setup
  file { "${katello_www_pub_dir}/${katello_rhsm_setup_script}":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('certs/rhsm-katello-reconfigure.erb')
  }
}
