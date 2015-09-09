# Katello specific certs settings
class certs::katello (
  $hostname                      = $fqdn,
  $deployment_url                = undef,
  $rhsm_port                     = 443,
  $server_ca_name                = $::certs::server_ca_name,
  $candlepin_cert_rpm_alias_filename = undef
  ){

  $candlepin_cert_rpm_alias = $candlepin_cert_rpm_alias_filename ? {
    undef   => 'katello-ca-consumer-latest.noarch.rpm',
    default => $candlepin_cert_rpm_alias_filename,
  }

  $katello_www_pub_dir            = '/var/www/html/pub'

  $rhsm_ca_dir                    = '/etc/rhsm/ca'
  $katello_rhsm_setup_script      = "katello-rhsm-atomic-consumer"
  $katello_rhsm_atomic_tar     = "katello-rhsm-atomic-consumer.tar"

  $candlepin_consumer_name        = "katello-ca-consumer-${::fqdn}"
  $candlepin_consumer_summary     = "Subscription-manager consumer certificate for Katello instance ${::fqdn}"
  $candlepin_consumer_description = 'Consumer certificate and post installation script that configures rhsm.'

  $katello_atomic_base_dir_name   = "atomic"
  $katello_atomic_dir             = "${katello_www_pub_dir}/${katello_atomic_base_dir_name}"
  $sub_manager_cert_file_name     = "${certs::server_ca_name}.pem"

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
  # We need to deliver the server_ca for yum and rhsm to trust the server
  # and the default_ca for goferd to trust the qpid
  certs_bootstrap_rpm { $candlepin_consumer_name:
    dir              => $katello_www_pub_dir,
    summary          => $candlepin_consumer_summary,
    description      => $candlepin_consumer_description,
    # katello-default-ca is needed for the katello-agent to work properly
    # (especially in the custom certs scenario)
    files            => ["${rhsm_ca_dir}/katello-default-ca.pem:644=${certs::pki_dir}/certs/${certs::default_ca_name}.crt",
                        "${rhsm_ca_dir}/katello-server-ca.pem:644=${certs::pki_dir}/certs/${certs::server_ca_name}.crt"],
    bootstrap_script => template('certs/rhsm-katello-reconfigure.erb'),
    alias            => $candlepin_cert_rpm_alias,
    subscribe        => $::certs::server_ca,
  } ~>
  # Setup the atomic pub dir
  file { $katello_atomic_dir:
    ensure => directory,
    owner  => 'apache',
    group  => 'apache',
    mode   => '0755',
    require => File["${katello_www_pub_dir}"]
  } ->
  # Placing the atomic rhsm setup script in the pub dir for atomic rhsm setup
  file { "${katello_atomic_dir}/${katello_rhsm_setup_script}":
    ensure  => file,
    owner   => 'root',
    group   => 'root',
    mode    => '0755',
    content => template('certs/rhsm-katello-atomic-configure.erb')
  } ~>
  # Placing the CA in the atomic pub dir to be included along with the tar gz
  file { "${katello_atomic_dir}/${sub_manager_cert_file_name}":
    ensure  => file,
    source  => "${katello_www_pub_dir}/${certs::server_ca_name}.crt",
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    require => File["${katello_www_pub_dir}/${certs::server_ca_name}.crt"],
  } ~>
  exec { "setup_${katello_rhsm_atomic_tar}":
  cwd     => "${katello_www_pub_dir}",
  command => "/usr/bin/tar cf ${katello_rhsm_atomic_tar} ${katello_atomic_base_dir_name}",
  require => File["${katello_atomic_dir}"],
  }
}
