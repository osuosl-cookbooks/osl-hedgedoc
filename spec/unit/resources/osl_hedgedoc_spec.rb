require_relative '../../spec_helper'

describe 'hedgedoc_test::default' do
  platform 'almalinux'
  cached(:subject) { chef_run }
  step_into :osl_hedgedoc

  before do
    stub_command('iptables -C INPUT -j REJECT --reject-with icmp-host-prohibited 2>/dev/null').and_return(true)
  end

  it { is_expected.to include_recipe 'osl-docker' }

  it do
    is_expected.to accept_osl_firewall_port('hedgedoc-example-org').with(
      ports: ['3000'],
      osl_only: true
    )
  end

  it { is_expected.to create_directory('/data/hedgedoc/hedgedoc.example.org').with(recursive: true) }

  it do
    is_expected.to create_directory('/data/hedgedoc/hedgedoc.example.org/uploads').with(
      owner: 10_000,
      group: 10_000,
      recursive: true
    )
  end

  it do
    is_expected.to create_file('/data/hedgedoc/hedgedoc.example.org/intro.md')
      .with(content: "# Welcome to OSL HedgeDoc\n\nThis is a custom landing page.\n")
  end

  it do
    expect(chef_run.file('/data/hedgedoc/hedgedoc.example.org/intro.md')).to \
      notify('osl_dockercompose[hedgedoc-example-org]').to(:rebuild)
  end

  it do
    is_expected.to create_template('/data/hedgedoc/hedgedoc.example.org/docker-compose.yml').with(
      source: 'docker-compose.yml.erb',
      cookbook: 'osl-hedgedoc'
    )
  end

  it do
    is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/docker-compose.yml')
      .with_content(%r{\./intro\.md:/hedgedoc/public/intro\.md:ro})
  end

  it do
    expect(chef_run.template('/data/hedgedoc/hedgedoc.example.org/docker-compose.yml')).to \
      notify('osl_dockercompose[hedgedoc-example-org]').to(:rebuild)
  end

  it do
    is_expected.to create_template('/data/hedgedoc/hedgedoc.example.org/.env').with(
      source: 'env.erb',
      cookbook: 'osl-hedgedoc',
      sensitive: true
    )
  end

  it do
    is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env')
      .with_content('CMD_DB_URL=postgres://hedgedoc:hedgedoc@10.0.0.2:5432/hedgedoc')
  end

  it do
    is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env')
      .with_content('CMD_DOMAIN=hedgedoc.example.org')
  end

  it { is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env').with_content('CMD_PROTOCOL_USESSL=true') }
  it { is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env').with_content('CMD_URL_ADDPORT=false') }
  it { is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env').with_content('HEDGEDOC_VERSION=latest') }
  it { is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env').with_content('APP_PORT=3000') }

  it do
    is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env')
      .with_content(/^CMD_ALLOW_FREEURL=true$/)
  end

  it do
    is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env')
      .with_content(/^CMD_DEFAULT_PERMISSION=limited$/)
  end

  # Auth is exercised by the dedicated ldap/oidc contexts below.
  it { is_expected.to_not render_file('/data/hedgedoc/hedgedoc.example.org/.env').with_content(/^CMD_LDAP_/) }
  it { is_expected.to_not render_file('/data/hedgedoc/hedgedoc.example.org/.env').with_content(/^CMD_OAUTH2_/) }

  it do
    expect(chef_run.template('/data/hedgedoc/hedgedoc.example.org/.env')).to \
      notify('osl_dockercompose[hedgedoc-example-org]').to(:rebuild)
  end

  it do
    is_expected.to pull_docker_image('hedgedoc-example-org').with(
      repo: 'quay.io/hedgedoc/hedgedoc',
      tag: 'latest'
    )
  end

  it do
    expect(chef_run.docker_image('hedgedoc-example-org')).to \
      notify('osl_dockercompose[hedgedoc-example-org]').to(:rebuild)
  end

  it do
    is_expected.to up_osl_dockercompose('hedgedoc-example-org')
      .with(directory: '/data/hedgedoc/hedgedoc.example.org')
  end
end

describe 'hedgedoc_test::mysql' do
  platform 'almalinux'
  cached(:subject) { chef_run }
  step_into :osl_hedgedoc

  before do
    stub_command('iptables -C INPUT -j REJECT --reject-with icmp-host-prohibited 2>/dev/null').and_return(true)
  end

  it do
    is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env')
      .with_content(%r{^CMD_DB_URL=mysql://hedgedoc:hedgedoc@.*:3306/hedgedoc$})
  end

  # No intro_md set here: the file is not created and the compose mount is absent.
  it { is_expected.to_not create_file('/data/hedgedoc/hedgedoc.example.org/intro.md') }

  it do
    is_expected.to_not render_file('/data/hedgedoc/hedgedoc.example.org/docker-compose.yml')
      .with_content(/intro\.md/)
  end
end

describe 'hedgedoc_test::intro_source' do
  platform 'almalinux'
  cached(:subject) { chef_run }
  step_into :osl_hedgedoc

  before do
    stub_command('iptables -C INPUT -j REJECT --reject-with icmp-host-prohibited 2>/dev/null').and_return(true)
  end

  # intro_source pulls the landing page from a cookbook_file, defaulting to the
  # calling cookbook (hedgedoc_test).
  it do
    is_expected.to create_cookbook_file('/data/hedgedoc/hedgedoc.example.org/intro.md').with(
      source: 'intro.md',
      cookbook: 'hedgedoc_test'
    )
  end

  it do
    expect(chef_run.cookbook_file('/data/hedgedoc/hedgedoc.example.org/intro.md')).to \
      notify('osl_dockercompose[hedgedoc-example-org]').to(:rebuild)
  end

  it { is_expected.to_not create_file('/data/hedgedoc/hedgedoc.example.org/intro.md') }

  it do
    is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/docker-compose.yml')
      .with_content(%r{\./intro\.md:/hedgedoc/public/intro\.md:ro})
  end
end

describe 'hedgedoc_test::ldap' do
  platform 'almalinux'
  cached(:subject) { chef_run }
  step_into :osl_hedgedoc

  before do
    stub_command('iptables -C INPUT -j REJECT --reject-with icmp-host-prohibited 2>/dev/null').and_return(true)
  end

  {
    'CMD_LDAP_URL' => 'ldaps://ldap.example.org',
    'CMD_LDAP_SEARCHBASE' => 'ou=people,dc=example,dc=org',
    'CMD_LDAP_BINDCREDENTIALS' => 'fakepassword',
    'CMD_LDAP_PROVIDERNAME' => 'Example LDAP',
  }.each do |key, value|
    it do
      is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env')
        .with_content("#{key}=#{value}")
    end
  end

  it { is_expected.to_not render_file('/data/hedgedoc/hedgedoc.example.org/.env').with_content(/^CMD_OAUTH2_/) }
end

describe 'hedgedoc_test::oidc' do
  platform 'almalinux'
  cached(:subject) { chef_run }
  step_into :osl_hedgedoc

  before do
    stub_command('iptables -C INPUT -j REJECT --reject-with icmp-host-prohibited 2>/dev/null').and_return(true)
  end

  {
    'CMD_OAUTH2_CLIENT_ID' => 'hedgedoc',
    'CMD_OAUTH2_CLIENT_SECRET' => 'fakesecret',
    'CMD_OAUTH2_AUTHORIZATION_URL' => 'https://idp.example.org/authorize',
    'CMD_OAUTH2_USER_PROFILE_USERNAME_ATTR' => 'preferred_username',
    'CMD_OAUTH2_PROVIDERNAME' => 'Example SSO',
  }.each do |key, value|
    it do
      is_expected.to render_file('/data/hedgedoc/hedgedoc.example.org/.env')
        .with_content("#{key}=#{value}")
    end
  end

  it { is_expected.to_not render_file('/data/hedgedoc/hedgedoc.example.org/.env').with_content(/^CMD_LDAP_/) }
end
