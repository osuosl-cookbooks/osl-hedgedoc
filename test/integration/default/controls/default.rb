hedgedoc_version = input('hedgedoc_version', value: 'latest')

# Toggles so the mysql/ldap/oidc suites can reuse this same profile (see
# kitchen.yml):
#   db_dialect     - 'postgres' (default) or 'mysql', sets the expected CMD_DB_URL
#   default_extras - intro.md + extra_options, only set by the default recipe
#   test_ldap      - CMD_LDAP_* settings
#   test_oidc      - CMD_OAUTH2_* settings
db_dialect = input('db_dialect', value: 'postgres')
default_extras = input('default_extras', value: true)
test_ldap = input('test_ldap', value: false)
test_oidc = input('test_oidc', value: false)

db_url_regex =
  if db_dialect == 'mysql'
    %r{^CMD_DB_URL=mysql://hedgedoc:hedgedoc@.*:3306/hedgedoc$}
  else
    %r{^CMD_DB_URL=postgres://hedgedoc:hedgedoc@.*:5432/hedgedoc$}
  end

# --- Shared: every suite deploys the same core instance ----------------------

# The HedgeDoc container publishes its web port on the host so an external
# HAProxy node (doing SSL termination) can reach the backend.
describe port(3000) do
  it { should be_listening }
  its('addresses') { should include '0.0.0.0' }
end

describe docker_container('hedgedoc-example-org-hedgedoc-1') do
  it { should exist }
  it { should be_running }
  its('image') { should eq "quay.io/hedgedoc/hedgedoc:#{hedgedoc_version}" }
end

# A 200 from HedgeDoc proves the Node app booted AND connected to its database --
# HedgeDoc exits on startup if the database is unreachable, so this is a true
# end-to-end signal.
describe http('http://localhost:3000/') do
  its('status') { should cmp 200 }
end

describe http('http://localhost:3000/status') do
  its('status') { should cmp 200 }
end

describe file('/data/hedgedoc/hedgedoc.example.org/.env') do
  it { should exist }
  its('content') { should match db_url_regex }
  its('content') { should match(/^CMD_DOMAIN=hedgedoc.example.org$/) }
  its('content') { should match(/^CMD_PROTOCOL_USESSL=true$/) }
  its('content') { should match(/^CMD_URL_ADDPORT=false$/) }
end

describe directory('/data/hedgedoc/hedgedoc.example.org/uploads') do
  it { should exist }
  its('uid') { should eq 10_000 }
  its('gid') { should eq 10_000 }
end

# Firewall should allow the HedgeDoc port for the external HAProxy host,
# restricted to OSL-managed IPs (osl_only).
describe iptables do
  it { should have_rule('-A INPUT -j hedgedoc-hedgedoc-example-or') }
  it { should have_rule('-A hedgedoc-hedgedoc-example-or -p tcp -m tcp --dport 3000 -j osl_only') }
end unless docker

# --- default suite only: intro_md + extra_options ----------------------------

if default_extras
  describe file('/data/hedgedoc/hedgedoc.example.org/.env') do
    its('content') { should match(/^CMD_ALLOW_FREEURL=true$/) }
    its('content') { should match(/^CMD_DEFAULT_PERMISSION=limited$/) }
  end

  # Custom landing page is written to disk and bind-mounted into the container.
  describe file('/data/hedgedoc/hedgedoc.example.org/intro.md') do
    it { should exist }
    its('content') { should match(/Welcome to OSL HedgeDoc/) }
  end

  describe file('/data/hedgedoc/hedgedoc.example.org/docker-compose.yml') do
    its('content') { should match(%r{\./intro\.md:/hedgedoc/public/intro\.md:ro}) }
  end

  # HedgeDoc serves public/ statically at the root, so the bind-mounted intro is
  # returned as raw markdown at /intro.md -- proves the mount reached the
  # container. (The cover page loads it client-side, so it never appears in /.)
  describe http('http://localhost:3000/intro.md') do
    its('status') { should cmp 200 }
    its('body') { should match(/Welcome to OSL HedgeDoc/) }
  end
end

# --- ldap suite: HedgeDoc booted with the (fake) LDAP config ------------------

if test_ldap
  describe file('/data/hedgedoc/hedgedoc.example.org/.env') do
    its('content') { should match(%r{^CMD_LDAP_URL=ldaps://ldap\.example\.org$}) }
    its('content') { should match(/^CMD_LDAP_SEARCHBASE=ou=people,dc=example,dc=org$/) }
    its('content') { should match(/^CMD_LDAP_PROVIDERNAME=Example LDAP$/) }
  end
end

# --- oidc suite: HedgeDoc registered the OAuth2/OIDC strategy -----------------

if test_oidc
  describe file('/data/hedgedoc/hedgedoc.example.org/.env') do
    its('content') { should match(/^CMD_OAUTH2_CLIENT_ID=hedgedoc$/) }
    its('content') { should match(%r{^CMD_OAUTH2_AUTHORIZATION_URL=https://idp\.example\.org/authorize$}) }
    its('content') { should match(/^CMD_OAUTH2_PROVIDERNAME=Example SSO$/) }
  end

  # GET /auth/oauth2 only exists when the OAuth2 strategy was registered from the
  # config, and it redirects to the provider. We must NOT set max_redirects here:
  # inspec only follows redirects when it's set, and a limit of 0 makes it raise
  # on the first hop (nil status). Omitting it returns the 302 + Location as-is,
  # which proves the strategy is wired up (the fake IdP is never contacted).
  describe http('http://localhost:3000/auth/oauth2') do
    its('status') { should cmp 302 }
    its('headers.location') { should match(%r{^https://idp\.example\.org/authorize}) }
  end
end
