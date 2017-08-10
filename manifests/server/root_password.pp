#
class mysql::server::root_password {

  $options         = $mysql::server::options
  $secret_file     = $mysql::server::install_secret_file
  $secret_grep     = $mysql::server::install_secret_grep
  $secret_grep_opt = $mysql::server::install_secret_grep_opt
  $secret_rm       = $mysql::server::install_secret_rm

  # New installations of MySQL will configure a default random password for the root user
  # with an expiration. No actions can be performed until this password is changed. The
  # below exec will remove this default password. If the user has supplied a root
  # password it will be set further down with the mysql_user resource.
  $rm_pass_mysql = "mysqladmin -u root --password=\$(grep ${secret_grep_opt} \'${secret_grep}\' ${secret_file}) password ''"
  $rm_pass_file = "${secret_rm} ${secret_file}"

  exec { 'remove install pass from mysql':
    command => $rm_pass_mysql,
    onlyif  => [ "test -f ${secret_file}", "grep ${secret_grep_opt} \'${secret_grep}\' ${secret_file}" ],
    path    => ['/bin','/sbin','/usr/bin','/usr/sbin','/usr/local/bin','/usr/local/sbin'],
  }
  -> exec { 'remove install pass in file':
    command => $rm_pass_file,
    path    => ['/bin','/sbin','/usr/bin','/usr/sbin','/usr/local/bin','/usr/local/sbin'],
  }

  # manage root password if it is set
  if $mysql::server::create_root_user == true and $mysql::server::root_password != 'UNSET' {
    mysql_user { 'root@localhost':
      ensure        => present,
      password_hash => mysql_password($mysql::server::root_password),
      require       => Exec['remove install pass'],
    }
  }

  if $mysql::server::create_root_my_cnf == true and $mysql::server::root_password != 'UNSET' {
    file { "${::root_home}/.my.cnf":
      content => template('mysql/my.cnf.pass.erb'),
      owner   => 'root',
      mode    => '0600',
    }

    # show_diff was added with puppet 3.0
    if versioncmp($::puppetversion, '3.0') >= 0 {
      File["${::root_home}/.my.cnf"] { show_diff => false }
    }
    if $mysql::server::create_root_user == true {
      Mysql_user['root@localhost'] -> File["${::root_home}/.my.cnf"]
    }
  }
}
