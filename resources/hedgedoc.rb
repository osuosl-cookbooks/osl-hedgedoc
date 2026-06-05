resource_name :osl_hedgedoc
provides :osl_hedgedoc
unified_mode true

default_action :create

property :domain, String, name_property: true
property :db_dialect, String, default: 'postgres', equal_to: %w(postgres mysql)
property :db_host, String, required: true
property :db_port, Integer
property :db_name, String, required: true
property :db_user, String, required: true
property :db_password, String, sensitive: true, required: true
property :session_secret, String, sensitive: true, required: true
property :version, String, default: 'latest'
property :port, Integer, default: 3000
property :timezone, String, default: 'UTC'
property :allow_anonymous, [true, false], default: true
property :allow_email_register, [true, false], default: true
# LDAP authentication. Keys map to CMD_LDAP_<KEY> env vars, e.g.
# { 'url' => 'ldaps://ldap.example.org', 'searchbase' => 'ou=people,dc=example,dc=org' }.
# Sensitive because it holds bind credentials (CMD_LDAP_BINDCREDENTIALS).
property :ldap, Hash, default: {}, sensitive: true
# Generic OAuth2 / OpenID Connect provider. Keys map to CMD_OAUTH2_<KEY> env
# vars, e.g. { 'client_id' => '...', 'authorization_url' => '...' }.
# Sensitive because it holds the client secret (CMD_OAUTH2_CLIENT_SECRET).
property :oauth2, Hash, default: {}, sensitive: true
# Custom landing page, bind-mounted over the container's public/intro.md.
# Provide it either as inline markdown (intro_md) or as a cookbook_file shipped
# in a cookbook (intro_source, defaulting to the calling cookbook). The two are
# mutually exclusive.
property :intro_md, String
property :intro_source, String
property :intro_cookbook, String
# Arbitrary additional HedgeDoc settings, rendered verbatim into the .env file
# as KEY=value lines. Use the full env var name, e.g.
# { 'CMD_ALLOW_FREEURL' => true, 'CMD_DEFAULT_PERMISSION' => 'limited' }.
property :extra_options, Hash, default: {}

action :create do
  include_recipe 'osl-docker'

  # Each instance lives under its own directory so multiple HedgeDoc instances
  # can run on the same host. `instance` is a sanitized identifier reused for the
  # Compose project and image resource. See libraries/helpers.rb.
  base_dir = hedgedoc_base_dir(new_resource.name)
  instance = hedgedoc_instance(new_resource.name)
  # The firewall chain name is truncated to satisfy the iptables 28-char limit,
  # which the full (sanitized) domain routinely exceeds.
  firewall_chain = hedgedoc_firewall_chain(instance)

  db_port = new_resource.db_port || hedgedoc_db_port(new_resource.db_dialect)
  db_url = hedgedoc_db_url(
    dialect: new_resource.db_dialect,
    user: new_resource.db_user,
    password: new_resource.db_password,
    host: new_resource.db_host,
    port: db_port,
    name: new_resource.db_name
  )

  # Open the HedgeDoc port so an HAProxy node terminating SSL on a separate host
  # can reach the backend. Restricted to OSL-managed IPs.
  osl_firewall_port firewall_chain do
    ports [new_resource.port.to_s]
    osl_only true
  end

  directory base_dir do
    recursive true
  end

  directory "#{base_dir}/uploads" do
    owner hedgedoc_uid
    group hedgedoc_gid
    recursive true
  end

  if new_resource.intro_md && new_resource.intro_source
    raise "osl_hedgedoc[#{new_resource.name}]: set only one of intro_md or intro_source"
  end

  mount_intro = !(new_resource.intro_md.nil? && new_resource.intro_source.nil?)

  # A custom landing page is bind-mounted as a single file, so it must exist on
  # disk before Compose starts (otherwise Docker would create a directory).
  if new_resource.intro_source
    cookbook_file "#{base_dir}/intro.md" do
      source new_resource.intro_source
      cookbook new_resource.intro_cookbook || new_resource.cookbook_name.to_s
      notifies :rebuild, "osl_dockercompose[#{instance}]"
    end
  elsif new_resource.intro_md
    file "#{base_dir}/intro.md" do
      content new_resource.intro_md
      notifies :rebuild, "osl_dockercompose[#{instance}]"
    end
  end

  template "#{base_dir}/docker-compose.yml" do
    source 'docker-compose.yml.erb'
    cookbook 'osl-hedgedoc'
    variables(mount_intro: mount_intro)
    notifies :rebuild, "osl_dockercompose[#{instance}]"
  end

  template "#{base_dir}/.env" do
    source 'env.erb'
    cookbook 'osl-hedgedoc'
    sensitive true
    variables(
      version: new_resource.version,
      port: new_resource.port,
      timezone: new_resource.timezone,
      db_url: db_url,
      domain: new_resource.domain,
      session_secret: new_resource.session_secret,
      allow_anonymous: new_resource.allow_anonymous,
      allow_email_register: new_resource.allow_email_register,
      ldap: new_resource.ldap,
      oauth2: new_resource.oauth2,
      extra_options: new_resource.extra_options
    )
    notifies :rebuild, "osl_dockercompose[#{instance}]"
  end

  docker_image instance do
    repo 'quay.io/hedgedoc/hedgedoc'
    tag new_resource.version
    notifies :rebuild, "osl_dockercompose[#{instance}]"
  end

  osl_dockercompose instance do
    directory base_dir
  end
end
