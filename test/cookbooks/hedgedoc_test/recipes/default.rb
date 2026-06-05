osl_postgresql_test 'hedgedoc' do
  username 'hedgedoc'
  password 'hedgedoc'
end

osl_hedgedoc 'hedgedoc.example.org' do
  db_host node['ipaddress']
  db_name 'hedgedoc'
  db_user 'hedgedoc'
  db_password 'hedgedoc'
  session_secret 'a' * 32
  extra_options(
    'CMD_ALLOW_FREEURL' => true,
    'CMD_DEFAULT_PERMISSION' => 'limited'
  )
  intro_md "# Welcome to OSL HedgeDoc\n\nThis is a custom landing page.\n"
end
